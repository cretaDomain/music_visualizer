import 'package:flutter/material.dart';
import 'package:creta_music_visualizer/music_visualizer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Music Visualizer Example',
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: MusicVisualizer(),
        ),
      ),
    );
  }
}
