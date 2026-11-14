import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/palette.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 48, this.showGlow = false});

  final double size;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _BrandMarkPainter(showGlow: showGlow),
      ),
    );
  }
}

class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    this.markSize = 40,
    this.titleSize = 22,
    this.showTagline = false,
    this.light = false,
  });

  final double markSize;
  final double titleSize;
  final bool showTagline;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final textColor = light ? Colors.white : Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: markSize,
          height: markSize,
          decoration: BoxDecoration(
            color: AppPalette.charcoal,
            borderRadius: BorderRadius.circular(markSize * 0.3),
            border: Border.all(
              color: AppPalette.emerald.withValues(alpha: 0.35),
            ),
          ),
          padding: EdgeInsets.all(markSize * 0.16),
          child: BrandMark(size: markSize * 0.68),
        ),
        SizedBox(width: markSize * 0.32),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'EstroShop',
              style: TextStyle(
                fontSize: titleSize,
                height: 1.05,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                color: textColor,
              ),
            ),
            if (showTagline)
              Text(
                'Business, in control.',
                style: TextStyle(
                  fontSize: titleSize * 0.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: AppPalette.emerald,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter({required this.showGlow});

  final bool showGlow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final scale = math.min(w, h);

    if (showGlow) {
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            AppPalette.emerald.withValues(alpha: 0.22),
            AppPalette.emerald.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(w / 2, h * 0.55),
          radius: scale * 0.5,
        ));
      canvas.drawCircle(Offset(w / 2, h * 0.55), scale * 0.5, glowPaint);
    }

    final bars = <(double, double, Color, Color)>[
      (0.16, 0.26, const Color(0xFF0B6E56), const Color(0xFF0E8A69)),
      (0.38, 0.37, const Color(0xFF10A876), const Color(0xFF12C28B)),
      (0.60, 0.48, const Color(0xFF34D99F), const Color(0xFF7BF0C0)),
    ];
    final bottom = h * 0.84;
    final barWidth = w * 0.14;
    for (final bar in bars) {
      final rect = Rect.fromLTWH(
        w * bar.$1,
        bottom - h * bar.$2,
        barWidth,
        h * bar.$2,
      );
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bar.$3, bar.$4],
        ).createShader(rect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(barWidth * 0.46)),
        paint,
      );
    }

    final linePaint = Paint()
      ..color = const Color(0xFFDFFFF2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.042
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(w * 0.08, h * 0.58)
      ..lineTo(w * 0.37, h * 0.46)
      ..lineTo(w * 0.66, h * 0.34)
      ..lineTo(w * 0.92, h * 0.22);
    canvas.drawPath(path, linePaint);

    final dotCenter = Offset(w * 0.92, h * 0.22);
    canvas.drawCircle(
      dotCenter,
      w * 0.075,
      Paint()..color = const Color(0xFF8DFFD2),
    );
    canvas.drawCircle(
      dotCenter,
      w * 0.033,
      Paint()..color = AppPalette.charcoal,
    );
  }

  @override
  bool shouldRepaint(covariant _BrandMarkPainter oldDelegate) =>
      oldDelegate.showGlow != showGlow;
}

class BrandHeroMark extends StatelessWidget {
  const BrandHeroMark({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF15251E), Color(0xFF08100C)],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: AppPalette.emerald.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppPalette.emerald.withValues(alpha: 0.22),
            blurRadius: size * 0.5,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      padding: EdgeInsets.all(size * 0.16),
      child: BrandMark(size: size * 0.68, showGlow: true),
    );
  }
}
