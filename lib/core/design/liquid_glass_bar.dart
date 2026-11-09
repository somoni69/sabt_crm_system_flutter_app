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

/// The moving lens is a solid tinted pill with a faint specular rim. It is
/// not glass itself: only the floating capsule behind it is translucent,
/// so there is never glass-on-glass.
BoxDecoration _lensDecoration(AppPalette palette) => BoxDecoration(
  color: palette.accent.withValues(alpha: 0.20),
  borderRadius: const BorderRadius.all(Radius.circular(GlassTokens.radiusPill)),
  border: Border.all(
    color: palette.accentBright.withValues(alpha: 0.28),
    width: 1,
  ),
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

/// Floating Liquid Glass bottom navigation.
///
/// * A detached pill capsule with specular rim and depth shadow. Live
///   backdrop blur on Apple platforms only; Android gets the opaque
///   composite of the same tint (see [GlassSurface]).
/// * A tap slides the lens in 140ms (same curve on both platforms).
/// * A horizontal drag scrubs the lens under the finger with rubber-band
///   edges; on release it settles on [Motion.springSnap] and only then
///   commits the tab, so scrubbing never switches screens mid-gesture.
/// * Reduced motion snaps everything; high contrast/accessible navigation
///   drops transparency.
class LiquidGlassNavBar extends StatefulWidget {
  const LiquidGlassNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
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

  @override
  State<LiquidGlassNavBar> createState() => _LiquidGlassNavBarState();
}

class _LiquidGlassNavBarState extends State<LiquidGlassNavBar>
    with TickerProviderStateMixin {
  late final AnimationController _position;
  late final AnimationController _lift;

  late double _goal;
  int _motionTicket = 0;
  bool _reduceMotion = false;
  bool _dragging = false;

  static const _barHeight = 62.0;
  static const _move = Duration(milliseconds: 140);

  @override
  void initState() {
    super.initState();
    final initial = _clampedIndex(widget.selectedIndex).toDouble();
    _goal = initial;
    _position = AnimationController.unbounded(vsync: this, value: initial);
    _lift = AnimationController(
      vsync: this,
      duration: Motion.micro,
      reverseDuration: Motion.release,
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
    if (_goal == target) return;
    _moveTo(widget.selectedIndex);
  }

  @override
  void dispose() {
    _position.dispose();
    _lift.dispose();
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
      _position
        ..stop()
        ..value = _goal;
    });
  }

  void _moveTo(int index) {
    final target = _clampedIndex(index).toDouble();
    _goal = target;
    if (_reduceMotion) {
      _motionTicket++;
      _position.stop();
      _position.value = target;
      return;
    }
    final ticket = ++_motionTicket;
    _position
        .animateTo(target, duration: _move, curve: Curves.easeOutCubic)
        .whenComplete(() {
      if (ticket != _motionTicket || !mounted) return;
    });
  }

  void _commit(int index) {
    final target = _clampedIndex(index);
    final changed = target != widget.selectedIndex;
    _moveTo(target);
    if (!changed) return;
    HapticFeedback.selectionClick();
    widget.onSelected(target);
  }

  double _rawPosition(double x, double tabWidth) => x / tabWidth - 0.5;

  void _dragStart(DragStartDetails details, double tabWidth) {
    if (tabWidth <= 0) return;
    _dragging = true;
    _motionTicket++;
    _position.stop();
    if (!_reduceMotion) _lift.forward();
    HapticFeedback.selectionClick();
    _position.value = resistNavPosition(
      _rawPosition(details.localPosition.dx, tabWidth),
      widget.items.length,
    );
  }

  void _dragUpdate(DragUpdateDetails details, double tabWidth) {
    if (!_dragging || tabWidth <= 0) return;
    _position.value = resistNavPosition(
      _rawPosition(details.localPosition.dx, tabWidth),
      widget.items.length,
    );
  }

  void _dragEnd(double pixelsPerSecond, double tabWidth) {
    if (!_dragging) return;
    _dragging = false;
    _lift.reverse();
    final velocity = navFlingVelocity(pixelsPerSecond, tabWidth);
    final target = settleNavIndex(
      position: _position.value,
      velocityTabs: velocity,
      itemCount: widget.items.length,
    );
    _settleOn(target, velocity);
  }

  /// Lands the lens on [index] with the shared snap spring, then commits.
  void _settleOn(int index, double velocityTabs) {
    final target = _clampedIndex(index);
    final changed = target != widget.selectedIndex;
    _goal = target.toDouble();
    ++_motionTicket;
    if (_reduceMotion) {
      _position.stop();
      _position.value = _goal;
    } else {
      _position.animateWith(
        SpringSimulation(
          Motion.springSnap,
          _position.value,
          _goal,
          velocityTabs,
          snapToEnd: true,
        ),
      );
    }
    if (!changed) return;
    HapticFeedback.selectionClick();
    widget.onSelected(target);
  }

  void _onTap(double x, double tabWidth) {
    if (tabWidth <= 0) return;
    final index = (x / tabWidth).floor().clamp(0, widget.items.length - 1);
    _commit(index);
  }

  int _visualIndex(double position) {
    final max = widget.items.length - 1;
    if (max < 0) return 0;
    return position.round().clamp(0, max);
  }

  @override
  Widget build(BuildContext context) {
    _syncMotion(MediaQuery.disableAnimationsOf(context));
    // Scaffold consumes viewInsets on its body, so the bar would never see
    // the keyboard if it read MediaQuery.viewInsetsOf. The view still has them.
    final keyboard =
        MediaQueryData.fromView(View.of(context)).viewInsets.bottom > 0;
    final motion = !_reduceMotion;
    final slide = motion ? const Duration(milliseconds: 120) : Duration.zero;
    final fade = motion ? const Duration(milliseconds: 80) : Duration.zero;

    return ExcludeSemantics(
      excluding: keyboard,
      child: IgnorePointer(
        ignoring: keyboard,
        child: SafeArea(
          top: false,
          child: AnimatedSlide(
            duration: slide,
            curve: Motion.drawer,
            offset: keyboard ? const Offset(0, 1.6) : Offset.zero,
            child: AnimatedOpacity(
              duration: fade,
              opacity: keyboard ? 0 : 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: GlassSurface(
                  radius: GlassTokens.radiusPill,
                  blur: GlassTokens.blurLarge,
                  strong: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: SizedBox(
                      height: _barHeight,
                      child: _buildCapsule(),
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
            const SizedBox.expand(),
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
                  onHorizontalDragStart: (d) => _dragStart(d, tabWidth),
                  onHorizontalDragUpdate: (d) => _dragUpdate(d, tabWidth),
                  onHorizontalDragEnd: (d) =>
                      _dragEnd(d.primaryVelocity ?? 0, tabWidth),
                  onHorizontalDragCancel: () => _dragEnd(0, tabWidth),
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_position, _lift]),
                    builder: (context, _) {
                      final pos = _position.value;
                      final lift = _lift.value;
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
    const scale = 1.0;
    final color = emphasized
        ? context.palette.text
        : reduceMotion
        ? context.palette.textTertiary
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
      child: Padding(
        // Inset keeps a long label such as «Разработка» inside the lens.
        // The lens is tabWidth − 10, so 8px on each side stays inside it.
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.scale(
              scale: scale,
              child: Icon(
                emphasized ? item.activeIcon : item.icon,
                size: 20.5,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 12,
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  item.label,
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: (emphasized ? _labelStyleActive : _labelStyle)
                      .copyWith(color: color),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
