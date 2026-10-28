import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'glass_surface.dart';
import 'glass_tokens.dart';
import 'motion.dart';

class GlassNavItem {
  const GlassNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// How far the lens may travel past the first or last tab, in tab units.
const navEdgeOverscroll = 0.25;

/// Capsule width of the moving lens. The upper bound stays at least the
/// lower bound so a narrow split-screen width cannot throw in [num.clamp].
double navLensWidth({required double tabWidth, required double lift}) {
  final grown = tabWidth - 10 + lift * 6;
  final upper = tabWidth + 2;
  final maxExtent = upper < 40 ? 40.0 : upper;
  return grown.clamp(40.0, maxExtent).toDouble();
}

/// Capsule height of the moving lens.
double navLensHeight(double lift) => 50 + lift * 4;

/// Maps a finger position in tab units onto the lens position.
///
/// [raw] is `localX / tabWidth - 0.5`, so `0` is the center of the first
/// tab. Inside the tabs the mapping is linear. Past either end it eases
/// out and then stops at [navEdgeOverscroll].
double resistNavPosition(double raw, int itemCount) {
  if (itemCount < 1) return 0;
  final max = (itemCount - 1).toDouble();
  final double curved;
  if (raw < 0) {
    final diff = -raw;
    curved = -(1 - (1 / (diff * 0.5 + 1))) * 0.35;
  } else if (raw > max) {
    final diff = raw - max;
    curved = max + (1 - (1 / (diff * 0.5 + 1))) * 0.35;
  } else {
    curved = raw;
  }
  final limit = max + navEdgeOverscroll;
  return curved.clamp(-navEdgeOverscroll, limit).toDouble();
}

/// Tab index selected when a scrub ends.
///
/// A release faster than 1.1 tabs/second biases the landing by 0.4 tab in
/// the flick direction. The result is always inside `0 .. itemCount - 1`.
int settleNavIndex({
  required double position,
  required double velocityTabs,
  required int itemCount,
}) {
  if (itemCount < 1) return 0;
  final max = itemCount - 1;
  final stepped = velocityTabs.abs() > 1.1
      ? position + velocityTabs.sign * 0.4
      : position;
  return stepped.round().clamp(0, max);
}

/// Converts a pointer fling into tabs/second and caps it.
///
/// Only the sign affects [settleNavIndex]. The cap keeps the release spring
/// from throwing the lens far outside the capsule.
double navFlingVelocity(double pixelsPerSecond, double tabWidth) {
  if (tabWidth <= 0 || pixelsPerSecond == 0) return 0;
  return (pixelsPerSecond / tabWidth).clamp(-3.5, 3.5).toDouble();
}

BoxDecoration _lensDecoration(AppPalette palette) => BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      palette.accent.withValues(alpha: 0.30),
      palette.accentDeep.withValues(alpha: 0.42),
    ],
  ),
  borderRadius: const BorderRadius.all(Radius.circular(GlassTokens.radiusPill)),
  border: Border.all(color: palette.glassRim, width: GlassTokens.hairline),
);

BoxDecoration _actionDecoration(AppPalette palette) => BoxDecoration(
  shape: BoxShape.circle,
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [palette.accent, palette.accentDeep],
  ),
  border: Border.all(color: palette.glassRim, width: GlassTokens.hairline),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.32),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: palette.accent.withValues(alpha: 0.28),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ],
);

const _labelStyle = TextStyle(
  fontFamily: AppTypography.family,
  fontSize: 9.2,
  height: 1.1,
  letterSpacing: 0.1,
  fontWeight: FontWeight.w500,
);

const _labelStyleActive = TextStyle(
  fontFamily: AppTypography.family,
  fontSize: 9.2,
  height: 1.1,
  letterSpacing: 0.1,
  fontWeight: FontWeight.w600,
);

const SpringDescription _navSpring = Motion.springSnap;

/// Liquid glass navigation chrome: a floating capsule, a spring-driven
/// lens, and a detached circular action.
///
/// The plate is opaque glass: [context.palette.glassTint] composited on the
/// canvas, plus the shared rim. It stays on screen over scrolling pages and
/// the ambient layer, so a live [BackdropFilter] would recomposite every
/// frame on low-end GPUs. The lens is a solid tinted capsule. The action
/// is an opaque fill — its previous frost sat under a nearly solid gradient.
class LiquidGlassNavBar extends StatefulWidget {
  const LiquidGlassNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.onAction,
    this.actionIcon = Icons.add_rounded,
    this.actionTooltip = 'Создать',
  }) : assert(items.length >= 2 && items.length <= 5);

  /// Lens render box, for tests that need to read its position.
  @visibleForTesting
  static const Key lensKey = Key('sabt.glassNav.lens');

  /// Tab capsule render box, for tests that need its bounds.
  @visibleForTesting
  static const Key capsuleKey = Key('sabt.glassNav.capsule');

  final List<GlassNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onAction;
  final IconData actionIcon;
  final String actionTooltip;

  @override
  State<LiquidGlassNavBar> createState() => _LiquidGlassNavBarState();
}

