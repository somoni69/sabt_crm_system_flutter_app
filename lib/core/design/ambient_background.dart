import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// The environment the glass refracts. A single custom painter keeps this
/// cheap: no shader packages, no blur widgets behind every page.
///
/// The shell passes [animate] false. The drift is a full-screen tick that
/// never goes idle, which keeps the GPU awake on cheap Android devices.
/// One composed frame still draws the orbs, grid, and horizon.
class AmbientBackground extends StatefulWidget {
  const AmbientBackground({super.key, this.animate = true});

  final bool animate;

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 26),
    );
    if (widget.animate) _controller.repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
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
    final reduce = MediaQuery.disableAnimationsOf(context);
    final drifting = widget.animate && !reduce;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = drifting ? _controller.value : 0.35;
          return CustomPaint(
            painter: _AmbientPainter(t, palette),
            size: Size.infinite,
            isComplex: true,
            willChange: drifting,
          );
        },
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter(this.t, this.palette);

  final double t;
  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final dark = palette.isDark;

    // Canvas base: deep graphite in dark mode, porcelain in light.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF090C14), Color(0xFF06080E), Color(0xFF05070C)]
              : [
                  const Color(0xFFF8F9FC),
                  palette.background,
                  palette.backgroundDeep,
                ],
          stops: const [0.0, 0.48, 1.0],
        ).createShader(rect),
    );

    final drift = math.sin(t * math.pi * 2);

    _orb(
      canvas,
      size,
      center: Offset(
        size.width * (0.82 + drift * 0.05),
        size.height * (0.10 + math.cos(t * math.pi * 2) * 0.03),
      ),
      radius: size.width * 0.82,
      color: palette.accent.withValues(alpha: dark ? 0.26 : 0.16),
    );
    _orb(
      canvas,
      size,
      center: Offset(
        size.width * (-0.12 - drift * 0.04),
        size.height * (0.56 + drift * 0.04),
      ),
      radius: size.width * 0.78,
      color: palette.ice.withValues(alpha: dark ? 0.11 : 0.10),
    );
    _orb(
      canvas,
      size,
      center: Offset(
        size.width * (0.44 - drift * 0.06),
        size.height * (1.04 - math.cos(t * math.pi * 2) * 0.03),
      ),
      radius: size.width * 0.62,
      color: palette.brandRed.withValues(alpha: dark ? 0.045 : 0.05),
    );
    _orb(
      canvas,
      size,
      center: Offset(size.width * 0.12, size.height * 0.02),
      radius: size.width * 0.34,
      color: Colors.white.withValues(alpha: dark ? 0.035 : 0.5),
    );

    // Fine engineering grid; almost invisible, but gives the glass a surface
    // to reflect instead of an empty gradient.
    final grid = Paint()
      ..color = (dark ? Colors.white : palette.text)
          .withValues(alpha: dark ? 0.018 : 0.03)
      ..strokeWidth = 0.6;
    const step = 44.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Vignette keeps chrome readable near the edges.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.5, size.height * 0.42),
          size.longestSide * 0.78,
          dark
              ? const [Color(0x00000000), Color(0x66000000)]
              : const [Color(0x00000000), Color(0x140F1830)],
          const [0.55, 1.0],
        ),
    );

    // A woven light-line across the top — the "liquid" horizon.
    final horizon = Path()
      ..moveTo(0, size.height * 0.18)
      ..cubicTo(
        size.width * 0.3,
        size.height * (0.13 + drift * 0.02),
        size.width * 0.68,
        size.height * (0.22 - drift * 0.02),
        size.width,
        size.height * 0.15,
      );
    canvas.drawPath(
      horizon,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            palette.accentBright.withValues(alpha: dark ? 0.16 : 0.22),
            palette.ice.withValues(alpha: dark ? 0.10 : 0.16),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
  }

  void _orb(
    Canvas canvas,
    Size size, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          radius,
          [color, color.withValues(alpha: 0)],
          const [0.0, 1.0],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.palette != palette;
}
