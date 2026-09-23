import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Circular attendance/progress ring — the "67% attendance" donut pattern common to top-tier
/// school apps' dashboards, used where a single percentage is the headline stat (parent's child
/// attendance summary) instead of a flat stat card.
class AttendanceRing extends StatelessWidget {
  const AttendanceRing({super.key, required this.percent, this.size = 96, this.strokeWidth = 10, this.color = AppColors.success, this.label});

  final double percent; // 0-100
  final double size;
  final double strokeWidth;
  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0, 100).toDouble();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(percent: clamped, strokeWidth: strokeWidth, color: color),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${clamped.toStringAsFixed(0)}%', style: TextStyle(fontSize: size * 0.24, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              if (label != null)
                Text(label!, style: TextStyle(fontSize: size * 0.11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.percent, required this.strokeWidth, required this.color});
  final double percent;
  final double strokeWidth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final track = Paint()
      ..color = AppColors.background
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [color.withValues(alpha: 0.55), color],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweep = 2 * math.pi * (percent / 100);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, sweep, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.percent != percent || oldDelegate.color != color;
}