class _LiquidGlassNavBarState extends State<LiquidGlassNavBar>
    with TickerProviderStateMixin {
  late final AnimationController _position;
  late final AnimationController _lift;
  late final AnimationController _actionScale;

  late double _goal;
  int _motionTicket = 0;
  bool _dragging = false;
  bool _reduceMotion = false;

  static const _barHeight = 66.0;

  @override
  void initState() {
    super.initState();
    final initial = _clampedIndex(widget.selectedIndex).toDouble();
    _goal = initial;
    _position = AnimationController.unbounded(vsync: this, value: initial);
    _lift = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _actionScale = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      lowerBound: 0.92,
      upperBound: 1,
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant LiquidGlassNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dragging) return;
    final indexChanged = oldWidget.selectedIndex != widget.selectedIndex;
    final countChanged = oldWidget.items.length != widget.items.length;
    if (!indexChanged && !countChanged) return;
    final target = _clampedIndex(widget.selectedIndex).toDouble();
    // A scrub already launched this spring, including its release velocity.
    // Starting again from didUpdateWidget would zero that velocity.
    if (_goal == target) return;
    _springTo(widget.selectedIndex);
  }

  @override
  void dispose() {
    _position.dispose();
    _lift.dispose();
    _actionScale.dispose();
    super.dispose();
  }

  int _clampedIndex(int index) {
    final max = widget.items.length - 1;
    if (max < 0) return 0;
    return index.clamp(0, max);
  }

  void _syncMotion(bool reduce) {
    final turnedOn = reduce && !_reduceMotion;
    _reduceMotion = reduce;
    if (!turnedOn) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_reduceMotion) return;
      _motionTicket++;
      _lift.value = 0;
      _actionScale.value = 1;
      if (_dragging) return;
      _position
        ..stop()
        ..value = _goal;
    });
  }

  void _springTo(int index, {double velocity = 0}) {
    final target = _clampedIndex(index).toDouble();
    _goal = target;
    if (_reduceMotion) {
      _motionTicket++;
      _position.stop();
      _lift.value = 0;
      _position.value = target;
      return;
    }
    final ticket = ++_motionTicket;
    final simulation = SpringSimulation(
      _navSpring,
      _position.value,
      target,
      velocity,
    );
    _lift.forward();
    _position.animateWith(simulation).whenComplete(() {
      if (ticket != _motionTicket || _dragging || !mounted) return;
      _lift.reverse();
    });
  }

  void _commit(int index, {double velocity = 0, bool heavy = false}) {
    final target = _clampedIndex(index);
    if (target != widget.selectedIndex) {
      if (heavy) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
      widget.onSelected(target);
    }
    _springTo(target, velocity: velocity);
  }

  void _onTap(double x, double tabWidth) {
    if (tabWidth <= 0) return;
    final index = (x / tabWidth).floor().clamp(0, widget.items.length - 1);
    _commit(index);
  }

  void _trackFinger(double localX, double tabWidth) {
    if (tabWidth <= 0) return;
    final raw = localX / tabWidth - 0.5;
    _position.value = resistNavPosition(raw, widget.items.length);
  }

  void _onPanStart(DragStartDetails details, double tabWidth) {
    _dragging = true;
    _motionTicket++;
    _position.stop();
    if (!_reduceMotion) _lift.forward();
    HapticFeedback.selectionClick();
    // The accepting sample is not delivered again as an update. A fast scrub
    // can be one move plus an up, so the lens has to follow this point too.
    _trackFinger(details.localPosition.dx, tabWidth);
  }

  void _onPanUpdate(DragUpdateDetails details, double tabWidth) {
    _trackFinger(details.localPosition.dx, tabWidth);
  }

  void _onPanEnd(DragEndDetails details, double tabWidth) {
    _dragging = false;
    final velocity = navFlingVelocity(
      details.velocity.pixelsPerSecond.dx,
      tabWidth,
    );
    final target = settleNavIndex(
      position: _position.value,
      velocityTabs: velocity,
      itemCount: widget.items.length,
    );
    _commit(target, velocity: velocity, heavy: true);
  }

  void _onPanCancel() {
    if (!_dragging) return;
    _dragging = false;
    _springTo(widget.selectedIndex);
  }

  void _setActionPressed(bool pressed) {
    if (_reduceMotion) return;
    if (pressed) {
      _actionScale.reverse();
    } else {
      _actionScale.forward();
    }
  }

  int _visualIndex(double position) {
    if (!_dragging) return _clampedIndex(widget.selectedIndex);
    return settleNavIndex(
      position: position,
      velocityTabs: 0,
      itemCount: widget.items.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    _syncMotion(MediaQuery.disableAnimationsOf(context));
    // Scaffold consumes viewInsets on its body, so the bar would never see
    // the keyboard if it read MediaQuery.viewInsetsOf. The view still has them.
    final keyboard =
        MediaQueryData.fromView(View.of(context)).viewInsets.bottom > 0;
    final motion = !_reduceMotion;
    final slide = motion ? Motion.sheet : Duration.zero;
    final fade = motion ? Motion.exit : Duration.zero;

    return ExcludeSemantics(
      excluding: keyboard,
      child: IgnorePointer(
        ignoring: keyboard,
        child: SafeArea(
          top: false,
          child: AnimatedSlide(
            duration: slide,
            curve: Motion.drawer,
            offset: keyboard ? const Offset(0, 1.4) : Offset.zero,
            child: AnimatedOpacity(
              duration: fade,
              opacity: keyboard ? 0 : 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: SizedBox(
                      height: _barHeight,
                      child: Row(
                        children: [
                          Expanded(child: _buildCapsule()),
                          const SizedBox(width: 12),
                          _buildAction(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCapsule() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = constraints.maxWidth / widget.items.length;
        return Stack(
          key: LiquidGlassNavBar.capsuleKey,
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            const GlassSurface(
              radius: GlassTokens.radiusPill,
              blurBackdrop: false,
              padding: EdgeInsets.zero,
              child: SizedBox.expand(),
            ),
            RepaintBoundary(
              child: ClipRRect(
                borderRadius: const BorderRadius.all(
                  Radius.circular(GlassTokens.radiusPill),
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onTapUp: (details) =>
                      _onTap(details.localPosition.dx, tabWidth),
                  onPanStart: (details) => _onPanStart(details, tabWidth),
                  onPanUpdate: (details) => _onPanUpdate(details, tabWidth),
                  onPanEnd: (details) => _onPanEnd(details, tabWidth),
                  onPanCancel: _onPanCancel,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_position, _lift]),
                    builder: (context, _) {
                      final pos = _position.value;
                      final lift = _reduceMotion ? 0.0 : _lift.value;
                      final lensWidth = navLensWidth(
                        tabWidth: tabWidth,
                        lift: lift,
                      );
                      final lensHeight = navLensHeight(lift);
                      final centerX = (pos + 0.5) * tabWidth;
                      final visual = _visualIndex(pos);
                      return Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            left: centerX - lensWidth / 2,
                            top: (_barHeight - lensHeight) / 2,
                            width: lensWidth,
                            height: lensHeight,
                            child: SizedBox.expand(
                              key: LiquidGlassNavBar.lensKey,
                              child: DecoratedBox(
                                decoration: _lensDecoration(context.palette),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              for (var i = 0; i < widget.items.length; i++)
                                Expanded(
                                  child: _NavTab(
                                    item: widget.items[i],
                                    position: pos,
                                    index: i,
                                    emphasized: visual == i,
                                    selected: widget.selectedIndex == i,
                                    reduceMotion: _reduceMotion,
                                    onTap: () => _commit(i),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAction() {
    return Tooltip(
      message: widget.actionTooltip,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: widget.actionTooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setActionPressed(true),
          onTapUp: (_) {
            _setActionPressed(false);
            HapticFeedback.mediumImpact();
            widget.onAction();
          },
          onTapCancel: () => _setActionPressed(false),
          child: ScaleTransition(
            scale: _actionScale,
            child: RepaintBoundary(
              child: SizedBox(
                width: 62,
                height: 62,
                child: DecoratedBox(
                  decoration: _actionDecoration(context.palette),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(widget.actionIcon, color: Colors.white, size: 26),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.item,
    required this.position,
    required this.index,
    required this.emphasized,
    required this.selected,
    required this.reduceMotion,
    required this.onTap,
  });

  final GlassNavItem item;
  final double position;
  final int index;
  final bool emphasized;
  final bool selected;
  final bool reduceMotion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final distance = (position - index).abs().clamp(0.0, 1.0);
    final proximity = 1 - distance;
    final scale = reduceMotion ? 1.0 : 1 + proximity * 0.09;
    final color = emphasized
        ? context.palette.text
        : Color.lerp(
            context.palette.textTertiary,
            context.palette.accentBright,
            proximity * 0.55,
          )!;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      onTap: onTap,
      excludeSemantics: true,
      child: Center(
        child: Transform.scale(
          scale: scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                emphasized ? item.activeIcon : item.icon,
                size: 20.5,
                color: color,
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (emphasized ? _labelStyleActive : _labelStyle).copyWith(
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
