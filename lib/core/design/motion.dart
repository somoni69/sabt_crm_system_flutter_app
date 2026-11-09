import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Shared motion for Sabt. Mapped from a transform-and-opacity ladder onto
/// Flutter: short fades for frequent actions, 150–250ms ease-out for sheets
/// and routes, springs only on the nav gesture and interactive drag surfaces.
///
/// Entrances start at [enterScale], never at 0. Reduced motion
/// (`MediaQuery.disableAnimations`) resolves to zero duration.
abstract final class Motion {
  static const Duration press = Duration(milliseconds: 100);
  static const Duration micro = Duration(milliseconds: 120);

  /// Asymmetric release after a press-down: slightly gentler than [press]
  /// so tactile controls rebound with physical weight instead of snapping.
  static const Duration release = Duration(milliseconds: 140);

  static const Duration standard = Duration(milliseconds: 200);
  static const Duration sheet = Duration(milliseconds: 240);
  static const Duration exit = Duration(milliseconds: 160);

  /// Per-item stagger step for list/card cascades, capped so the last item
  /// never starts more than 210ms after the first.
  static const Duration stagger = Duration(milliseconds: 35);

  static Duration staggerDelay(int index, {int maxItems = 6}) =>
      Duration(milliseconds: index.clamp(0, maxItems) * stagger.inMilliseconds);

  /// Route push, modelled on the native iOS push: the incoming page
  /// slides over a parallaxing previous page. Occasional, spatial —
  /// it earns its 180ms. The pop is a touch shorter so leaving always
  /// feels faster than arriving.
  static const Duration page = Duration(milliseconds: 180);
  static const Duration pageExit = Duration(milliseconds: 140);

  /// Spring for gesture-carrying elements (the nav lens and interactive
  /// preview cards). Underdamped (ratio ~0.69), so a flick lands with one
  /// soft overshoot, exactly like UIKit's interruptible springs. Only for
  /// elements the finger can still be holding when the target changes.
  static const SpringDescription springSnap = SpringDescription(
    mass: 1,
    stiffness: 380,
    damping: 27,
  );

  /// Orchestrated entrance of a whole screen (login, splash, onboarding).
  /// Individual elements take a slice of this timeline via an [Interval],
  /// so the whole choreography runs on a single ticker.
  static const Duration entrance = Duration(milliseconds: 950);

  /// Slow, ambient loop (breathing glow, drifting orbs). Never used for
  /// content that carries information — decoration only.
  static const Duration ambient = Duration(seconds: 14);

  /// cubic-bezier(0.23, 1, 0.32, 1). Entrances and exits.
  static const Cubic easeOut = Cubic(0.23, 1, 0.32, 1);

  /// Gentle overshoot for a single hero element (the brand mark landing).
  /// Scale only, never layout, and never on more than one element at a time.
  static const Cubic spring = Cubic(0.34, 1.28, 0.64, 1);

  /// cubic-bezier(0.77, 0, 0.175, 1). Motion between two on-screen points.
  static const Cubic easeInOut = Cubic(0.77, 0, 0.175, 1);

  /// cubic-bezier(0.32, 0.72, 0, 1). Sheets and the keyboard hide.
  static const Cubic drawer = Cubic(0.32, 0.72, 0, 1);

  static const double enterScale = 0.96;
  static const double pressScale = 0.97;

  /// True on iOS/macOS. Drives platform-specific motion: full parallax push
  /// and live backdrop blur on Apple, lighter fade+slide and opaque
  /// surfaces elsewhere, so Android holds frame rate on every tier.
  static bool isApple(BuildContext context) {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  }

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

/// Route transition modelled on the native iOS push.
///
/// * Push: the incoming page slides in from the right edge over the
///   previous one, which parallaxes a quarter-width to the left and
///   dims under a scrim — the spatial model every iOS user already
///   knows. A soft shadow rides the incoming page's left edge.
/// * Pop: the same system in reverse, slightly faster ([Motion.pageExit]
///   at the page level), so leaving always feels lighter than arriving.
///
/// Only `transform` and `opacity` move. The previous-page effect is
/// driven by [secondaryAnimation]; when nobody is covering this page
/// it stays at rest and costs one static transform.
class MotionPageTransition extends StatefulWidget {
  const MotionPageTransition({
    super.key,
    required this.animation,
    required this.child,
    this.secondaryAnimation,
  });

  final Animation<double> animation;
  final Animation<double>? secondaryAnimation;
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
      begin: const Offset(0.06, 0),
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
    final secondary = widget.secondaryAnimation;

