import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/design/motion.dart';
import '../../../../core/theme/app_colors.dart';

/// Living backdrop for the sign-in screen — and only for it.
///
/// The app shell keeps its ambient background static on purpose (a
/// full-screen ticker behind every page would keep the GPU awake all
/// day). The login screen is the one place where motion earns its cost:
/// three drifting orbs in the brand hue, a slow diagonal light beam and
/// a field of rising particles, all drawn by a single painter.
///
/// The layer paints the graphite base itself and then translucent light
/// over it, lives in its own [RepaintBoundary], and freezes completely
/// under reduced motion.
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
      _controller.value = 0.35;
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
            painter: _AuroraPainter(_controller.value, palette),
            size: Size.infinite,
            isComplex: true,
            willChange: true,
          );
        },
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.t, this.palette);

  /// Loop phase, 0..1.
  final double t;
  final AppPalette palette;

  static final List<_Particle> _particles = _seedParticles();

  static List<_Particle> _seedParticles() {
    final random = math.Random(42);
    return List.generate(22, (index) {
      return _Particle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        radius: 0.8 + random.nextDouble() * 1.6,
        speed: 0.012 + random.nextDouble() * 0.03,
        twinkle: random.nextDouble() * math.pi * 2,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final phase = t * math.pi * 2;

    // Graphite base, matching the shell's ambient canvas. Painting it
    // here makes the login screen self-contained: the orbs below are
    // translucent light and would wash out over any foreign backdrop.
    canvas.drawRect(
      rect,
      Paint()
        ..shader =  LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.isDark ? const [Color(0xFF090C14), Color(0xFF06080E), Color(0xFF05070C)] : [const Color(0xFFF8F9FC), palette.background, palette.backgroundDeep],
          stops: [0.0, 0.48, 1.0],
        ).createShader(rect),
    );

    _orb(
      canvas,
      center: Offset(
        size.width * (0.84 + math.sin(phase) * 0.05),
        size.height * (0.08 + math.cos(phase) * 0.03),
      ),
      radius: size.width * 0.85,
      color: palette.accent.withValues(alpha: palette.isDark ? 0.14 : 0.18),
    );
    _orb(
      canvas,
      center: Offset(
        size.width * (-0.10 - math.cos(phase) * 0.04),
        size.height * (0.55 + math.sin(phase) * 0.04),
      ),
      radius: size.width * 0.75,
      color: palette.ice.withValues(alpha: palette.isDark ? 0.06 : 0.10),
    );
    _orb(
      canvas,
      center: Offset(
        size.width * (0.35 + math.sin(phase + 1.4) * 0.06),
        size.height * (1.02 + math.cos(phase + 1.4) * 0.02),
      ),
      radius: size.width * 0.60,
      color: palette.brandPurple.withValues(alpha: 0.10),
    );

    // Diagonal light beam, breathing across the upper third.
    final beam = Rect.fromLTWH(
      -size.width * 0.2,
      size.height * (0.02 + math.sin(phase) * 0.015),
      size.width * 1.4,
      size.height * 0.30,
    );
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-0.32);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.drawRect(
      beam,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0),
            palette.accentBright.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(beam),
    );
    canvas.restore();

    // Rising particles with a soft twinkle.
    for (final particle in _particles) {
      final y = (particle.y - t * particle.speed * 10) % 1.0;
      final resolvedY = y < 0 ? y + 1 : y;
      final alpha =
          0.10 + 0.16 * (0.5 + 0.5 * math.sin(phase * 2 + particle.twinkle));
      canvas.drawCircle(
        Offset(particle.x * size.width, resolvedY * size.height),
        particle.radius,
        Paint()
          ..color = (palette.isDark ? Colors.white : palette.accent)
              .withValues(alpha: alpha),
      );
    }

    // Readability vignette: darker at the very bottom where the
    // footnote and keyboard live.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, size.height * 0.55),
          Offset(0, size.height),
          palette.isDark
              ? const [Color(0x00000000), Color(0x59000000)]
              : const [Color(0x00000000), Color(0x120F1830)],
        ),
    );
  }

  void _orb(
    Canvas canvas, {
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
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.palette != palette;
}

class _Particle {
  const _Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.twinkle,
  });

  final double x;
  final double y;
  final double radius;
  final double speed;
  final double twinkle;
}
