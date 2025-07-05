import 'package:flutter/material.dart';
import 'package:creta_music_visualizer/src/models/shape_type.dart';

class ShapeSpark {
  final Offset center;
  final Color color;
  final ShapeType shape;
  double life;
  final double maxRadius;
  final int octave;

  ShapeSpark({
    required this.center,
    required this.color,
    required this.shape,
    this.life = 1.0,
    required this.maxRadius,
    required this.octave,
  });
}
