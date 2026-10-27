import 'dart:async';

import 'package:flutter/material.dart';

/// Shared motion for Sabt. Mapped from a transform-and-opacity ladder onto
/// Flutter: short fades for frequent actions, 150–250ms ease-out for sheets
/// and routes, springs only on the nav gesture.
///
/// Entrances start at [enterScale], never at 0. Reduced motion
/// (`MediaQuery.disableAnimations`) resolves to zero duration.
abstract final class Motion {
  static const Duration press = Duration(milliseconds: 100);
  static const Duration micro = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 200);
  static const Duration sheet = Duration(milliseconds: 240);
  static const Duration exit = Duration(milliseconds: 160);

  /// cubic-bezier(0.23, 1, 0.32, 1). Entrances and exits.
  static const Cubic easeOut = Cubic(0.23, 1, 0.32, 1);

  /// cubic-bezier(0.77, 0, 0.175, 1). Motion between two on-screen points.
  static const Cubic easeInOut = Cubic(0.77, 0, 0.175, 1);

  /// cubic-bezier(0.32, 0.72, 0, 1). Sheets and the keyboard hide.
  static const Cubic drawer = Cubic(0.32, 0.72, 0, 1);

  static const double enterScale = 0.96;
  static const double pressScale = 0.97;

  static bool allowed(BuildContext context) =>
      !MediaQuery.disableAnimationsOf(context);

  static Duration duration(BuildContext context, Duration value) =>
      allowed(context) ? value : Duration.zero;

  static AnimationStyle sheetStyle(BuildContext context) {
    if (!allowed(context)) return AnimationStyle.noAnimation;
    return const AnimationStyle(
      duration: sheet,
      reverseDuration: exit,
      curve: drawer,
      reverseCurve: easeOut,
    );
  }
}

/// Route enter and exit: fade plus a short vertical slide. No full-page
/// scale, so the route layer is not resampled on cheap devices.
class MotionPageTransition extends StatefulWidget {
  const MotionPageTransition({
    super.key,
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  State<MotionPageTransition> createState() => _MotionPageTransitionState();
}

class _MotionPageTransitionState extends State<MotionPageTransition> {
  late CurvedAnimation _curved;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _bind(widget.animation);
  }

  void _bind(Animation<double> animation) {
    _curved = CurvedAnimation(
      parent: animation,
      curve: Motion.easeOut,
      reverseCurve: Motion.easeOut,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.02),
      end: Offset.zero,
    ).animate(_curved);
  }

  @override
  void didUpdateWidget(MotionPageTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      _curved.dispose();
      _bind(widget.animation);
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curved,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// One-shot fade and settle for a surface that just arrived. The ticker
/// stops when the animation completes.
class MotionAppear extends StatefulWidget {
  const MotionAppear({
    super.key,
    required this.child,
    this.duration = Motion.micro,
    this.delay = Duration.zero,
    this.dy = 8,
    this.alignment = Alignment.center,
  });

  final Widget child;
  final Duration duration;
  final Duration delay;
  final double dy;
  final Alignment alignment;

  @override
  State<MotionAppear> createState() => _MotionAppearState();
}

class _MotionAppearState extends State<MotionAppear>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;
  bool _started = false;
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!Motion.allowed(context)) {
      _timer?.cancel();
      _settled = true;
      if (_controller.value != 1) _controller.value = 1;
      return;
    }
    if (_started || _settled) return;
    _started = true;
    if (widget.delay == Duration.zero) {
      _controller.forward().whenComplete(_finish);
    } else {
      _timer = Timer(widget.delay, () {
        if (!mounted || !Motion.allowed(context)) return;
        _controller.forward().whenComplete(_finish);
      });
    }
  }

  void _finish() {
    if (!mounted || _settled) return;
    setState(() => _settled = true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_settled || !Motion.allowed(context)) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = Motion.easeOut.transform(_controller.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * widget.dy),
            child: Transform.scale(
              scale: Motion.enterScale + (1 - Motion.enterScale) * t,
              alignment: widget.alignment,
              filterQuality: FilterQuality.low,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Cross-fade (and optional scale) when [child]'s key changes.
/// Size snaps. Layout geometry is not animated.
class MotionSwap extends StatelessWidget {
  const MotionSwap({
    super.key,
    required this.child,
    this.duration = Motion.standard,
    this.scale = true,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final Duration duration;
  final bool scale;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.duration(context, duration),
      switchInCurve: Motion.easeOut,
      switchOutCurve: Motion.easeOut,
      layoutBuilder: (current, previous) {
        return Stack(alignment: alignment, children: [...previous, ?current]);
      },
      transitionBuilder: (child, animation) {
        final fading = FadeTransition(opacity: animation, child: child);
        if (!scale) return fading;
        return AnimatedBuilder(
          animation: animation,
          child: fading,
          builder: (context, fadingChild) {
            final t = animation.value;
            return Transform.scale(
              scale: Motion.enterScale + (1 - Motion.enterScale) * t,
              alignment: alignment,
              filterQuality: FilterQuality.low,
              child: fadingChild,
            );
          },
        );
      },
      child: child,
    );
  }
}
