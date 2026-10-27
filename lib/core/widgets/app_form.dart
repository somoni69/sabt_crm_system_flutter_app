import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class FormSectionLabel extends StatelessWidget {
  const FormSectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 7),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: AppTypography.overline(color: context.palette.textTertiary),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class AppChoice<T> {
  const AppChoice({
    required this.value,
    required this.label,
    this.icon,
    this.color,
  });

  final T value;
  final String label;
  final IconData? icon;
  final Color? color;
}

/// The one segmented-choice standard for forms (priority, type,
/// access…). Same language as GlassSegmentedControl and
/// AppFilterChip: track = surface2, selected = solid brand violet
/// (#59479e) with white text, unselected = tertiary text. An option's
/// [AppChoice.color] is semantic only — it renders as a 6px dot, never
/// as a different selected colour, so «Средний» no longer turns blue
/// while «Задача» turns purple on the next row. Labels shrink instead
/// of ellipsising («Критичн…»).
class AppChoiceChips<T> extends StatelessWidget {
  const AppChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<AppChoice<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        color: palette.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.borderSoft),
      ),
      child: Row(
        children: options.map((option) {
          final active = option.value == selected;
          final fg = active ? palette.onControlSelected : palette.textTertiary;
          return Expanded(
            child: Semantics(
              button: true,
              selected: active,
              label: option.label,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (!active) {
                    HapticFeedback.selectionClick();
                    onChanged(option.value);
                  }
                },
                child: AnimatedContainer(
                  duration: Motion.duration(context, Motion.micro),
                  curve: Motion.easeOut,
                  constraints: const BoxConstraints(minHeight: 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? palette.controlSelected
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: active
                          ? palette.controlSelected
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (option.color != null) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: active ? Colors.white : option.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                      if (option.icon != null) ...[
                        Icon(option.icon, size: 14, color: fg),
                        const SizedBox(width: 5),
                      ],
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            option.label,
                            maxLines: 1,
                            style: TextStyle(
                              fontFamily: AppTypography.family,
                              fontSize: 12.5,
                              fontWeight: active
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: fg,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Inline expanding selector built on the framework's [Expansible].
///
/// Previously this was a [DropdownButtonFormField], whose popup menu
/// covers the form (and floats over the keyboard on small screens).
/// Now the option list expands in place inside the form — like iOS
/// inline pickers — pushing the fields below it down, and collapses
/// on selection. The animation is the widget's own: an
/// [ExpansibleController] plus [AnimationStyle] fed from the shared
/// [Motion] tokens, so it retargets mid-flight and collapses to
/// instant under reduced motion.
class AppSelectField<T> extends StatefulWidget {
  const AppSelectField({
    super.key,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    this.hint = 'Выберите',
    this.icon,
  });

  final T? value;
  final List<T> items;
  final String Function(T item) labelOf;
  final ValueChanged<T?> onChanged;
  final String hint;
  final IconData? icon;

  @override
  State<AppSelectField<T>> createState() => _AppSelectFieldState<T>();
}

class _AppSelectFieldState<T> extends State<AppSelectField<T>> {
  final ExpansibleController _controller = ExpansibleController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  T? get _selected => widget.items.contains(widget.value) ? widget.value : null;

  void _toggle(BuildContext headerContext) {
    HapticFeedback.selectionClick();
    final expanding = !_controller.isExpanded;
    _controller.toggle();
    if (expanding) {
      // Once the list has opened, keep the whole selector on screen
      // even when it grows past the sheet's fold.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Scrollable.ensureVisible(
          headerContext,
          duration: Motion.duration(headerContext, Motion.sheet),
          curve: Motion.easeOut,
          alignment: 0.05,
        );
      });
    }
  }

  void _pick(T item) {
    HapticFeedback.selectionClick();
    widget.onChanged(item);
    _controller.collapse();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final selected = _selected;
    final animate = Motion.allowed(context);

    return Expansible(
      controller: _controller,
      maintainState: false,
      animationStyle: animate
          ? AnimationStyle(
              duration: Motion.sheet,
              curve: Motion.drawer,
              reverseCurve: Motion.easeOut,
            )
          : AnimationStyle.noAnimation,
      headerBuilder: (context, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = Motion.easeOut.transform(animation.value);
            return Semantics(
              button: true,
              expanded: _controller.isExpanded,
              label: selected == null ? widget.hint : widget.labelOf(selected),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _toggle(context),
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: palette.surface2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Color.lerp(palette.borderSoft, palette.accent, t)!,
                      width: 1 + 0.3 * t,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          size: 19,
                          color: Color.lerp(
                            palette.textTertiary,
                            palette.accentBright,
                            t,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Text(
                          selected == null
                              ? widget.hint
                              : widget.labelOf(selected),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 14,
                            color: selected == null
                                ? palette.textTertiary
                                : palette.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Transform.rotate(
                        angle: t * 3.141592653589793,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: Color.lerp(
                            palette.textTertiary,
                            palette.accentBright,
                            t,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      bodyBuilder: (context, animation) {
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            decoration: BoxDecoration(
              color: palette.surface2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.borderSoft),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < widget.items.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: palette.borderSoft),
                  _optionRow(widget.items[i]),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _optionRow(T item) {
    final palette = context.palette;
    final active = item == _selected;
    return Semantics(
      button: true,
      selected: active,
      label: widget.labelOf(item),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _pick(item),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          color: active
              ? palette.accent.withValues(alpha: 0.10)
              : Colors.transparent,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.labelOf(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? palette.accentBright : palette.text,
                  ),
                ),
              ),
              if (active)
                Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: palette.accentBright,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppFieldRow extends StatelessWidget {
  const AppFieldRow({
    super.key,
    required this.child,
    this.trailing,
    this.label,
    this.onTrailingTap,
  });

  final Widget child;
  final Widget? trailing;
  final String? label;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: context.palette.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.borderSoft),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label != null) ...[
                  Text(
                    label!,
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: context.palette.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                child,
              ],
            ),
          ),
          if (trailing != null)
            GestureDetector(
              onTap: onTrailingTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(padding: const EdgeInsets.all(6), child: trailing),
            ),
        ],
      ),
    );
  }
}
