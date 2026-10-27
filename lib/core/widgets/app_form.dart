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
            style: AppTypography.overline(color: AppColors.textTertiary),
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

/// Solid selector for use inside sheets. Liquid glass is chrome-only, so form
/// controls stay opaque rather than stacking a second translucent layer.
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
    return Container(
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: options.map((option) {
          final active = option.value == selected;
          final color = option.color ?? AppColors.accentBright;
          return Expanded(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? color.withValues(alpha: 0.13)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active
                        ? color.withValues(alpha: 0.32)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (option.icon != null) ...[
                      Icon(
                        option.icon,
                        size: 13,
                        color: active ? color : AppColors.textTertiary,
                      ),
                      const SizedBox(width: 5),
                    ],
                    Flexible(
                      child: Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 11.5,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: active ? color : AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class AppSelectField<T> extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: items.contains(value) ? value : null,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
      borderRadius: BorderRadius.circular(16),
      dropdownColor: AppColors.surface3,
      style: const TextStyle(
        fontFamily: AppTypography.family,
        fontSize: 14,
        color: AppColors.text,
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon, size: 19),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      items: [
        for (final item in items)
          DropdownMenuItem<T>(
            value: item,
            child: Text(
              labelOf(item),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
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
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSoft),
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
                    style: const TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary,
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
