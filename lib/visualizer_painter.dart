import 'package:flutter/material.dart';

class VisualizerPainter extends CustomPainter {
  final double decibels;

  VisualizerPainter({required this.decibels});

  @override
  void paint(Canvas canvas, Size size) {
    // 화면 중앙을 기준으로 그리기 위한 Paint 객체
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    // 데시벨 값을 시각적인 높이로 변환
    // 데시벨은 보통 음수이며, 0에 가까울수록 소리가 큽니다. (-120 ~ 0)
    // -60dB일 때 화면 높이의 절반, 0dB일 때 화면 전체 높이가 되도록 매핑합니다.
    final normalizedDb = (decibels + 60).clamp(0, 60) / 60; // 0.0 ~ 1.0 범위로 정규화
    final barHeight = normalizedDb * size.height;

    // 화면 중앙에 막대 그리기
    const barWidth = 100.0;
    final rect = Rect.fromLTWH(
      (size.width - barWidth) / 2, // x 위치 (가운데 정렬)
      size.height - barHeight, // y 위치 (아래쪽부터 높이 계산)
      barWidth, // 너비
      barHeight, // 높이
    );

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant VisualizerPainter oldDelegate) {
    // 데시벨 값이 변경될 때만 다시 그리도록 설정하여 성능을 최적화합니다.
    return decibels != oldDelegate.decibels;
  }
}
