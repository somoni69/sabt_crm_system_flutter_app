import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/design/motion.dart';

/// Horizontal shake that is triggered by bumping [signal].
///
/// Used exactly once per rejected sign-in attempt: a validation error or
/// a server refusal. The motion is a damped sine — four visible swings
/// that settle to zero — so it reads as "no" without ever moving layout.
/// Reduced motion collapses it to nothing.
class Shake extends StatefulWidget {
  const Shake({super.key, required this.child, this.signal = 0});

  final Widget child;

  /// Increment to shake. The initial value never triggers.
  final int signal;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(Shake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.signal != oldWidget.signal && widget.signal > 0) {
      if (Motion.allowed(context)) {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        final offset = t == 0 || t == 1
            ? 0.0
            : math.sin(t * math.pi * 4) * 9 * (1 - t);
        // Always the same Transform wrapper: swapping between the bare
        // child and a Transform would remount the form inside on every
        // shake and drop field state mid-interaction.
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
    );
  }
}
