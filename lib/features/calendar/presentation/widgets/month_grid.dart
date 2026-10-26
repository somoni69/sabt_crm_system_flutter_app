import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_range_key.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_surfaces.dart';

class CalendarMonthBar extends StatelessWidget {
  const CalendarMonthBar({
    super.key,
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    this.trailing,
  });

  final MonthKey month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Arrow(onTap: onPrevious, icon: Icons.chevron_left_rounded),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: onToday,
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${BizDate.monthNominative(month.start)} ${month.year}',
                  style: const TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  month.isCurrent
                      ? 'Текущий месяц'
                      : 'Нажмите, чтобы вернуться',
                  style: const TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 9.5,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (trailing != null) trailing!,
        const SizedBox(width: 8),
        _Arrow(onTap: onNext, icon: Icons.chevron_right_rounded),
      ],
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.onTap, required this.icon});

  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Icon(icon, size: 19, color: AppColors.textSecondary),
      ),
    );
  }
}

class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.month,
    required this.selected,
    required this.onSelect,
    this.markers = const {},
  });

  final MonthKey month;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  /// `YYYY-MM-DD` → dot colors for that day.
  final Map<String, List<Color>> markers;

  @override
  Widget build(BuildContext context) {
    final days = BizDate.monthGrid(month.start);
    final today = BizDate.today();

    return AppCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      radius: 22,
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      BizDate.weekdayShort(DateTime(2024, 1, 1 + i)),
                      style: const TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.9,
              mainAxisSpacing: 4,
              crossAxisSpacing: 3,
            ),
            itemBuilder: (context, index) {
              final day = days[index];
              final inMonth = day.month == month.month;
              final isToday = BizDate.isSameDay(day, today);
              final isSelected = BizDate.isSameDay(day, selected);
              final dots = markers[BizDate.key(day)] ?? const <Color>[];

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(day),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF7E5DEB), Color(0xFF5B3EC8)],
                          )
                        : null,
                    color: isSelected ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.accentBright.withValues(alpha: 0.5)
                          : isToday
                          ? AppColors.accent.withValues(alpha: 0.55)
                          : Colors.transparent,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.30),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 12.5,
                          height: 1.05,
                          fontWeight: isSelected || isToday
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : inMonth
                              ? (isToday
                                    ? AppColors.accentBright
                                    : AppColors.text)
                              : AppColors.textDisabled,
                          fontFeatures: AppTypography.tabular,
                        ),
                      ),
                      if (dots.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final color in dots.take(3))
                              Container(
                                width: 3.4,
                                height: 3.4,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.9)
                                      : color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ] else
                        const SizedBox(height: 7),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
