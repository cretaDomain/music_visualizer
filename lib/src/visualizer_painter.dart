import 'dart:ui' as ui;
import 'dart:math';

import 'package:creta_music_visualizer/src/models/circle_spark.dart';
import 'package:flutter/material.dart';

import 'models/color_spark.dart';
import 'models/visualizer_type.dart';

class VisualizerPainter extends CustomPainter {
  final VisualizerType type;
  final String note;
  final List<double> fftData;
  final List<ColorSpark> barSparks;
  final List<CircleSpark> circleSparks;

  VisualizerPainter({
    required this.type,
    required this.note,
    required this.fftData,
    required this.barSparks,
    required this.circleSparks,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (fftData.isEmpty) return;

    switch (type) {
      case VisualizerType.bars:
        _drawBars(canvas, size);
        break;
      case VisualizerType.circles:
        _drawCircles(canvas, size);
        break;
    }
  }

  void _drawBars(Canvas canvas, Size size) {
    final barPaint = Paint()..style = PaintingStyle.fill;
    final barWidth = size.width / fftData.length;
    final maxBarHeight = size.height;

    // 1. Draw the base bars in a neutral color
    for (int i = 0; i < fftData.length; i++) {
      final normalizedAmplitude = fftData[i].clamp(0, 1);
      final barHeight = normalizedAmplitude * maxBarHeight;
      if (barHeight <= 0) continue;

      final rect = Rect.fromLTWH(
        i * barWidth,
        size.height - barHeight,
        barWidth,
        barHeight,
      );

      barPaint.color = Colors.white.withOpacity(0.8);
      canvas.drawRect(rect, barPaint);
    }

    // 2. Draw the color sparks as a glow effect
    for (final spark in barSparks) {
      if (spark.index >= fftData.length) continue;

      final normalizedAmplitude = fftData[spark.index].clamp(0, 1);
      if (normalizedAmplitude <= 0) continue;

      final barHeight = normalizedAmplitude * maxBarHeight;

      final glowIntensity = (spark.octave - 3).clamp(1, 4).toDouble();

      final glowPaint = Paint()
        ..color = spark.color.withOpacity(spark.life * 0.7)
        ..maskFilter = MaskFilter.blur(
            BlurStyle.normal, convertRadiusToSigma(10.0 * glowIntensity * spark.life));

      final glowRect = Rect.fromLTWH(
        spark.index * barWidth,
        size.height - barHeight,
        barWidth,
        barHeight,
      );

      canvas.drawRect(glowRect, glowPaint);
    }

    // 3. Draw the note text
    _drawNoteText(canvas, size);
  }

  void _drawCircles(Canvas canvas, Size size) {
    final circlePaint = Paint();

    for (final spark in circleSparks) {
      final center = Offset(spark.center.dx * size.width, spark.center.dy * size.height);

      final maxRadius = size.width * 0.3 * spark.maxRadius;
      final currentRadius = maxRadius * (1.0 - spark.life);
      final opacity = spark.life.clamp(0.0, 1.0);

      if (opacity <= 0 || currentRadius <= 0) continue;

      circlePaint.color = spark.color.withOpacity(opacity * 0.8);

      final ringCount = spark.octave.clamp(2, 5);

      for (int i = 0; i < ringCount; i++) {
        final radius = currentRadius * ((i + 1) / ringCount);

        circlePaint.style = PaintingStyle.stroke;
        circlePaint.strokeWidth = max(1.0, currentRadius / 20 * (1 - (i / ringCount)));
        canvas.drawCircle(center, radius, circlePaint);
      }
    }

    _drawNoteText(canvas, size);
  }

  void _drawNoteText(Canvas canvas, Size size) {
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
    return oldDelegate.type != type ||
        oldDelegate.note != note ||
        oldDelegate.fftData != fftData ||
        oldDelegate.barSparks != barSparks ||
        oldDelegate.circleSparks != circleSparks;
  }
}
