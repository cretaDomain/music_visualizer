import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'models/color_spark.dart';

class VisualizerPainter extends CustomPainter {
  final String note;
  final List<double> fftData;
  final List<ColorSpark> sparks;

  VisualizerPainter({
    required this.note,
    required this.fftData,
    required this.sparks,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (fftData.isEmpty) return;

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
        barWidth, // Use full width for a fuller look
        barHeight,
      );

      barPaint.color = Colors.white.withValues(alpha: 0.8);
      canvas.drawRect(rect, barPaint);
    }

    // 2. Draw the color sparks as a glow effect
    for (final spark in sparks) {
      if (spark.index >= fftData.length) continue;

      final normalizedAmplitude = fftData[spark.index].clamp(0, 1);
      if (normalizedAmplitude <= 0) continue;

      final barHeight = normalizedAmplitude * maxBarHeight;

      // Make the glow more intense for higher octaves
      final glowIntensity = (spark.octave - 3).clamp(1, 4).toDouble();

      final glowPaint = Paint()
        ..color = spark.color.withValues(alpha: spark.life * 0.7) // Fade out
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
    // Repainting is now driven by the AnimationController via AnimatedBuilder.
    // This method is for when painter properties themselves change.
    return oldDelegate.note != note ||
        oldDelegate.fftData != fftData ||
        oldDelegate.sparks != sparks;
  }
}
