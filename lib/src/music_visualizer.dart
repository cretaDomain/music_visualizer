import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:creta_music_visualizer/src/models/shape_spark.dart';
import 'package:creta_music_visualizer/src/models/shape_type.dart';
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

  // ignore: unused_field
  final bool _isRecording = false;
  String _note = '';
  List<double> _fftData = List.filled(64, 0.0);
  final List<List<double>> _fftDataHistory = [];
  List<ColorSpark> _colorSparks = [];
  List<ShapeSpark> _shapeSparks = [];
  bool _isInitialized = false;
  VisualizerType _currentType = VisualizerType.bars;
  int _highlightCounter = 0;

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
    super.dispose();
  }

  void _changeVisualizationType() {
    setState(() {
      final nextIndex = (_currentType.index + 1) % VisualizerType.values.length;
      _currentType = VisualizerType.values[nextIndex];
    });
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

    // Shape sparks
    final nextShapeSparks = <ShapeSpark>[];
    for (final spark in _shapeSparks) {
      spark.life -= 0.02; // Slower fade for shapes
      if (spark.life > 0) {
        nextShapeSparks.add(spark);
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

          // The shape is determined by a random index in the FFT spectrum, not the overall note octave.
          final sparkIndex = random.nextInt(fftData.length);
          final ShapeType shape;
          if (sparkIndex < 22) {
            shape = ShapeType.triangle;
          } else if (sparkIndex < 46) {
            // 22 + 24
            shape = ShapeType.circle;
          } else {
            shape = ShapeType.star;
          }

          nextShapeSparks.add(ShapeSpark(
            center: Offset(random.nextDouble(), random.nextDouble()),
            color: noteColor,
            octave: noteOctave,
            maxRadius: maxAmplitude * 2.0,
            shape: shape,
          ));
        }
      }
    }
    _colorSparks = nextColorSparks;
    _shapeSparks = nextShapeSparks;
    if (_highlightCounter % 7 == 0) {
      _highlightCounter = 0;
      _note = newNote;
    } else {
      //_note = '';
    }
    _highlightCounter++;
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
        _shapeSparks.clear();
        _note = '';
        _highlightCounter = 0;
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
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return CustomPaint(
              size: Size.infinite,
              painter: VisualizerPainter(
                type: _currentType,
                note: _note,
                fftData: _fftData,
                barSparks: _colorSparks,
                shapeSparks: _shapeSparks,
              ),
            );
          },
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: _changeVisualizationType,
            backgroundColor: Colors.black.withOpacity(0.5),
            hoverColor: Colors.black.withOpacity(0.7),
            child: const Icon(Icons.sync_alt, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
