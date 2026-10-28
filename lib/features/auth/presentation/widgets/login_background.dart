import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/design/motion.dart';
import '../../../../core/theme/app_colors.dart';

/// Editorial studio backdrop for the sign-in screen.
///
/// Replaces generic dark-purple AI aurora blobs with a grounded,
/// high-craft studio canvas:
/// * warm porcelain in light mode, deep obsidian in dark mode;
/// * a subtle radial dot-matrix architectural grid across the upper
///   stage that fades smoothly into the canvas;
/// * gentle ambient studio light at the top edge, isolated inside its
///   own [RepaintBoundary] and frozen under reduced motion.
class LoginBackground extends StatefulWidget {
  const LoginBackground({super.key});

  @override
  State<LoginBackground> createState() => _LoginBackgroundState();
}

class _LoginBackgroundState extends State<LoginBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.ambient,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.allowed(context)) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0.25;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _StudioStagePainter(_controller.value, palette),
            size: Size.infinite,
            isComplex: true,
            willChange: Motion.allowed(context),
          );
        },
      ),
    );
  }
}

class _StudioStagePainter extends CustomPainter {
  _StudioStagePainter(this.t, this.palette);

  final double t;
  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final phase = t * math.pi * 2;
    final isDark = palette.isDark;

    // 1. Grounded editorial canvas base.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [
                  Color(0xFF0B0F1A),
                  Color(0xFF070A11),
                  Color(0xFF05070C),
                ]
              : const [
                  Color(0xFFFBF9FE),
                  Color(0xFFF4F2FA),
                  Color(0xFFECEFF7),
                ],
          stops: const [0.0, 0.52, 1.0],
        ).createShader(rect),
    );

    // 2. Soft top-stage daylight wash (gives the floating hero cards
    //    a distinct stage without looking like neon glow).
    final topLightCenter = Offset(
      size.width * (0.50 + math.sin(phase) * 0.03),
      size.height * (0.14 + math.cos(phase) * 0.015),
    );
    final topLightRadius = size.width * 0.92;
    canvas.drawCircle(
      topLightCenter,
      topLightRadius,
      Paint()
        ..shader = ui.Gradient.radial(
          topLightCenter,
          topLightRadius,
          [
            palette.brandPurple.withValues(alpha: isDark ? 0.14 : 0.09),
            palette.ice.withValues(alpha: isDark ? 0.04 : 0.05),
            palette.brandPurple.withValues(alpha: 0),
          ],
          const [0.0, 0.55, 1.0],
        ),
    );

    // 3. Secondary warm/cool periphery accent on the upper right.
    final warmCenter = Offset(
      size.width * (0.86 - math.cos(phase) * 0.03),
      size.height * 0.08,
    );
    canvas.drawCircle(
      warmCenter,
      size.width * 0.48,
      Paint()
        ..shader = ui.Gradient.radial(
          warmCenter,
          size.width * 0.48,
          [
            palette.brandRed.withValues(alpha: isDark ? 0.06 : 0.045),
            palette.brandRed.withValues(alpha: 0),
          ],
        ),
    );

    // 4. Architectural dot matrix across the upper hero stage, masked
    //    radially so it frames the floating cards cleanly.
    const step = 24.0;
    final maxY = size.height * 0.46;
    final focal = Offset(size.width * 0.5, size.height * 0.20);
    final maxDist = size.width * 0.62;
    final dotBase = isDark ? Colors.white : const Color(0xFF161B2D);

    for (double y = 18; y < maxY; y += step) {
      for (double x = 18; x < size.width - 12; x += step) {
        final pt = Offset(x, y);
        final dist = (pt - focal).distance;
        if (dist >= maxDist) continue;
        final fade = (1.0 - (dist / maxDist)).clamp(0.0, 1.0);
        final alpha = (isDark ? 0.08 : 0.07) * fade * fade;
        if (alpha <= 0.005) continue;
        canvas.drawCircle(
          pt,
          1.15,
          Paint()..color = dotBase.withValues(alpha: alpha),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StudioStagePainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.palette != palette;
}
