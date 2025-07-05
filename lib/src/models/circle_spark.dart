import 'package:flutter/material.dart';

class CircleSpark {
  final Offset center;
  final Color color;
  double life;
  final double maxRadius;
  final int octave;

  CircleSpark({
    required this.center,
    required this.color,
    this.life = 1.0,
    required this.maxRadius,
    required this.octave,
  });
}
