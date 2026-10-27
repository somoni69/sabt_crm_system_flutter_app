import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/glass_surface.dart';
import '../design/glass_tokens.dart';
import '../design/motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_surfaces.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.expanded = true,
    this.compact = false,
    this.loading = false,
    this.trailing,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool expanded;
  final bool compact;
  final bool loading;
  final Widget? trailing;

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
    final height = widget.compact ? 42.0 : 52.0;
    final radius = BorderRadius.circular(widget.compact ? 13 : 16);

    final (
      Color bg,
      Color fg,
      Border? border,
      List<BoxShadow>? shadows,
    ) = switch (widget.variant) {
      AppButtonVariant.primary => (
        Colors.transparent,
        Colors.white,
        null,
        [
          BoxShadow(
            color: context.palette.accent.withValues(alpha: 0.30),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      AppButtonVariant.secondary => (
        context.palette.surface2,
        context.palette.text,
        Border.all(color: context.palette.border),
        null,
      ),
      AppButtonVariant.ghost => (
        Colors.transparent,
        context.palette.textSecondary,
        Border.all(color: context.palette.borderSoft),
        null,
      ),
      AppButtonVariant.danger => (
        context.palette.danger,
        Colors.white,
        Border.all(color: context.palette.danger.withValues(alpha: 0.45)),
        [
          BoxShadow(
            color: context.palette.danger.withValues(alpha: 0.20),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
    };

    final content = Row(
      mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
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
              color: fg,
            ),
          ),
        ),
        if (widget.trailing != null) ...[
          const SizedBox(width: 8),
          widget.trailing!,
        ],
      ],
    );

    Widget inner = AnimatedContainer(
      duration: animate ? Motion.micro : Duration.zero,
      curve: Motion.easeOut,
      height: height,
      width: widget.expanded ? double.infinity : null,
      padding: EdgeInsets.symmetric(horizontal: widget.compact ? 16 : 20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: border,
        boxShadow: shadows,
        gradient: widget.variant == AppButtonVariant.primary
            ? (_enabled
                  ? context.palette.primaryGradient
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: context.palette.primaryGradient.colors
                          .map((c) => c.withValues(alpha: 0.45))
                          .toList(),
                    ))
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.variant == AppButtonVariant.primary)
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
          Opacity(opacity: _enabled ? 1 : 0.45, child: content),
        ],
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
        scale: _pressed && animate ? Motion.pressScale : 1,
        duration: animate ? Motion.press : Duration.zero,
        curve: Motion.easeOut,
        child: inner,
      ),
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
    Widget button = PressableScale(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          // Theme-aware in both modes: white-alpha glass was invisible
          // on the light theme (white icon well on a white header).
          color: filled ? context.palette.surface3 : context.palette.surface2,
          borderRadius: BorderRadius.circular(size * 0.34),
          border: Border.all(
            color: filled ? context.palette.border : context.palette.borderSoft,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: size * 0.46, color: color ?? context.palette.text),
            if ((badge ?? 0) > 0)
              Positioned(
                top: size * 0.17,
                right: size * 0.16,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 15),
                  height: 15,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: context.palette.danger,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: context.palette.background,
                      width: 1.5,
                    ),
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
