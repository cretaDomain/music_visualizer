import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

//import 'package:fftea/fftea.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'audio_analysis_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with TickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioAnalysisService _analysisService = AudioAnalysisService();
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  late final AnimationController _animationController;

  bool _isRecording = false;
  String _note = '';
  List<double> _fftData = List.filled(64, 0.0);
  final List<List<double>> _fftDataHistory = [];
  List<ColorSpark> _colorSparks = [];
  bool _isInitialized = false;

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
      // Handle permission denial
      //print('Microphone permission not granted');
      return;
    }
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    _recorder.dispose();
    _audioStreamSubscription?.cancel();
    _animationController.dispose();
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

        // 1. 가중치 곡선 적용 (중앙 증폭)
        final weightedFftData = List<double>.generate(averagedFftData.length, (i) {
          final weight = _calculateGaussianWeight(i, averagedFftData.length);
          return averagedFftData[i] * weight;
        });

        // 2. 편차 증폭 (Contrast Stretching)
        final stretchedFftData = _stretchContrast(weightedFftData);

        // Spark Management - Create a new list for the new state
        final nextSparks = <ColorSpark>[];
        for (final spark in _colorSparks) {
          spark.life -= 0.04; // Update life
          if (spark.life > 0) {
            nextSparks.add(spark); // Add to new list if alive
          }
        }

        final newNote = result['note'] as String;
        if (newNote.isNotEmpty && newNote != 'N/A') {
          final noteName = newNote.substring(0, newNote.length - 1);
          final noteOctave = int.tryParse(newNote.substring(newNote.length - 1)) ?? 4;
          final noteColor = _noteColorMap[noteName];

          if (noteColor != null) {
            final random = Random();
            for (int i = 0; i < 2; i++) {
              final sparkIndex = random.nextInt(stretchedFftData.length);
              nextSparks.add(ColorSpark(
                index: sparkIndex,
                color: noteColor,
                octave: noteOctave,
              ));
            }
          }
        }

        // setState is no longer needed here, as AnimatedBuilder handles repainting.
        // Simply update the state variables directly.
        _note = newNote;
        _fftData = stretchedFftData;
        _colorSparks = nextSparks;
      });

      // We only need to set state here to update the button icon
      setState(() {
        _isRecording = true;
      });
    }
  }

  Future<void> _stopRecording() async {
    await _audioStreamSubscription?.cancel();
    await _recorder.stop();
    setState(() {
      _isRecording = false;
      _fftData = List.filled(64, 0.0);
      _fftDataHistory.clear();
      _colorSparks.clear();
      _note = '';
    });
  }

  void _toggleRecording() {
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  double _calculateGaussianWeight(int index, int totalLength,
      {double peakFactor = 1.5, double spreadFactor = 12.0}) {
    final center = totalLength / 2.0;
    // Real Gaussian function: e^(-(x-b)^2 / (2c^2))
    final exponent = -pow(index - center, 2) / (2 * pow(spreadFactor, 2));
    final weight = exp(exponent);

    // Apply peak factor: baseline is 1 (original value), peak is amplified
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
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: _isInitialized
              ? AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: Size.infinite,
                      painter: VisualizerPainter(
                        note: _note,
                        fftData: _fftData,
                        sparks: _colorSparks,
                      ),
                    );
                  },
                )
              : const CircularProgressIndicator(),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _isInitialized ? _toggleRecording : null,
          backgroundColor: _isInitialized ? null : Colors.grey,
          child: Icon(_isRecording ? Icons.stop : Icons.mic),
        ),
      ),
    );
  }
}

class VisualizerPainter extends CustomPainter {
  final String note;
  final List<double> fftData;
  final List<ColorSpark> sparks;

  VisualizerPainter({
    required this.note,
    required this.fftData,
    required this.sparks,
  });

  // ignore: unused_element
  Color _getColorForNote(String note) {
    if (note.isEmpty || note == 'N/A') return Colors.white;
    // This is now used for the main bar color, maybe return a constant color
    return Colors.white;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (fftData.isEmpty) return;

    final barPaint = Paint()..style = PaintingStyle.fill;
    final barWidth = size.width / fftData.length;
    final maxBarHeight = size.height;

    // 1. Draw the base bars in a neutral color
    for (int i = 0; i < fftData.length; i++) {
      final normalizedAmplitude = fftData[i].clamp(0, 1);
      final barHeight = normalizedAmplitude * maxBarHeight;
      if (barHeight <= 0) continue;

      final rect = Rect.fromLTWH(
        i * barWidth,
        size.height - barHeight,
        barWidth, // Use full width for a fuller look
        barHeight,
      );

      barPaint.color = Colors.white.withValues(alpha: 0.8);
      canvas.drawRect(rect, barPaint);
    }

    // 2. Draw the color sparks as a glow effect
    for (final spark in sparks) {
      if (spark.index >= fftData.length) continue;

      final normalizedAmplitude = fftData[spark.index].clamp(0, 1);
      if (normalizedAmplitude <= 0) continue;

      final barHeight = normalizedAmplitude * maxBarHeight;

      // Make the glow more intense for higher octaves
      final glowIntensity = (spark.octave - 3).clamp(1, 4).toDouble();

      final glowPaint = Paint()
        ..color = spark.color.withValues(alpha: spark.life * 0.7) // Fade out
        ..maskFilter = MaskFilter.blur(
            BlurStyle.normal, convertRadiusToSigma(10.0 * glowIntensity * spark.life));

      final glowRect = Rect.fromLTWH(
        spark.index * barWidth,
        size.height - barHeight,
        barWidth,
        barHeight,
      );

      canvas.drawRect(glowRect, glowPaint);
    }

    // 3. Draw the note text
    if (note.isNotEmpty && note != 'N/A') {
      final textPainter = TextPainter(
        text: TextSpan(
          text: note,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(blurRadius: 5.0, color: Colors.black)],
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout(minWidth: 0, maxWidth: size.width);
      final offset = Offset((size.width - textPainter.width) / 2, 20);
      textPainter.paint(canvas, offset);
    }
  }

  static double convertRadiusToSigma(double radius) {
    return radius * 0.57735 + 0.5;
  }

  @override
  bool shouldRepaint(covariant VisualizerPainter oldDelegate) {
    // Repainting is now driven by the AnimationController via AnimatedBuilder.
    // This method is for when painter properties themselves change.
    return oldDelegate.note != note ||
        oldDelegate.fftData != fftData ||
        oldDelegate.sparks != sparks;
  }
}

class ColorSpark {
  int index;
  Color color;
  double life;
  int octave;

  ColorSpark({
    required this.index,
    required this.color,
    this.life = 1.0,
    required this.octave,
  });
}
