import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_range_key.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../tasks/presentation/task_form_sheet.dart';
import '../domain/calendar_event.dart';
import '../presentation/calendar_providers.dart';
import 'widgets/month_grid.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  MonthKey _month = MonthKey.current();
  DateTime _selected = BizDate.today();

  void _shiftMonth(int delta) {
    final next = _month.add(delta);
    setState(() {
      _month = next;
      _selected = next.start;
    });
  }

  void _goToday() {
    final now = BizDate.today();
    setState(() {
      _month = MonthKey.of(now);
      _selected = now;
    });
  }

  Color _colorOf(CalendarEvent event) {
    if (event.isTask) {
      if (event.isDone) return context.palette.success;
      if (event.isOverdue) return context.palette.danger;
      return context.palette.accent;
    }
    if (event.isMeeting) return context.palette.info;
    if (event.isRepeatCall) return context.palette.warning;
    if (event.isShoot) return context.palette.ice;
    if (event.isPayment) return context.palette.success;
    if (event.isProjectMilestone) return context.palette.accentBright;
    return context.palette.textSecondary;
  }

  IconData _iconOf(CalendarEvent event) {
    if (event.isTask) {
      return event.isMeeting ? Icons.videocam_outlined : Icons.checklist_rounded;
    }
    if (event.isRepeatCall) return Icons.phone_callback_rounded;
    if (event.isMeeting) return Icons.handshake_outlined;
    if (event.isShoot) return Icons.photo_camera_outlined;
    if (event.isPayment) return Icons.payments_outlined;
    if (event.isProjectMilestone) return Icons.flag_outlined;
    return Icons.event_outlined;
  }

  Future<void> _refresh() async {
    ref.read(dataRevisionProvider.notifier).bump();
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  void _openEvent(CalendarEvent event) {
    if (event.taskId != null && event.taskId!.isNotEmpty) {
      context.push('/tasks/${event.taskId}');
      return;
    }
    showGlassSheet<void>(
      context: context,
      title: event.title,
      subtitle: event.typeLabel,
      child: _EventDetail(event: event),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final canSee = canUseCalendar(user);
    final canCreate = canCreateTask(user);
    final async = ref.watch(calendarProvider(_month.range));
    final snapshot = async.value;
    final events = snapshot?.data ?? const <CalendarEvent>[];
    final dayEvents = events
        .where((event) => BizDate.isSameDay(event.date, _selected))
        .toList()
      ..sort((a, b) {
        final ta = a.time ?? '00:00';
        final tb = b.time ?? '00:00';
        return ta.compareTo(tb);
      });

    final markers = <String, List<Color>>{};
    for (final event in events) {
      final key = BizDate.key(event.date);
      final color = _colorOf(event);
      final list = markers.putIfAbsent(key, () => []);
      if (!list.contains(color) && list.length < 3) list.add(color);
    }

    final error = async.error;
    final errorMessage =
        error is ApiException ? error.message : 'Не удалось загрузить календарь';

    return AppPage(
      showBottomBarSpace: false,
      header: AppHeader(
        title: 'Календарь',
        subtitle: '${BizDate.monthNominative(_month.start)} ${_month.year}',
        onBack: () => context.pop(),
        actions: [
          AppIconButton(
            icon: Icons.today_rounded,
            size: 40,
            onPressed: _goToday,
            tooltip: 'Сегодня',
          ),
          if (canCreate)
            AppIconButton(
              icon: Icons.add_rounded,
              size: 40,
              filled: true,
              color: Colors.white,
              onPressed: () => showTaskForm(
                context,
                ref,
                initialDeadline: DateTime(
                  _selected.year,
                  _selected.month,
                  _selected.day,
                  10,
                ),
              ),
              tooltip: 'Новое событие',
            ),
        ],
      ),
      onRefresh: canSee ? _refresh : null,
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!canSee)
                const EmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: 'Календарь недоступен',
                  message: 'У вашей роли нет доступа к календарю.',
                )
              else ...[
                CalendarMonthBar(
                  month: _month,
                  onPrevious: () => _shiftMonth(-1),
                  onNext: () => _shiftMonth(1),
                  onToday: _goToday,
                ),
                const SizedBox(height: 12),
                MonthGrid(
                  month: _month,
                  selected: _selected,
                  markers: markers,
                  onSelect: (day) => setState(() => _selected = day),
                ),
                const SizedBox(height: 18),
                SectionHeader(
                  overline: BizDate.dayLabel(_selected).toUpperCase(),
                  title: 'Повестка дня',
                  actionLabel: dayEvents.isEmpty ? null : '${dayEvents.length}',
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                ),
                if (snapshot?.error != null) ...[
                  if (events.isEmpty)
                    InlineError(message: errorMessage, onRetry: _refresh)
                  else
                    OfflineRibbon(
                      cachedAt: snapshot?.savedAt,
                      showRetry: true,
                      onRetry: _refresh,
                    ),
                  const SizedBox(height: 14),
                ],
                if (async.isLoading && snapshot == null)
                  const _CalendarSkeleton()
                else if (error != null && snapshot == null)
                  InlineError(message: errorMessage, onRetry: _refresh)
                else if (dayEvents.isEmpty)
                  EmptyState(
                    icon: Icons.event_available_outlined,
                    title: 'Свободный день',
                    message: 'На эту дату нет событий. Можно запланировать задачу или встречу.',
                    actionLabel: canCreate ? 'Добавить событие' : null,
                    onAction: canCreate ? () => _createOnDay() : null,
                    compact: true,
                  )
                else
                  for (final event in dayEvents) ...[
                    _EventRow(
                      event: event,
                      color: _colorOf(event),
                      icon: _iconOf(event),
                      onTap: () => _openEvent(event),
                    ),
                    const SizedBox(height: 8),
                  ],
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _createOnDay() {
    showTaskForm(
      context,
      ref,
      initialDeadline: DateTime(
        _selected.year,
        _selected.month,
        _selected.day,
        10,
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final CalendarEvent event;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
      radius: 17,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.timeLabel,
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 10.5,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
                const SizedBox(height: 3),
                Icon(icon, size: 15, color: color),
              ],
            ),
          ),
          Container(
            width: 2,
            height: 40,
            margin: const EdgeInsets.only(right: 12, top: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 13,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: event.isDone
                              ? context.palette.textTertiary
                              : context.palette.text,
                        ),
                      ),
                    ),
                    if (event.isOverdue)
                      const AppChip(
                        label: 'Просрочено',
                        tone: ChipTone.danger,
                        compact: true,
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      event.typeLabel,
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                    if (event.projectName != null)
                      Text(
                        '· ${event.projectName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:  TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 10.5,
                          color: context.palette.textTertiary,
                        ),
                      ),
                    if (event.location != null)
                      Text(
                        '· ${event.location}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:  TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 10.5,
                          color: context.palette.textTertiary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
           Icon(Icons.chevron_right_rounded,
              size: 18, color: context.palette.textTertiary),
        ],
      ),
    );
  }
}

