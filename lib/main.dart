import 'dart:async';
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
      final stream = await _recorder.startStream(const RecordConfig(encoder: AudioEncoder.pcm16bits));
      
      _audioStreamSubscription = stream.listen((data) {
        final result = _analysisService.analyzeFrequency(data);
        setState(() {
          _note = result['note'] as String;
          _fftData = result['fft'] as List<double>;
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
    'C': Colors.red, 'C#': Colors.redAccent,
    'D': Colors.orange, 'D#': Colors.orangeAccent,
    'E': Colors.yellow,
    'F': Colors.green, 'F#': Colors.greenAccent,
    'G': Colors.blue, 'G#': Colors.lightBlueAccent,
    'A': Colors.indigo, 'A#': Colors.indigoAccent,
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
      final normalizedAmplitude = (fftData[i] / 10000000).clamp(0, 1);
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
    for(int i = 0; i < fftData.length; i++) {
      if(oldDelegate.fftData[i] != fftData[i]) return true;
    }
    return oldDelegate.note != note;
  }
}
