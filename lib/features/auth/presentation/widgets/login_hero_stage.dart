import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/motion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'animated_brand_mark.dart';

/// Interactive spatial hero stage for the sign-in screen.
///
/// Combines two benchmark mobile patterns:
/// 1. Peripheral floating tactile badges around the focal mark (giving
///    depth and product context at a glance without cluttering the form),
///    animated strictly via compositor `Transform.translate` inside
///    [RepaintBoundary] so layout never runs during the ambient loop;
/// 2. Three tilted tactile squircle pillar tiles ("Задачи · Контент · Клиенты")
///    and a live workspace preview card that responds to both taps and
///    horizontal drag/swipe gestures with an interruptible spring
///    ([Motion.springSnap]) and velocity hand-off.
class LoginHeroStage extends StatefulWidget {
  const LoginHeroStage({
    super.key,
    required this.compact,
  });

  /// True when the software keyboard is open or when the two-factor
  /// challenge is active, collapsing the stage smoothly so the form stays
  /// comfortably above the keyboard on both iOS and Android.
  final bool compact;

  @override
  State<LoginHeroStage> createState() => _LoginHeroStageState();
}

class _LoginHeroStageState extends State<LoginHeroStage>
    with TickerProviderStateMixin {
  int _selectedPillar = 0;
  bool _dragSwitchedInGesture = false;

  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  /// Unbounded spring controller driving horizontal drag & release on the
  /// live workspace preview card. Inherits finger velocity on release and
  /// can be interrupted mid-flight without resetting to zero.
  late final AnimationController _dragOffset = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );

  static const List<_PillarSpec> _pillars = [
    _PillarSpec(
      label: 'Задачи',
      icon: Icons.check_circle_outline_rounded,
      tiltDegrees: -5.5,
      previewTag: 'СПРИНТ · СЕГОДНЯ',
      previewTitle: 'Редизайн айдентики и гайдлайна',
      previewMeta: 'В работе · 4 из 5 этапов закрыто',
      previewBadge: 'В ритме',
    ),
    _PillarSpec(
      label: 'Контент',
      icon: Icons.auto_awesome_mosaic_outlined,
      tiltDegrees: 0,
      previewTag: 'SMM · WEBRAND',
      previewTitle: 'Сетка Reels и проверка сторис',
      previewMeta: '12 публикаций согласовано на неделю',
      previewBadge: '12/12',
    ),
    _PillarSpec(
      label: 'Клиенты',
      icon: Icons.insights_rounded,
      tiltDegrees: 5.5,
      previewTag: 'CRM · ПРОЕКТЫ',
      previewTitle: 'Аналитика, тарифы и отчёты',
      previewMeta: '24 активных бренда под контролем',
      previewBadge: '+28%',
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.allowed(context) && !widget.compact) {
      if (!_float.isAnimating) _float.repeat(reverse: true);
    } else {
      _float.stop();
      _float.value = 0.3;
      _dragOffset.stop();
      _dragOffset.value = 0;
    }
  }

  @override
  void didUpdateWidget(covariant LoginHeroStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.compact != oldWidget.compact) {
      if (widget.compact || !Motion.allowed(context)) {
        _float.stop();
        _dragOffset.stop();
        _dragOffset.value = 0;
      } else if (!_float.isAnimating) {
        _float.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _float.dispose();
    _dragOffset.dispose();
    super.dispose();
  }

  Color _pillarColor(AppPalette palette, int index) => switch (index) {
    0 => palette.brandPurple,
    1 => palette.brandRed,
    _ => palette.ice,
  };

  void _selectPillar(int nextIndex, {double initialVelocity = 0}) {
    final clamped = nextIndex.clamp(0, _pillars.length - 1);
    if (clamped == _selectedPillar) return;
    final direction = clamped > _selectedPillar ? 1.0 : -1.0;
    HapticFeedback.selectionClick();
    setState(() => _selectedPillar = clamped);
    if (Motion.allowed(context)) {
      // Give the newly arrived card a subtle directional spring impulse.
      final startOffset = _dragOffset.value.abs() > 2
          ? _dragOffset.value * 0.35
          : direction * 14.0;
      _dragOffset.animateWith(
        SpringSimulation(
          Motion.springSnap,
          startOffset,
          0,
          initialVelocity * 0.18,
        ),
      );
    } else {
      _dragOffset.value = 0;
    }
  }

  void _onPreviewDragStart(DragStartDetails details) {
    _dragSwitchedInGesture = false;
    _dragOffset.stop();
  }

  void _onPreviewDragUpdate(DragUpdateDetails details) {
    final dx = details.delta.dx;
    final atLeftEdge = _selectedPillar == 0 && (_dragOffset.value + dx) > 0;
    final atRightEdge =
        _selectedPillar == _pillars.length - 1 && (_dragOffset.value + dx) < 0;
    final resistance = (atLeftEdge || atRightEdge) ? 0.24 : 0.58;
    _dragOffset.value = (_dragOffset.value + dx * resistance).clamp(-56.0, 56.0);

    if (!_dragSwitchedInGesture && _dragOffset.value.abs() >= 34) {
      final step = _dragOffset.value < 0 ? 1 : -1;
      final target = (_selectedPillar + step).clamp(0, _pillars.length - 1);
      if (target != _selectedPillar) {
        _dragSwitchedInGesture = true;
        _selectPillar(target);
      }
    }
  }

  void _onPreviewDragEnd(DragEndDetails details) {
    final vx = details.primaryVelocity ?? 0;
    if (!_dragSwitchedInGesture && vx.abs() > 260) {
      final step = vx < 0 ? 1 : -1;
      final target = (_selectedPillar + step).clamp(0, _pillars.length - 1);
      if (target != _selectedPillar) {
        _selectPillar(target, initialVelocity: vx / 28);
        return;
      }
    }
    if (!Motion.allowed(context)) {
      _dragOffset.value = 0;
      return;
    }
    _dragOffset.animateWith(
      SpringSimulation(
        Motion.springSnap,
        _dragOffset.value,
        0,
        vx / 32,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final animate = Motion.allowed(context);

    return MotionSwap(
      duration: Motion.sheet,
      animateSize: true,
      alignment: Alignment.topCenter,
      child: widget.compact
          ? _buildCompactStage(palette)
          : _buildExpandedStage(palette, animate),
    );
  }

  Widget _buildCompactStage(AppPalette palette) {
    return Center(
      key: const ValueKey('hero-compact'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AnimatedBrandMark(size: 46, playEntrance: false),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sabt Workspace',
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: palette.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Задачи · Контент · Клиенты',
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 12,
                  color: palette.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedStage(AppPalette palette, bool animate) {
    final activePillar = _pillars[_selectedPillar];
    final activeAccent = _pillarColor(palette, _selectedPillar);

    return Column(
      key: const ValueKey('hero-expanded'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Spatial floating composition: center brand mark flanked by
        //    peripheral floating tactile chips (Baller / Appllama style).
        //    Uses compositor Transform.translate only — Stack Positioned
        //    coordinates never mutate.
        RepaintBoundary(
          child: SizedBox(
            height: 112,
            child: AnimatedBuilder(
              animation: _float,
              builder: (context, _) {
                final wave = math.sin(_float.value * math.pi);
                final leftDy = animate ? wave * -3.5 : 0.0;
                final rightDy = animate ? (1 - wave) * 3.5 : 0.0;

                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Left floating tactile sticker.
                    Positioned(
                      left: 4,
                      top: 10,
                      child: Transform.translate(
                        offset: Offset(0, leftDy),
                        child: Transform.rotate(
                          angle: -0.11,
                          child: _FloatingStickerChip(
                            icon: Icons.bolt_rounded,
                            iconColor: palette.success,
                            label: 'Спринт · 96%',
                            subtitle: 'Задачи в срок',
                          ),
                        ),
                      ),
                    ),
                    // Right floating tactile sticker.
                    Positioned(
                      right: 4,
                      bottom: 8,
                      child: Transform.translate(
                        offset: Offset(0, rightDy),
                        child: Transform.rotate(
                          angle: 0.10,
                          child: _FloatingStickerChip(
                            icon: Icons.local_fire_department_rounded,
                            iconColor: palette.brandRed,
                            label: '12/12 сторис',
                            subtitle: 'SMM-контроль',
                          ),
                        ),
                      ),
                    ),
                    // Center focal mark inside a tactile 3D squircle pedestal.
                    const AnimatedBrandMark(
                      size: 78,
                      playEntrance: false,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 2. Three tilted tactile squircle pillar badges (NotePanda style:
        //    "Задачи. Контент. Клиенты."). Tapping switches the live preview.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _pillars.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              _TactilePillarTile(
                spec: _pillars[i],
                accent: _pillarColor(palette, i),
                selected: _selectedPillar == i,
                onTap: () => _selectPillar(i),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),

        // 3. Compact live workspace preview card that responds to both
        //    pillar taps and horizontal drag gestures with spring physics.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _onPreviewDragStart,
          onHorizontalDragUpdate: _onPreviewDragUpdate,
          onHorizontalDragEnd: _onPreviewDragEnd,
          child: AnimatedBuilder(
            animation: _dragOffset,
            builder: (context, child) {
              final dx = _dragOffset.value;
              final tilt = (dx / 56.0).clamp(-1.0, 1.0) * 0.018;
              return Transform.translate(
                offset: Offset(dx, 0),
                child: Transform.rotate(
                  angle: tilt,
                  child: child,
                ),
              );
            },
            child: MotionSwap(
              duration: Motion.standard,
              child: _WorkspacePreviewPill(
                key: ValueKey(_selectedPillar),
                spec: activePillar,
                accent: activeAccent,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PillarSpec {
  const _PillarSpec({
    required this.label,
    required this.icon,
    required this.tiltDegrees,
    required this.previewTag,
    required this.previewTitle,
    required this.previewMeta,
    required this.previewBadge,
  });

  final String label;
  final IconData icon;
  final double tiltDegrees;
  final String previewTag;
  final String previewTitle;
  final String previewMeta;
  final String previewBadge;
}

class _FloatingStickerChip extends StatelessWidget {
  const _FloatingStickerChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final lipColor = palette.isDark
        ? const Color(0xFF06080E)
        : const Color(0xFFD5DCEB);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: palette.surface1,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: palette.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: lipColor,
            offset: const Offset(0, 2.5),
            blurRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: palette.isDark ? 0.28 : 0.06),
            offset: const Offset(0, 8),
            blurRadius: 16,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                  fontFeatures: AppTypography.tabular,
                ),
              ),
              const SizedBox(height: 1.5),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 9.5,
                  height: 1.1,
                  color: palette.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TactilePillarTile extends StatefulWidget {
  const _TactilePillarTile({
    required this.spec,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final _PillarSpec spec;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TactilePillarTile> createState() => _TactilePillarTileState();
}

class _TactilePillarTileState extends State<_TactilePillarTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final animate = Motion.allowed(context);
    final selected = widget.selected;
    final accent = widget.accent;
    final depressed = _pressed && animate;
    final activeDuration = animate
        ? (_pressed ? Motion.press : Motion.release)
        : Duration.zero;

    final borderColor = selected ? accent : palette.border;
    final lipColor = selected
        ? Color.alphaBlend(Colors.black.withValues(alpha: 0.28), accent)
        : (palette.isDark ? const Color(0xFF06080E) : const Color(0xFFD4DBEC));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: depressed ? 0.95 : 1.0,
        duration: activeDuration,
        curve: Motion.easeOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: widget.spec.tiltDegrees * math.pi / 180,
              child: AnimatedContainer(
                duration: activeDuration,
                curve: Motion.easeOut,
                width: 46,
                height: 46,
                transform: Matrix4.translationValues(
                  0,
                  depressed ? 1.5 : 0.0,
                  0,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? Color.alphaBlend(
                          accent.withValues(
                            alpha: palette.isDark ? 0.22 : 0.12,
                          ),
                          palette.surface1,
                        )
                      : palette.surface1,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: borderColor,
                    width: selected ? 1.5 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: lipColor,
                      offset: Offset(0, depressed ? 1.0 : 2.5),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Icon(
                  widget.spec.icon,
                  size: 21,
                  color: selected ? accent : palette.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.spec.label}.',
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: -0.1,
                color: selected ? palette.text : palette.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspacePreviewPill extends StatelessWidget {
  const _WorkspacePreviewPill({
    super.key,
    required this.spec,
    required this.accent,
  });

  final _PillarSpec spec;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final lipColor = palette.isDark
        ? const Color(0xFF06080E)
        : const Color(0xFFD6DCEC);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: palette.surface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: lipColor,
            offset: const Offset(0, 2.5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Icon(spec.icon, size: 18, color: accent),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  spec.previewTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.15,
                    color: palette.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  spec.previewMeta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 11.5,
                    color: palette.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: accent.withValues(alpha: 0.25)),
            ),
            child: Text(
              spec.previewBadge,
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: accent,
                fontFeatures: AppTypography.tabular,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