class _EventDetail extends StatelessWidget {
  const _EventDetail({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 7,
          runSpacing: 6,
          children: [
            AppChip(
              label: event.typeLabel,
              tone: event.isOverdue ? ChipTone.danger : ChipTone.accent,
              compact: true,
            ),
            AppChip(
              label: event.timeLabel,
              tone: ChipTone.neutral,
              icon: Icons.schedule_rounded,
              compact: true,
            ),
            if (event.status != null)
              AppChip(
                label: event.isDone ? 'Готово' : event.status!,
                tone: event.isDone ? ChipTone.success : ChipTone.info,
                compact: true,
              ),
          ],
        ),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          radius: 16,
          child: Column(
            children: [
              KeyValueRow(
                label: 'Дата',
                value: BizDate.fullDate(event.date),
                icon: Icons.event_outlined,
              ),
              if (event.projectName != null) ...[
                 Divider(height: 1, color: context.palette.borderSoft),
                KeyValueRow(
                  label: 'Проект',
                  value: event.projectName!,
                  icon: Icons.folder_outlined,
                ),
              ],
              if (event.assigneeName != null) ...[
                 Divider(height: 1, color: context.palette.borderSoft),
                KeyValueRow(
                  label: 'Ответственный',
                  value: event.assigneeName!,
                  icon: Icons.person_outline_rounded,
                ),
              ],
              if (event.location != null) ...[
                 Divider(height: 1, color: context.palette.borderSoft),
                KeyValueRow(
                  label: 'Место',
                  value: event.location!,
                  icon: Icons.place_outlined,
                ),
              ],
            ],
          ),
        ),
        if (event.description != null && event.description!.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            event.description!,
            style:  TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 13,
              height: 1.55,
              color: context.palette.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 18),
        if (event.taskId != null)
          AppButton(
            label: 'Открыть задачу',
            icon: Icons.arrow_forward_rounded,
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/tasks/${event.taskId}');
            },
          ),
      ],
    );
  }
}

class _CalendarSkeleton extends StatelessWidget {
  const _CalendarSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SkeletonBox(height: 300, radius: 22),
        SizedBox(height: 16),
        SkeletonBox(height: 66, radius: 17),
        SizedBox(height: 8),
        SkeletonBox(height: 66, radius: 17),
      ],
    );
  }
}
