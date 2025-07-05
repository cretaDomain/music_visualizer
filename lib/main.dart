import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fftea/fftea.dart';
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

class _MyAppState extends State<MyApp> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioAnalysisService _analysisService = AudioAnalysisService();
  StreamSubscription<Uint8List>? _audioStreamSubscription;

  bool _isRecording = false;
  String _note = '';
  List<double> _fftData = List.filled(64, 0.0);
  final List<List<double>> _fftDataHistory = [];
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      // Handle permission denial
      print('Microphone permission not granted');
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

        setState(() {
          _note = result['note'] as String;
          _fftData = stretchedFftData;
        });
      });

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
              ? CustomPaint(
                  size: Size.infinite,
                  painter: VisualizerPainter(
                    note: _note,
                    fftData: _fftData,
                  ),
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

  VisualizerPainter({
    required this.note,
    required this.fftData,
  });

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

  Color _getColorForNote(String note) {
    if (note.isEmpty || note == 'N/A') return Colors.white;
    final noteName = note.substring(0, note.length - 1);
    return _noteColorMap[noteName] ?? Colors.white;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (fftData.isEmpty) return;

    final paint = Paint()..style = PaintingStyle.fill;
    final barWidth = size.width / fftData.length;
    final maxBarHeight = size.height;
    final color = _getColorForNote(note);

    for (int i = 0; i < fftData.length; i++) {
      final normalizedAmplitude = fftData[i].clamp(0, 1);
      final barHeight = normalizedAmplitude * maxBarHeight;
      if (barHeight <= 0) continue;

      final rect = Rect.fromLTWH(
        i * barWidth,
        size.height - barHeight,
        barWidth - 1,
        barHeight,
      );

      paint.color = color.withOpacity(0.7);
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, convertRadiusToSigma(5));
      canvas.drawRect(rect, paint);

      paint.maskFilter = null;
      paint.color = color;
      canvas.drawRect(rect, paint);
    }

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
    // Simple deep comparison for the list
    if (oldDelegate.fftData.length != fftData.length) return true;
    for (int i = 0; i < fftData.length; i++) {
      if (oldDelegate.fftData[i] != fftData[i]) return true;
    }
    return oldDelegate.note != note;
  }
}
