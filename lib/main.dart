import 'package:flutter/material.dart';

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
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'Visualizer will be here',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
