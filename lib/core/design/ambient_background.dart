import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The environment the glass refracts. A single custom painter keeps this
/// cheap: no shader packages, no blur widgets behind every page.
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
    final reduce = MediaQuery.disableAnimationsOf(context);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = reduce ? 0.35 : _controller.value;
          return CustomPaint(
            painter: _AmbientPainter(t),
            size: Size.infinite,
            isComplex: true,
            willChange: !reduce,
          );
        },
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Deep graphite base.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF090C14),
            AppColors.background,
            Color(0xFF05070C),
          ],
          stops: [0.0, 0.48, 1.0],
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
      color: AppColors.accent.withValues(alpha: 0.26),
    );
    _orb(
      canvas,
      size,
      center: Offset(
        size.width * (-0.12 - drift * 0.04),
        size.height * (0.56 + drift * 0.04),
      ),
      radius: size.width * 0.78,
      color: AppColors.ice.withValues(alpha: 0.11),
    );
    _orb(
      canvas,
      size,
      center: Offset(
        size.width * (0.44 - drift * 0.06),
        size.height * (1.04 - math.cos(t * math.pi * 2) * 0.03),
      ),
      radius: size.width * 0.62,
      color: AppColors.brandRed.withValues(alpha: 0.045),
    );
    _orb(
      canvas,
      size,
      center: Offset(size.width * 0.12, size.height * 0.02),
      radius: size.width * 0.34,
      color: Colors.white.withValues(alpha: 0.035),
    );

    // Fine engineering grid; almost invisible, but gives the glass a surface
    // to reflect instead of an empty gradient.
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.018)
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
          const [Color(0x00000000), Color(0x66000000)],
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
            AppColors.accentBright.withValues(alpha: 0.16),
            AppColors.ice.withValues(alpha: 0.10),
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
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) => oldDelegate.t != t;
}
