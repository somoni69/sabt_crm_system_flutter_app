import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// The wordmark used in the web shell: lowercase "sabt" plus the red dot.
class SabtWordmark extends StatelessWidget {
  const SabtWordmark({
    super.key,
    this.fontSize = 26,
    this.color = AppColors.text,
    this.showDot = true,
  });

  final double fontSize;
  final Color color;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'sabt',
          style: TextStyle(
            fontFamily: AppTypography.family,
            fontSize: fontSize,
            height: 1,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.4,
            color: color,
          ),
        ),
        if (showDot)
          Padding(
            padding: EdgeInsets.only(left: fontSize * 0.055, bottom: fontSize * 0.12),
            child: Container(
              width: fontSize * 0.16,
              height: fontSize * 0.16,
              decoration: const BoxDecoration(
                color: AppColors.brandRed,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

/// The brand S inside a liquid glass sphere. Built with canvas primitives so
/// it stays crisp on every density and never needs a raster asset.
class SabtGlassMark extends StatelessWidget {
  const SabtGlassMark({super.key, this.size = 72, this.glow = true});

  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MarkPainter(glow: glow),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.glow});

  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    if (glow) {
      canvas.drawCircle(
        center,
        radius * 1.04,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppColors.accent.withValues(alpha: 0.44),
              AppColors.accent.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius * 1.5)),
      );
    }

    // Sphere body.
    canvas.drawCircle(
      center,
      radius * 0.86,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1F47), Color(0xFF141020), Color(0xFF0B0912)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // Reflected top-left window light.
    canvas.drawCircle(
      Offset(size.width * 0.33, size.height * 0.26),
      radius * 0.30,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.34),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * 0.33, size.height * 0.26),
            radius: radius * 0.34,
          ),
        ),
    );

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, size.width * 0.014)
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x66FFFFFF), Color(0x10FFFFFF), Color(0x33FFFFFF)],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.86));
    canvas.drawCircle(center, radius * 0.86, rim);

    // The S.
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'S',
        style: TextStyle(
          fontFamily: AppTypography.family,
          fontSize: size.width * 0.62,
          fontWeight: FontWeight.w700,
          height: 1,
          color: Colors.white,
          shadows: [
            Shadow(
              color: AppColors.accent.withValues(alpha: 0.55),
              blurRadius: size.width * 0.12,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2 - size.height * 0.01,
      ),
    );

    // Brand dot.
    final dotCenter = Offset(size.width * 0.77, size.height * 0.23);
    canvas.drawCircle(
      dotCenter,
      radius * 0.17,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFF7B7B), AppColors.brandRed],
        ).createShader(Rect.fromCircle(center: dotCenter, radius: radius * 0.17)),
    );
    canvas.drawCircle(
      dotCenter,
      radius * 0.17,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.012
        ..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) => oldDelegate.glow != glow;
}
