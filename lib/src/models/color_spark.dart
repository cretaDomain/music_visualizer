import 'package:flutter/material.dart';

class ColorSpark {
  int index;
  Color color;
  double life;
  int octave;

  ColorSpark({
    required this.index,
    required this.color,
    this.life = 1.0,
    required this.octave,
  });
}
