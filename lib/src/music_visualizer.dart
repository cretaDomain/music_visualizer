import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:creta_music_visualizer/src/models/circle_spark.dart';
import 'package:creta_music_visualizer/src/models/visualizer_type.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'audio_analysis_service.dart';
import 'models/color_spark.dart';
import 'visualizer_painter.dart';

class MusicVisualizer extends StatefulWidget {
  const MusicVisualizer({super.key});

  @override
  State<MusicVisualizer> createState() => _MusicVisualizerState();
}

class _MusicVisualizerState extends State<MusicVisualizer> with TickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioAnalysisService _analysisService = AudioAnalysisService();
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  late final AnimationController _animationController;
  Timer? _visualizerTimer;

  // ignore: unused_field
  final bool _isRecording = false;
  String _note = '';
  List<double> _fftData = List.filled(64, 0.0);
  final List<List<double>> _fftDataHistory = [];
  List<ColorSpark> _colorSparks = [];
  List<CircleSpark> _circleSparks = [];
  bool _isInitialized = false;
  VisualizerType _currentType = VisualizerType.bars;

  final Map<String, Color> _noteColorMap = {
    'C': Colors.red,
    'C#': Colors.redAccent,
    'D': Colors.orange,
    'D#': Colors.orangeAccent,
    'E': Colors.yellow,
    'F': Colors.green,
    'F#': Colors.greenAccent,
    'G': Colors.blue,
    'G#': Colors.lightBlueAccent,
    'A': Colors.indigo,
    'A#': Colors.indigoAccent,
    'B': Colors.purple,
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _visualizerTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        setState(() {
          _currentType =
              _currentType == VisualizerType.bars ? VisualizerType.circles : VisualizerType.bars;
        });
      }
    });

    _init();
  }

  Future<void> _init() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      return;
    }
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
      _startRecording();
    }
  }

  @override
  void dispose() {
    _stopRecording();
    _recorder.dispose();
    _animationController.dispose();
    _visualizerTimer?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (await _recorder.hasPermission()) {
      final stream =
          await _recorder.startStream(const RecordConfig(encoder: AudioEncoder.pcm16bits));

      _audioStreamSubscription = stream.listen((data) {
        final result = _analysisService.analyzeFrequency(data);
        final newFftData = result['fft'] as List<double>;

        _fftDataHistory.add(newFftData);
        if (_fftDataHistory.length > 24) {
          _fftDataHistory.removeAt(0);
        }

        final averagedFftData = List<double>.filled(newFftData.length, 0.0);
        for (final fft in _fftDataHistory) {
          for (int i = 0; i < fft.length; i++) {
            averagedFftData[i] += fft[i];
          }
        }

        for (int i = 0; i < averagedFftData.length; i++) {
          averagedFftData[i] /= _fftDataHistory.length;
        }

        final weightedFftData = List<double>.generate(averagedFftData.length, (i) {
          final weight = _calculateGaussianWeight(i, averagedFftData.length);
          return averagedFftData[i] * weight;
        });

        final stretchedFftData = _stretchContrast(weightedFftData);

        // Update effects based on visualizer type
        final newNote = result['note'] as String;
        _updateVisualEffects(newNote, stretchedFftData);

        _note = newNote;
        _fftData = stretchedFftData;
      });

      if (mounted) {
        setState(() {});
      }
    }
  }

  void _updateVisualEffects(String newNote, List<double> fftData) {
    // Bar sparks
    final nextColorSparks = <ColorSpark>[];
    for (final spark in _colorSparks) {
      spark.life -= 0.04;
      if (spark.life > 0) {
        nextColorSparks.add(spark);
      }
    }

    // Circle sparks
    final nextCircleSparks = <CircleSpark>[];
    for (final spark in _circleSparks) {
      spark.life -= 0.02; // Slower fade for circles
      if (spark.life > 0) {
        nextCircleSparks.add(spark);
      }
    }

    if (newNote.isNotEmpty && newNote != 'N/A') {
      final noteName = newNote.substring(0, newNote.length - 1);
      final noteOctave = int.tryParse(newNote.substring(newNote.length - 1)) ?? 4;
      final noteColor = _noteColorMap[noteName];

      if (noteColor != null) {
        final random = Random();
        if (_currentType == VisualizerType.bars) {
          for (int i = 0; i < 2; i++) {
            final sparkIndex = random.nextInt(fftData.length);
            nextColorSparks.add(ColorSpark(
              index: sparkIndex,
              color: noteColor,
              octave: noteOctave,
            ));
          }
        } else if (_currentType == VisualizerType.circles) {
          final maxAmplitude = fftData.reduce(max);
          nextCircleSparks.add(CircleSpark(
            center: Offset(random.nextDouble(), random.nextDouble()),
            color: noteColor,
            octave: noteOctave,
            maxRadius: maxAmplitude * 2.0, // Scale radius by amplitude
          ));
        }
      }
    }
    _colorSparks = nextColorSparks;
    _circleSparks = nextCircleSparks;
  }

  Future<void> _stopRecording() async {
    await _audioStreamSubscription?.cancel();
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    if (mounted) {
      setState(() {
        _fftData = List.filled(64, 0.0);
        _fftDataHistory.clear();
        _colorSparks.clear();
        _circleSparks.clear();
        _note = '';
      });
    }
  }

  double _calculateGaussianWeight(int index, int totalLength,
      {double peakFactor = 1.5, double spreadFactor = 12.0}) {
    final center = totalLength / 2.0;
    final exponent = -pow(index - center, 2) / (2 * pow(spreadFactor, 2));
    final weight = exp(exponent);
    return 1 + weight * (peakFactor - 1);
  }

  List<double> _stretchContrast(List<double> data) {
    if (data.every((d) => d == 0)) return data;

    double minVal = data.reduce((a, b) => a < b ? a : b);
    double maxVal = data.reduce((a, b) => a > b ? a : b);

    if (maxVal == minVal) return List.filled(data.length, 0.5);

    return data.map((d) => (d - minVal) / (maxVal - minVal)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return _isInitialized
        ? AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return CustomPaint(
                size: Size.infinite,
                painter: VisualizerPainter(
                  type: _currentType,
                  note: _note,
                  fftData: _fftData,
                  barSparks: _colorSparks,
                  circleSparks: _circleSparks,
                ),
              );
            },
          )
        : const Center(child: CircularProgressIndicator());
  }
}
