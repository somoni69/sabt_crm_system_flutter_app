import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

enum LoginButtonPhase { idle, loading, success }

/// Primary sign-in button with three choreographed states.
///
/// * idle — label and arrow, ready;
/// * loading — the arrow gives way to a spinner and the label becomes
///   "Входим…", so the user reads progress, not just motion;
/// * success — a check is drawn stroke-by-stroke inside a ring before
///   the router carries the user into the workspace.
///
/// Content cross-fades with a small scale settle; the plate itself
/// never resizes, so nothing below it jumps. Press feedback matches
/// the shared [Motion.pressScale] ladder.
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
    final success = widget.phase == LoginButtonPhase.success;

    final content = switch (widget.phase) {
      LoginButtonPhase.idle => Row(
        key: const ValueKey('idle'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.label,
            style: const TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.05,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 9),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: Colors.white,
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
              fontSize: 15,
              fontWeight: FontWeight.w600,
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
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    };

    final plate = AnimatedContainer(
      duration: animate ? Motion.standard : Duration.zero,
      curve: Motion.easeOut,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: success
              ? const [Color(0xFF3ECF8E), Color(0xFF1F9D63)]
              :  [Color(0xFF7A63E0), context.palette.brandPurple],
        ),
        boxShadow: [
          BoxShadow(
            color: (success ? context.palette.success : context.palette.accent).withValues(
              alpha: 0.30,
            ),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 1,
            left: 16,
            right: 16,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: 0.32),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          Opacity(
            opacity: _enabled || widget.phase != LoginButtonPhase.idle
                ? 1
                : 0.45,
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
        ],
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
          scale: _pressed && animate ? Motion.pressScale : 1,
          duration: animate ? Motion.press : Duration.zero,
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
