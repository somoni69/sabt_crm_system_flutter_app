import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/glass_surface.dart';
import '../design/glass_tokens.dart';
import '../design/motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_surfaces.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

typedef ButtonVariant = AppButtonVariant;

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    bool? expanded,
    bool? expand,
    this.compact = false,
    bool? loading,
    bool? busy,
    this.trailing,
    this.padding,
  }) : expanded = expanded ?? expand ?? true,
       loading = loading ?? busy ?? false;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool expanded;
  final bool compact;
  final bool loading;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _setPressed(bool value) {
    if (!_enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final animate = !MediaQuery.disableAnimationsOf(context);
    final palette = context.palette;
    final height = widget.compact ? 36.0 : 40.0;
    final radius = 8.0;

    final fg = switch (widget.variant) {
      AppButtonVariant.primary || AppButtonVariant.danger => Colors.white,
      AppButtonVariant.secondary => palette.text,
      AppButtonVariant.ghost => palette.textSecondary,
    };

    final fill = switch (widget.variant) {
      AppButtonVariant.primary => _enabled
          ? palette.primaryGradient
          : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(palette.surface3, palette.brandPurple, 0.72)!,
                Color.lerp(palette.surface3, palette.accentDeep, 0.72)!,
              ],
            ),
      AppButtonVariant.secondary => LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.surface1,
            palette.isDark ? palette.surface2 : palette.surface1,
          ],
        ),
      AppButtonVariant.ghost => const LinearGradient(
          colors: [Colors.transparent, Colors.transparent],
        ),
      AppButtonVariant.danger => LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              Colors.white.withValues(alpha: 0.12),
              palette.danger,
            ),
            palette.danger,
          ],
        ),
    };

    final depressed = _pressed && _enabled && animate;
    final activeDuration = animate
        ? (_pressed ? Motion.press : Motion.release)
        : Duration.zero;
    final secondaryLip = palette.isDark
        ? const Color(0xFF06080E)
        : const Color(0xFFD6DCEC);

    final shadows = switch (widget.variant) {
      AppButtonVariant.primary => [
          BoxShadow(
            color: const Color(0xFF392B6E).withValues(alpha: _enabled ? 1 : 0.4),
            blurRadius: 0,
            offset: Offset(0, depressed ? 1.0 : 2.5),
          ),
          BoxShadow(
            color: palette.brandPurple.withValues(
              alpha: _enabled ? (depressed ? 0.16 : 0.26) : 0.08,
            ),
            blurRadius: depressed ? 12 : 20,
            offset: Offset(0, depressed ? 4 : 9),
          ),
        ],
      AppButtonVariant.danger => [
          BoxShadow(
            color: Color.alphaBlend(
              Colors.black.withValues(alpha: 0.34),
              palette.danger,
            ),
            blurRadius: 0,
            offset: Offset(0, depressed ? 1.0 : 2.5),
          ),
          BoxShadow(
            color: palette.danger.withValues(alpha: depressed ? 0.14 : 0.22),
            blurRadius: depressed ? 10 : 18,
            offset: Offset(0, depressed ? 4 : 8),
          ),
        ],
      AppButtonVariant.secondary => [
          BoxShadow(
            color: secondaryLip,
            blurRadius: 0,
            offset: Offset(0, depressed ? 1.0 : 2.0),
          ),
        ],
      _ => null,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final shouldExpand = widget.expanded && constraints.hasBoundedWidth;
        final content = Row(
          mainAxisSize: shouldExpand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MotionSwap(
              duration: Motion.micro,
              scale: false,
              child: widget.loading
                  ? SizedBox(
                      key: const ValueKey('busy'),
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fg,
                      ),
                    )
                  : widget.icon != null
                  ? Icon(
                      widget.icon,
                      key: const ValueKey('icon'),
                      size: 18,
                      color: fg,
                    )
                  : const SizedBox.shrink(key: ValueKey('idle')),
            ),
            if (widget.loading || widget.icon != null) const SizedBox(width: 9),
            Flexible(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: widget.compact ? 13.5 : 14.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.05,
                  height: 1,
                  color: fg,
                ),
              ),
            ),
            if (widget.trailing != null) ...[
              const SizedBox(width: 8),
              IconTheme(
                data: IconThemeData(color: fg, size: 18),
                child: widget.trailing!,
              ),
            ],
          ],
        );

        Widget inner = AnimatedContainer(
          duration: activeDuration,
          curve: Motion.easeOut,
          height: height,
          width: shouldExpand ? double.infinity : null,
          transform: Matrix4.translationValues(0, depressed ? 1.5 : 0.0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: shadows,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: GlassRim(
              radius: radius,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: fill),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (widget.variant == AppButtonVariant.primary ||
                        widget.variant == AppButtonVariant.danger)
                      Positioned(
                        top: 1,
                        left: 18,
                        right: 18,
                        child: IgnorePointer(
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
                      ),
                    Padding(
                      padding: widget.padding ??
                          EdgeInsets.symmetric(
                            horizontal: widget.compact ? 16 : 20,
                          ),
                      child: Opacity(
                        opacity: _enabled ? 1 : 0.72,
                        child: content,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        if (!_enabled) return inner;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPressed(true),
          onTapCancel: () => _setPressed(false),
          onTapUp: (_) => _setPressed(false),
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onPressed!();
          },
          child: AnimatedScale(
            scale: depressed ? Motion.pressScale : 1,
            duration: activeDuration,
            curve: Motion.easeOut,
            child: inner,
          ),
        );
      },
    );
  }
}

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 42,
    this.badge,
    this.color,
    this.filled = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final int? badge;
  final Color? color;
  final bool filled;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = size * 0.34;
    Widget button = PressableScale(
      onTap: onPressed,
      child: SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: GlassRim(
            radius: radius,
            child: Container(
              decoration: BoxDecoration(
                color: filled
                    ? palette.surface3
                    : palette.isDark
                    ? palette.glassTint.withValues(alpha: 0.5)
                    : palette.surface1,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, size: size * 0.46, color: color ?? palette.text),
                  if ((badge ?? 0) > 0)
                    Positioned(
                      top: size * 0.17,
                      right: size * 0.16,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 15),
                        height: 15,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: palette.danger,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: palette.background, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          badge! > 99 ? '99+' : '$badge',
                          style: const TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 8.5,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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
    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

class GlassSegmentedControl<T> extends StatelessWidget {
  const GlassSegmentedControl({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.height = 44,
    this.expanded = true,
  });

  final List<SegmentItem<T>> items;
  final T selected;
  final ValueChanged<T> onChanged;
  final double height;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final index = items.indexWhere((item) => item.value == selected);
    final animate = !MediaQuery.disableAnimationsOf(context);

    return GlassSurface(
      radius: height / 2,
      blur: GlassTokens.blurSmall,
      blurBackdrop: false,
      shadow: false,
      padding: const EdgeInsets.all(3.5),
      child: SizedBox(
        height: height - 7,
        width: expanded ? double.infinity : null,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth / items.length;
            return Stack(
              children: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedSlide(
                      offset: Offset(index < 0 ? 0 : index.toDouble(), 0),
                      duration: animate ? Motion.micro : Duration.zero,
                      curve: Motion.easeInOut,
                      child: SizedBox(
                        width: width,
                        height: constraints.maxHeight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            // One selected state everywhere: solid
                            // brand violet + white text (same as
                            // AppChoiceChips / AppFilterChip).
                            color: context.palette.controlSelected,
                            borderRadius: BorderRadius.circular(height / 2),
                            border: Border.all(
                              color: context.palette.controlSelected,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: context.palette.accent.withValues(
                                  alpha: 0.22,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: items.map((item) {
                    final active = item.value == selected;
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (!active) {
                            HapticFeedback.selectionClick();
                            onChanged(item.value);
                          }
                        },
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: Duration.zero,
                            style: TextStyle(
                              fontFamily: AppTypography.family,
                              fontSize: 12.5,
                              fontWeight: active
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              letterSpacing: 0.05,
                              color: active
                                  ? context.palette.onControlSelected
                                  : context.palette.textTertiary,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (item.icon != null) ...[
                                  Icon(
                                    item.icon,
                                    size: 14,
                                    color: active
                                        ? context.palette.onControlSelected
                                        : context.palette.textTertiary,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Flexible(
                                  child: Text(
                                    item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (item.count != null) ...[
                                  const SizedBox(width: 5),
                                  Text(
                                    '${item.count}',
                                    style: TextStyle(
                                      fontFamily: AppTypography.family,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: active
                                          ? context.palette.onControlSelected
                                          : context.palette.textTertiary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class SegmentItem<T> {
  const SegmentItem({
    required this.value,
    required this.label,
    this.icon,
    this.count,
  });

  final T value;
  final String label;
  final IconData? icon;
  final int? count;
}

class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    this.hint = 'Поиск',
    this.onChanged,
    this.onClear,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      autofocus: autofocus,
      textInputAction: TextInputAction.search,
      style: TextStyle(
        fontFamily: AppTypography.family,
        fontSize: 14,
        color: context.palette.text,
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 19),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              onPressed: () {
                controller.clear();
                onChanged?.call('');
                onClear?.call();
              },
              icon: const Icon(Icons.close_rounded, size: 17),
            );
          },
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
      ),
    );
  }
}

class AppSheetHeader extends StatelessWidget {
  const AppSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onClose,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onClose;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              if (subtitle != null) ...[
                const SizedBox(height: 5),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: context.palette.textTertiary),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
        if (onClose != null) ...[
          const SizedBox(width: 6),
          AppIconButton(
            icon: Icons.close_rounded,
            onPressed: onClose,
            size: 38,
          ),
        ],
      ],
    );
  }
}

class AppSwitchTile extends StatelessWidget {
  const AppSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: context.palette.textTertiary),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.palette.text,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 12,
                        height: 1.35,
                        color: context.palette.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
