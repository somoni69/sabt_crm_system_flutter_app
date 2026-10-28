import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

enum LoginButtonPhase { idle, loading, success }

/// Tactile primary sign-in button with a physical 3D bottom lip and
/// three choreographed states (`idle` → `loading` → `success`).
///
/// Pressing the button physically depresses the plate onto its bottom
/// ledge (2 px vertical travel + lip compression), matching the tactile
/// hardware feel of benchmark iOS onboarding/login buttons.
class LoginButton extends StatefulWidget {
  const LoginButton({
    super.key,
    required this.phase,
    required this.label,
    this.onPressed,
  });

  final LoginButtonPhase phase;
  final String label;
  final VoidCallback? onPressed;

  @override
  State<LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<LoginButton> {
  bool _pressed = false;

  bool get _enabled =>
      widget.onPressed != null && widget.phase == LoginButtonPhase.idle;

  @override
  Widget build(BuildContext context) {
    final animate = Motion.allowed(context);
    final palette = context.palette;
    final success = widget.phase == LoginButtonPhase.success;
    final depressed = _pressed && _enabled && animate;

    final baseColor = success
        ? const Color(0xFF1F9D63)
        : palette.brandPurple;
    final topColor = Color.alphaBlend(
      Colors.white.withValues(alpha: 0.14),
      baseColor,
    );
    final lipColor = success
        ? const Color(0xFF12633D)
        : const Color(0xFF392B6E);

    final content = switch (widget.phase) {
      LoginButtonPhase.idle => Row(
        key: const ValueKey('idle'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.label,
            style: const TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
        ],
      ),
      LoginButtonPhase.loading => const Row(
        key: ValueKey('loading'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 17,
            height: 17,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 10),
          Text(
            'Входим…',
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
              color: Colors.white,
            ),
          ),
        ],
      ),
      LoginButtonPhase.success => const Row(
        key: ValueKey('success'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _AnimatedCheck(),
          SizedBox(width: 10),
          Text(
            'Добро пожаловать',
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
              color: Colors.white,
            ),
          ),
        ],
      ),
    };

    final activeDuration = animate
        ? (_pressed ? Motion.press : Motion.release)
        : Duration.zero;

    final plate = AnimatedContainer(
      duration: activeDuration,
      curve: Motion.easeOut,
      height: 56,
      transform: Matrix4.translationValues(0, depressed ? 2.0 : 0.0, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topColor, baseColor],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: lipColor,
            offset: Offset(0, depressed ? 1.5 : 3.5),
            blurRadius: 0,
          ),
          BoxShadow(
            color: baseColor.withValues(alpha: depressed ? 0.16 : 0.28),
            blurRadius: depressed ? 12 : 22,
            offset: Offset(0, depressed ? 4 : 10),
          ),
        ],
      ),
      child: Opacity(
        opacity: _enabled || widget.phase != LoginButtonPhase.idle ? 1 : 0.5,
        child: AnimatedSwitcher(
          duration: animate ? Motion.standard : Duration.zero,
          switchInCurve: Motion.easeOut,
          switchOutCurve: Motion.easeOut,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(
                  begin: Motion.enterScale,
                  end: 1,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: content,
        ),
      ),
    );

    if (!_enabled) {
      return Semantics(button: true, label: widget.label, child: plate);
    }

    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onPressed!();
        },
        child: AnimatedScale(
          scale: depressed ? 0.985 : 1,
          duration: activeDuration,
          curve: Motion.easeOut,
          child: plate,
        ),
      ),
    );
  }
}

/// Check drawn with a stroke sweep inside a ring that scales in.
class _AnimatedCheck extends StatefulWidget {
  const _AnimatedCheck();

  @override
  State<_AnimatedCheck> createState() => _AnimatedCheckState();
}

class _AnimatedCheckState extends State<_AnimatedCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.allowed(context)) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _CheckPainter(Motion.easeOut.transform(_controller.value)),
          );
        },
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 1;

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Colors.white.withValues(alpha: 0.55 * t);
    canvas.drawCircle(center, radius * (0.7 + 0.3 * t), ring);

    if (t <= 0.15) return;
    final progress = ((t - 0.15) / 0.85).clamp(0.0, 1.0);
    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.68)
      ..lineTo(size.width * 0.74, size.height * 0.34);

    final metric = path.computeMetrics().first;
    final partial = metric.extractPath(0, metric.length * progress);
    canvas.drawPath(
      partial,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) => oldDelegate.t != t;
}
