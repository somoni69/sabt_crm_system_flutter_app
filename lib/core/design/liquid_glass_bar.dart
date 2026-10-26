import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'glass_surface.dart';
import 'glass_tokens.dart';

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

/// Liquid glass navigation chrome: a floating capsule with a spring-driven
/// liquid lens and a detached circular action.
///
/// Contract: this is the only translucent layer at this Z-plane. The lens is
/// a solid tinted capsule, not another [BackdropFilter].
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

  bool _dragging = false;
  double _lastX = 0;
  DateTime _lastTime = DateTime.now();
  double _velocity = 0;

  static const _barHeight = 66.0;

  @override
  void initState() {
    super.initState();
    _position = AnimationController.unbounded(
      vsync: this,
      value: widget.selectedIndex.toDouble(),
    );
    _lift = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      reverseDuration: const Duration(milliseconds: 240),
    );
    _actionScale = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
      lowerBound: 0.90,
      upperBound: 1,
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant LiquidGlassNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex && !_dragging) {
      _springTo(widget.selectedIndex);
    }
  }

  @override
  void dispose() {
    _position.dispose();
    _lift.dispose();
    _actionScale.dispose();
    super.dispose();
  }

  void _springTo(int index, {double velocity = 0}) {
    final simulation = SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 380, damping: 27),
      _position.value,
      index.toDouble(),
      velocity,
    );
    _lift.forward();
    _position.animateWith(simulation).whenComplete(() {
      if (!_dragging && mounted) _lift.reverse();
    });
  }

  void _onTap(double x, double tabWidth) {
    final index = (x / tabWidth)
        .floor()
        .clamp(0, widget.items.length - 1);
    if (index != widget.selectedIndex) {
      HapticFeedback.lightImpact();
      widget.onSelected(index);
    }
    _springTo(index);
  }

  void _onPanStart(DragStartDetails details) {
    _dragging = true;
    _lastX = details.localPosition.dx;
    _lastTime = DateTime.now();
    _velocity = 0;
    _position.stop();
    _lift.forward();
    HapticFeedback.selectionClick();
  }

  void _onPanUpdate(DragUpdateDetails details, double tabWidth) {
    final now = DateTime.now();
    final dt = now.difference(_lastTime).inMicroseconds / 1000000;
    final dx = details.localPosition.dx - _lastX;
    if (dt > 0.001) {
      _velocity = ui.lerpDouble(_velocity, dx / dt, 0.35) ?? 0;
    }
    _lastX = details.localPosition.dx;
    _lastTime = now;

    final raw = details.localPosition.dx / tabWidth - 0.5;
    final max = (widget.items.length - 1).toDouble();
    double clamped = raw;
    if (raw < 0) {
      final diff = -raw;
      clamped = -(1 - (1 / (diff * 0.5 + 1))) * 0.35;
    } else if (raw > max) {
      final diff = raw - max;
      clamped = max + (1 - (1 / (diff * 0.5 + 1))) * 0.35;
    }
    _position.value = clamped.clamp(-0.25, max + 0.25);
  }

  void _onPanEnd(DragEndDetails details, double tabWidth) {
    _dragging = false;
    final max = widget.items.length - 1;
    final velocityTabs = details.velocity.pixelsPerSecond.dx / tabWidth;
    int target = velocityTabs.abs() > 1.1
        ? (_position.value + velocityTabs.sign * 0.4).round()
        : _position.value.round();
    target = target.clamp(0, max);
    if (target != widget.selectedIndex) {
      HapticFeedback.mediumImpact();
      widget.onSelected(target);
    }
    _springTo(target, velocity: velocityTabs);
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final reduce = MediaQuery.disableAnimationsOf(context);

    return SafeArea(
      top: false,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        offset: keyboard ? const Offset(0, 1.4) : Offset.zero,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: keyboard ? 0 : 1,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              height: _barHeight,
              child: Row(
                children: [
                  Expanded(child: _buildCapsule(reduce)),
                  const SizedBox(width: 12),
                  _buildAction(reduce),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCapsule(bool reduce) {
    return GlassSurface(
      radius: 999,
      blur: GlassTokens.blurLarge,
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / widget.items.length;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) => _onTap(details.localPosition.dx, tabWidth),
            onPanStart: _onPanStart,
            onPanUpdate: (details) => _onPanUpdate(details, tabWidth),
            onPanEnd: (details) => _onPanEnd(details, tabWidth),
            child: AnimatedBuilder(
              animation: Listenable.merge([_position, _lift]),
              builder: (context, _) {
                final pos = _position.value;
                final lift = _lift.value;
                final centerX = (pos + 0.5) * tabWidth;
                final dropletWidth =
                    (tabWidth - 10 + lift * 6).clamp(40.0, tabWidth + 2);
                final dropletHeight = 50 + lift * 4;

                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: centerX - dropletWidth / 2,
                      top: (_barHeight - dropletHeight) / 2,
                      width: dropletWidth,
                      height: dropletHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.accent.withValues(alpha: 0.30),
                              AppColors.accentDeep.withValues(alpha: 0.42),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.20),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.28),
                              blurRadius: 18,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < widget.items.length; i++)
                          Expanded(
                            child: _buildTab(
                              index: i,
                              position: pos,
                              tabWidth: tabWidth,
                              reduce: reduce,
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTab({
    required int index,
    required double position,
    required double tabWidth,
    required bool reduce,
  }) {
    final item = widget.items[index];
    final distance = (position - index).abs().clamp(0.0, 1.0);
    final proximity = 1 - distance;
    final active = widget.selectedIndex == index;
    final scale = reduce ? 1.0 : 1 + proximity * 0.09;
    final color = active
        ? Colors.white
        : Color.lerp(
            AppColors.textTertiary,
            AppColors.accentBright,
            proximity * 0.55,
          )!;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!active) {
          HapticFeedback.lightImpact();
          widget.onSelected(index);
        }
        _springTo(index);
      },
      child: Center(
        child: Transform.scale(
          scale: scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? item.activeIcon : item.icon,
                size: 20.5,
                color: color,
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 9.2,
                  height: 1.1,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: 0.1,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAction(bool reduce) {
    return Tooltip(
      message: widget.actionTooltip,
      child: GestureDetector(
        onTapDown: (_) => _actionScale.reverse(),
        onTapUp: (_) {
          _actionScale.forward();
          HapticFeedback.mediumImpact();
          widget.onAction();
        },
        onTapCancel: () => _actionScale.forward(),
        child: ScaleTransition(
          scale: _actionScale,
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.38),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: GlassSurface(
              radius: 999,
              blur: GlassTokens.blurMedium,
              strong: true,
              padding: EdgeInsets.zero,
              glow: false,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.accent.withValues(alpha: 0.92),
                          AppColors.accentDeep.withValues(alpha: 0.96),
                        ],
                      ),
                    ),
                  ),
                  Icon(widget.actionIcon, color: Colors.white, size: 26),
                  Positioned(
                    top: 7,
                    left: 16,
                    right: 16,
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: 0.45),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
