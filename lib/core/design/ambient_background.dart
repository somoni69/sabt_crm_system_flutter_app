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
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.background);
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.palette != palette;
}
