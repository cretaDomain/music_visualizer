import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Visualizer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const VisualizerPage(),
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
  // ignore: unused_field
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.microphone.request();
    if (status == PermissionStatus.granted) {
      setState(() {
        _hasPermission = true;
        _message = 'Permission granted! Starting audio stream...';
      });
      // TODO: Start audio stream here
    } else {
      setState(() {
        _hasPermission = false;
        _message = 'Permission denied. Please grant microphone access in settings.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          _message,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
