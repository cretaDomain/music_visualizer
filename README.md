# Music Visualizer

A music visualizer widget for Flutter that renders beautiful, animated visualizations from audio input, like the ones seen in classic media players.

## Platform Support

This package is designed for **Windows only**, as it relies on platform-specific implementations for audio capture.

## Features

*   Real-time audio processing from microphone input.
*   Smooth, FFT-based bar visualization.
*   Dynamic, note-based color glows with a beautiful fade-out effect.

## Getting started

TODO: List prerequisites and provide installation instructions.

## Usage

Here is a basic example of how to use the `MusicVisualizer` widget.

```dart
import 'package:flutter/material.dart';
import 'package:music_visualizer/music_visualizer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: MusicVisualizer(),
      ),
    );
  }
}
```