    // Non-Apple platforms get a lite variant: short slide + fade, with no
    // edge shade and no full-page parallax/scrim on the covered page. That
    // removes two extra full-screen layers per frame, which is what costs
    // frames on mid/low-end Android, and matches Material's own idiom.
    // Pages are transparent Scaffolds over a shared background, so the
    // incoming page must carry its own opaque backing or the covered page
    // shows through mid-flight. The RepaintBoundary rasterizes the page
    // once; the slide is then a pure layer translation with no per-frame
    // repaint of the page subtree.
    final backed = ColoredBox(
      color: context.palette.background,
      child: RepaintBoundary(child: widget.child),
    );

    if (!Motion.isApple(context)) {
      // Slide only: no FadeTransition, which would force an offscreen
      // saveLayer of the whole page every frame.
      return SlideTransition(
        position: _curved.drive(
          Tween<Offset>(begin: const Offset(0.2, 0), end: Offset.zero),
        ),
        child: backed,
      );
    }

    // Edge shade instead of a BoxShadow: a 28px gradient strip riding
    // the incoming page's left edge, visible only mid-flight. No blur
    // filter ever runs on the page layer.
    Widget page = SlideTransition(
      position: _slide,
      child: Stack(
        children: [
          backed,
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 28,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _curved,
                builder: (context, _) {
                  final shade = (1 - _curved.value) * 0.22;
                  if (shade <= 0) return const SizedBox.shrink();
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: shade),
                          Colors.black.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
    if (secondary == null) return page;

    return AnimatedBuilder(
      animation: secondary,
      child: page,
      builder: (context, child) {
        final t = Motion.easeOut.transform(secondary.value.clamp(0, 1));
        if (t == 0) return child!;
        return Transform.translate(
          offset: Offset(-0.25 * t * MediaQuery.sizeOf(context).width, 0),
          child: Stack(
            children: [
              child!,
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.14 * t),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
    if (!Motion.allowed(context)) return widget.child;
    // The AnimatedBuilder wrapper is kept even after settling: swapping
    // to the bare child at completion would remount the subtree and
    // reset any state inside it. At rest the controller no longer
    // notifies, so the stable wrapper costs nothing.
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

/// One slice of a shared entrance timeline.
///
/// The parent owns a single [AnimationController] (usually
/// [Motion.entrance] long) and every element declares the slice it
/// occupies — `begin`/`end` as fractions of that timeline. One ticker
/// therefore drives the whole choreography, elements never start before
/// the first frame is painted, and reduced motion collapses the slice
/// by jumping the parent controller straight to 1.
///
/// Only opacity and transform are animated; layout never moves, so a
/// staggered column cannot reflow while it is still appearing.
class StaggeredEntrance extends StatelessWidget {
  const StaggeredEntrance({
    super.key,
    required this.animation,
    required this.child,
    this.begin = 0,
    this.end = 1,
    this.dy = 18,
    this.scaleFrom = Motion.enterScale,
    this.curve = Motion.easeOut,
  }) : assert(begin >= 0 && begin < end && end <= 1);

  final Animation<double> animation;
  final Widget child;
  final double begin;
  final double end;
  final double dy;
  final double scaleFrom;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    if (!Motion.allowed(context)) return child;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final raw = ((animation.value - begin) / (end - begin)).clamp(0.0, 1.0);
        final t = curve.transform(raw);
        // The wrapper structure never changes, even at t == 1: returning
        // the bare child at the end would remount the subtree and reset
        // any state inside it (a stateful hero would restart its own
        // entrance, a field would lose its selection).
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * dy),
            child: Transform.scale(
              scale: scaleFrom + (1 - scaleFrom) * t,
              filterQuality: FilterQuality.low,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Cross-fade (and optional scale / height glide) when [child]'s key changes.
class MotionSwap extends StatelessWidget {
  const MotionSwap({
    super.key,
    required this.child,
    this.duration = Motion.standard,
    this.scale = true,
    this.animateSize = false,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final Duration duration;
  final bool scale;
  final bool animateSize;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final effectiveDuration = Motion.duration(context, duration);
    Widget switcher = AnimatedSwitcher(
      duration: effectiveDuration,
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

    if (!animateSize || !Motion.allowed(context)) return switcher;
    return AnimatedSize(
      duration: effectiveDuration,
      curve: Motion.drawer,
      alignment: alignment,
      clipBehavior: Clip.none,
      child: switcher,
    );
  }
}
