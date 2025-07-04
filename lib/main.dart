import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
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
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  StreamSubscription? _recorderSubscription;
  StreamSubscription? _audioDataSubscription;
  final StreamController<Uint8List> _audioDataController = StreamController();

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
    try {
      await _recorder.openRecorder();

      // 데시벨 값 표시를 위한 리스너
      _recorderSubscription = _recorder.onProgress!.listen((e) {
        if (e.decibels != null) {
          setState(() {
            _message = 'Decibels: ${e.decibels?.toStringAsFixed(2)}';
          });
        }
      });

      // (2-3 작업) 실제 오디오 데이터 출력을 위한 리스너
      _audioDataSubscription = _audioDataController.stream.listen((buffer) {
        // 콘솔에 데이터 길이와 앞 10바이트만 출력
        debugPrint(
            'Received audio data: ${buffer.length} bytes. Data: ${buffer.sublist(0, 10)}...');
      });

      await _recorder.startRecorder(
        toStream: _audioDataController.sink, // 데이터를 우리 스트림으로 보내도록 설정
        codec: Codec.pcm16, // 원본 데이터에 가까운 PCM 코덱 사용
        numChannels: 1,
        sampleRate: 44100,
      );
    } catch (e) {
      setState(() {
        _message = 'Failed to start recording: $e';
      });
    }
  }

  Future<void> _stopRecording() async {
    await _recorder.stopRecorder();
    await _recorderSubscription?.cancel();
    await _audioDataSubscription?.cancel();
    await _audioDataController.close();
    await _recorder.closeRecorder();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          _message,
          style: const TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}
