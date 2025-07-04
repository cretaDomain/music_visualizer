import 'dart:math';
import 'package:flutter/material.dart';

class VisualizerPainter extends CustomPainter {
  final List<double> amplitudes; // 주파수 대역별 진폭 리스트
  final String? pitch;

  VisualizerPainter({
    required this.amplitudes,
    this.pitch,
  });

  // 음계 이름에 따라 색상을 결정하는 헬퍼 메소드
  Color _getColorForPitch(String? pitch) {
    if (pitch == null) {
      return Colors.blue; // 기본 색상
    }
    // 'C', 'D', 'E' 같은 음계 이름만 추출 (옥타브 번호, # 등은 제외)
    final noteName = pitch.substring(0, 1).toUpperCase();

    switch (noteName) {
      case 'C':
        return Colors.red;
      case 'D':
        return Colors.orange;
      case 'E':
        return Colors.yellow;
      case 'F':
        return Colors.green;
      case 'G':
        return Colors.indigo;
      case 'A':
        return Colors.purple;
      case 'B':
        return Colors.pink;
      default:
        return Colors.blue;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 네온 효과를 위한 Paint 객체 (블러 효과)
    final glowPaint = Paint()
      ..color = _getColorForPitch(pitch).withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20.0);

    // 2. 실제 막대를 그릴 Paint 객체
    final barPaint = Paint()
      ..color = _getColorForPitch(pitch)
      ..style = PaintingStyle.fill;

    if (amplitudes.isEmpty) return;

    final double barWidth = size.width / amplitudes.length;
    const double minBarHeight = 2.0;

    for (int i = 0; i < amplitudes.length; i++) {
      // 3. 진폭 값을 막대 높이로 변환 (정규화 및 스케일링)
      // 진폭 값은 보통 매우 작으므로, 시각적으로 잘 보이도록 증폭합니다.
      // log 함수를 사용해 값의 분포를 조절하여 자연스러운 시각화를 만듭니다.
      final double normalizedAmplitude = amplitudes[i] * 1000; // 증폭
      final double logScaledAmplitude =
          normalizedAmplitude > 0 ? log(normalizedAmplitude + 1) * 20 : 0;
      final double barHeight = max(minBarHeight, logScaledAmplitude.clamp(0, size.height));

      final double left = i * barWidth;
      final double top = size.height - barHeight;
      final rect = Rect.fromLTWH(left, top, barWidth - 2, barHeight); // 막대 간 간격

      // 4. 네온 효과(glow)를 먼저 그리고, 그 위에 실제 막대를 그립니다.
      canvas.drawRect(rect.inflate(10.0), glowPaint); // inflate로 영역을 약간 확장
      canvas.drawRect(rect, barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant VisualizerPainter oldDelegate) {
    // amplitudes 리스트나 pitch가 변경될 때 다시 그립니다.
    return amplitudes != oldDelegate.amplitudes || pitch != oldDelegate.pitch;
  }
}
