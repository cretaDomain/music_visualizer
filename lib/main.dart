import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:music_visualizer/audio_analysis_service.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Music Visualizer',
      home: VisualizerPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class VisualizerPage extends StatefulWidget {
  const VisualizerPage({super.key});

  @override
  State<VisualizerPage> createState() => _VisualizerPageState();
}

class _VisualizerPageState extends State<VisualizerPage> {
  String _message = 'Checking permissions...';
  String? _pitch;
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final AudioAnalysisService _audioAnalysisService = AudioAnalysisService();
  StreamSubscription? _audioDataSubscription;
  final StreamController<Uint8List> _audioDataController = StreamController.broadcast();

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  @override
  void dispose() {
    _stopRecording();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.microphone.request();
    if (status == PermissionStatus.granted) {
      setState(() {
        _message = 'Permission granted! Initializing recorder...';
      });
      await _startRecording();
    } else {
      setState(() {
        _message = 'Permission denied. Please grant microphone access in settings.';
      });
    }
  }

  Future<void> _startRecording() async {
    const int sampleRate = 44100;
    try {
      await _recorder.openRecorder();

      _audioDataSubscription = _audioDataController.stream.listen((buffer) {
        final double decibels = _audioAnalysisService.calculateDecibels(buffer);
        final String? pitch = _audioAnalysisService.analyzePitch(buffer, sampleRate);

        setState(() {
          _message = 'Decibels: ${decibels.toStringAsFixed(2)}';
          _pitch = pitch;
        });
      });

      await _recorder.startRecorder(
        toStream: _audioDataController.sink,
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: sampleRate,
      );
    } catch (e) {
      setState(() {
        _message = 'Failed to start recording: $e';
      });
    }
  }

  Future<void> _stopRecording() async {
    await _recorder.stopRecorder();
    await _audioDataSubscription?.cancel();
    await _audioDataController.close();
    await _recorder.closeRecorder();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _message,
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),
            const SizedBox(height: 20),
            Text(
              'Pitch: ${_pitch ?? "N/A"}',
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),
          ],
        ),
      ),
    );
  }
}
