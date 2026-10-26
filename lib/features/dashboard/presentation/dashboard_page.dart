import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/rbac/permissions.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../notifications/domain/app_notification.dart';
import '../../notifications/presentation/notifications_providers.dart';
import '../../smm/domain/smm_models.dart';
import '../../smm/presentation/smm_providers.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/presentation/task_actions.dart';
import '../../tasks/presentation/tasks_providers.dart';
import '../../tasks/presentation/widgets/task_card.dart';
import 'dashboard_providers.dart';
import '../../shell/presentation/navigation_helpers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final today = BizDate.today();
    final hasTasks = userCan(user, Perm.tasksView);
    final canCalendar = userCan(user, Perm.calendarView);
    final isSmm = canSeeSmmSection(user);
    final canCheck = canCheckStories(user);

    final tasksSnapshot = hasTasks ? ref.watch(tasksProvider(TaskFeed.mine)).value : null;
    final tasks = tasksSnapshot?.data ?? const <TaskModel>[];
    final myDay = hasTasks ? ref.watch(myDayTasksProvider) : const <TaskModel>[];
    final unread = ref.watch(unreadNotificationsProvider).value?.data ?? 0;
    final notifications = ref.watch(notificationsProvider).value?.data ?? const <AppNotification>[];
    final pulse = ref.watch(companyPulseProvider).value;
    final storyProjects = isSmm ? ref.watch(dashboardStoryProjectsProvider) : const <SmmProject>[];
    final storyLogs = isSmm ? ref.watch(todayStoryLogsProvider) : const <StoryLog>[];
    final production = isSmm ? ref.watch(todayProductionItemsProvider) : const <SmmEvent>[];
    final online = ref.watch(onlineProvider);
    final overdue = myDay.where((task) => task.isOverdue).length;

    final storiesDone = storyLogs.fold<int>(0, (sum, log) => sum + log.storiesCount);
    final storiesTarget = storyProjects.fold<int>(0, (sum, project) => sum + project.dailyStoriesTarget);

    Future<void> refresh() async {
      ref.read(dataRevisionProvider.notifier).bump();
      await ref.read(authControllerProvider.notifier).refreshMe();
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }

    return AppPage(
      header: _DashboardHeader(
        name: user.name,
        avatar: user.avatar,
        position: user.displayPosition,
        department: user.department,
        unread: unread,
        onAvatar: () => context.push('/profile'),
        onCalendar: canCalendar ? () => context.push('/calendar') : null,
        onNotifications: () => context.push('/notifications'),
      ),
      onRefresh: refresh,
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageIntro(
                overline: _capitalize(BizDate.fullDate(today)),
                title: '${_greeting(BizDate.now().hour)}, ${user.firstName}',
                subtitle: user.combinedRoleLabel == user.displayPosition
                    ? user.combinedRoleLabel
                    : '${user.displayPosition} · ${user.combinedRoleLabel}',
              ),
              if (!online || (tasksSnapshot?.error != null && tasksSnapshot!.fromCache)) ...[
                OfflineRibbon(
                  cachedAt: tasksSnapshot?.savedAt,
                  showRetry: true,
                  onRetry: refresh,
                ),
                const SizedBox(height: 16),
              ],
              if (hasTasks)
                _FocusCard(
                  today: today,
                  tasks: myDay.length,
                  overdue: overdue,
                  storiesDone: storiesDone,
                  storiesTarget: storiesTarget,
                  showsStories: isSmm && storiesTarget > 0,
                  canCalendar: canCalendar,
                  canCheck: canCheck,
                  onTasks: () => openShellTab(ref, 'tasks'),
                  onCalendar: () => context.push('/calendar'),
                  onCheck: () => context.push('/stories-check'),
                )
              else
                _ControlCard(
                  canCheck: canCheck,
                  onCheck: () => context.push('/stories-check'),
                ),
              if (storyProjects.isNotEmpty) ...[
                const SizedBox(height: 26),
                SectionHeader(
                  overline: 'СТОРИС',
                  title: 'Дневной ритм',
                  actionLabel: 'Все проекты',
                  onAction: () => context.push('/projects'),
                ),
                SizedBox(
                  height: 172,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(right: 16),
                    itemCount: storyProjects.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final project = storyProjects[index];
                      final count = storyLogs
                          .where((log) => log.projectId == project.id)
                          .fold<int>(0, (sum, log) => sum + log.storiesCount);
                      return _StoryTrackerCard(
                        project: project,
                        initialCount: count,
                        editable: isStoryWriter(user),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 26),
              SectionHeader(
                overline: 'ЗАДАЧИ',
                title: 'На сегодня',
                actionLabel: hasTasks ? 'Все задачи' : null,
                onAction: hasTasks ? () => openShellTab(ref, 'tasks') : null,
              ),
              if (hasTasks && tasksSnapshot == null)
                const _TaskSkeleton()
              else if (hasTasks && myDay.isEmpty)
                AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      const SurfaceIcon(
                        icon: Icons.wb_sunny_outlined,
                        color: AppColors.success,
                        size: 42,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Дедлайнов на сегодня нет',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Можно спокойно заняться контентом или новыми задачами.',
                              style: TextStyle(
                                fontFamily: AppTypography.family,
                                fontSize: 12,
                                height: 1.4,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                for (final task in myDay.take(3)) ...[
                  TaskCard(
                    task: task,
                    onTap: () => context.push('/tasks/${task.id}'),
                    onQuickDone: task.isDone
                        ? null
                        : () => quickCompleteTask(context, ref, task),
                  ),
                  const SizedBox(height: 9),
                ],
              if (production.isNotEmpty) ...[
                const SizedBox(height: 18),
                SectionHeader(
                  overline: 'ПРОИЗВОДСТВО',
                  title: 'Публикации сегодня',
                  actionLabel: 'Календарь',
                  onAction: () => openShellTab(ref, 'work'),
                ),
                for (final event in production.take(4)) ...[
                  _ProductionRow(
                    event: event,
                    onTap: () => openShellTab(ref, 'work'),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              if (pulse != null) ...[
                const SizedBox(height: 18),
                const SectionHeader(
                  overline: 'КОМПАНИЯ',
                  title: 'Пульс агентства',
                ),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.folder_copy_outlined,
                        label: 'Активные проекты',
                        value: '${pulse.activeProjects}',
                        hint: 'из ${pulse.totalProjects}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.task_alt_rounded,
                        label: 'Выполнено',
                        value: '${pulse.completionRate}%',
                        hint: '${pulse.doneTasks} задач',
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.error_outline_rounded,
                        label: 'Просрочено',
                        value: '${pulse.overdueTasks}',
                        hint: 'требуют внимания',
                        color: pulse.overdueTasks > 0
                            ? AppColors.danger
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.timer_outlined,
                        label: 'Часы за месяц',
                        value: Money.hours(pulse.hoursThisMonth),
                        hint: '${pulse.totalUsers} сотрудников',
                        color: AppColors.ice,
                      ),
                    ),
                  ],
                ),
              ],
              if (notifications.isNotEmpty) ...[
                const SizedBox(height: 24),
                SectionHeader(
                  overline: 'СОБЫТИЯ',
                  title: 'Последнее',
                  actionLabel: 'Все',
                  onAction: () => context.push('/notifications'),
                ),
                for (final notification in notifications.take(3)) ...[
                  _NotificationRow(
                    notification: notification,
                    onTap: () => ref
                        .read(notificationsRepositoryProvider)
                        .open(notification),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              if (tasks.isEmpty &&
                  storyProjects.isEmpty &&
                  pulse == null &&
                  notifications.isEmpty) ...[
                const SizedBox(height: 12),
                const EmptyState(
                  icon: Icons.space_dashboard_outlined,
                  title: 'Рабочее пространство готово',
                  message:
                      'Здесь появятся ваши задачи, контент-план и события компании.',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _greeting(int hour) {
    if (hour < 5) return 'Доброй ночи';
    if (hour < 12) return 'Доброе утро';
    if (hour < 18) return 'Добрый день';
    return 'Добрый вечер';
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.name,
    required this.avatar,
    required this.position,
    required this.department,
    required this.unread,
    required this.onAvatar,
    required this.onCalendar,
    required this.onNotifications,
  });

  final String name;
  final String? avatar;
  final String position;
  final String? department;
  final int unread;
  final VoidCallback onAvatar;
  final VoidCallback? onCalendar;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return AppHeader(
      title: name,
      subtitle: department == null || department!.isEmpty
          ? position
          : '$position · $department',
      leading: AppAvatar(
        name: name,
        avatar: avatar,
        size: 38,
        ring: true,
        onTap: onAvatar,
      ),
      actions: [
        if (onCalendar != null)
          AppIconButton(
            icon: Icons.calendar_month_outlined,
            size: 40,
            onPressed: onCalendar,
            tooltip: 'Календарь',
          ),
        AppIconButton(
          icon: Icons.notifications_none_rounded,
          size: 40,
          badge: unread,
          onPressed: onNotifications,
          tooltip: 'Уведомления',
        ),
      ],
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({
    required this.today,
    required this.tasks,
    required this.overdue,
    required this.storiesDone,
    required this.storiesTarget,
    required this.showsStories,
    required this.canCalendar,
    required this.canCheck,
    required this.onTasks,
    required this.onCalendar,
    required this.onCheck,
  });

  final DateTime today;
  final int tasks;
  final int overdue;
  final int storiesDone;
  final int storiesTarget;
  final bool showsStories;
  final bool canCalendar;
  final bool canCheck;
  final VoidCallback onTasks;
  final VoidCallback onCalendar;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final allDone = tasks == 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF191F32), Color(0xFF111624), Color(0xFF151128)],
          stops: [0, 0.55, 1],
        ),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'ФОКУС ДНЯ',
                style: AppTypography.overline(color: AppColors.accentBright),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Text(
                  '${BizDate.weekdayShort(today)}, ${BizDate.dateShort(today)}',
                  style: const TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                allDone ? '0' : '$tasks',
                style: AppTypography.number(
                  size: 54,
                  color: allDone ? AppColors.success : AppColors.text,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      allDone ? 'Всё закрыто' : 'на сегодня',
                      style: const TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      allDone
                          ? 'Можно планировать следующее'
                          : overdue > 0
                              ? '$overdue просрочено'
                              : 'Дедлайны под контролем',
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: overdue > 0 ? AppColors.danger : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showsStories) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.auto_awesome_motion_rounded,
                    size: 14, color: AppColors.ice),
                const SizedBox(width: 6),
                Text(
                  'Сторис: $storiesDone / $storiesTarget',
                  style: const TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: storiesTarget <= 0
                          ? 0
                          : (storiesDone / storiesTarget).clamp(0, 1),
                      minHeight: 4,
                      backgroundColor: AppColors.surface3,
                      valueColor: const AlwaysStoppedAnimation(AppColors.ice),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Задачи',
                  icon: Icons.checklist_rounded,
                  compact: true,
                  variant: AppButtonVariant.secondary,
                  onPressed: onTasks,
                ),
              ),
              if (canCalendar) ...[
                const SizedBox(width: 9),
                Expanded(
                  child: AppButton(
                    label: 'Календарь',
                    icon: Icons.calendar_month_rounded,
                    compact: true,
                    onPressed: onCalendar,
                  ),
                ),
              ],
              if (canCheck) ...[
                const SizedBox(width: 9),
                Expanded(
                  child: AppButton(
                    label: 'Проверки',
                    icon: Icons.fact_check_outlined,
                    compact: true,
                    variant: AppButtonVariant.secondary,
                    onPressed: onCheck,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlCard extends StatelessWidget {
  const _ControlCard({required this.canCheck, required this.onCheck});

  final bool canCheck;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2130), Color(0xFF111624)],
        ),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SurfaceIcon(
                icon: Icons.fact_check_outlined,
                color: AppColors.success,
                size: 46,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Контроль качества',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Проверьте, как проекты закрывают дневную норму сторис.',
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (canCheck) ...[
            const SizedBox(height: 16),
            AppButton(
              label: 'Открыть проверки',
              icon: Icons.arrow_forward_rounded,
              compact: true,
              onPressed: onCheck,
            ),
          ],
        ],
      ),
    );
  }
}

class _StoryTrackerCard extends ConsumerStatefulWidget {
  const _StoryTrackerCard({
    required this.project,
    required this.initialCount,
    required this.editable,
  });

  final SmmProject project;
  final int initialCount;
  final bool editable;

  @override
  ConsumerState<_StoryTrackerCard> createState() => _StoryTrackerCardState();
}

class _StoryTrackerCardState extends ConsumerState<_StoryTrackerCard> {
  late int _count = widget.initialCount;
  bool _busy = false;

  @override
  void didUpdateWidget(covariant _StoryTrackerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_busy &&
        (oldWidget.initialCount != widget.initialCount ||
            oldWidget.project.id != widget.project.id)) {
      _count = widget.initialCount;
    }
  }

  Future<void> _change(int delta) async {
    if (_busy) return;
    final next = (_count + delta).clamp(0, 30);
    if (next == _count) return;
    final previous = _count;
    setState(() {
      _count = next;
      _busy = true;
    });
    try {
      await ref.read(smmRepositoryProvider).upsertStory(
            projectId: widget.project.id,
            date: BizDate.today(),
            storiesCount: next,
          );
      ref.read(dataRevisionProvider.notifier).bump();
    } catch (_) {
      if (mounted) setState(() => _count = previous);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.project.dailyStoriesTarget;
    final progress = target <= 0 ? 0.0 : (_count / target).clamp(0.0, 1.0);
    final complete = target > 0 && _count >= target;

    return SizedBox(
      width: 214,
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 13, 12, 12),
        radius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: complete ? AppColors.success : AppColors.ice,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    widget.project.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$_count',
                  style: AppTypography.number(
                    size: 34,
                    color: complete ? AppColors.success : AppColors.text,
                  ),
                ),
                const SizedBox(width: 5),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '/ $target',
                    style: const TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                const Spacer(),
                if (widget.editable)
                  _StepperButton(
                    icon: Icons.remove_rounded,
                    onTap: _busy ? null : () => _change(-1),
                  ),
                const SizedBox(width: 6),
                if (widget.editable)
                  _StepperButton(
                    icon: Icons.add_rounded,
                    accent: true,
                    onTap: _busy ? null : () => _change(1),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: AppColors.surface3,
                valueColor: AlwaysStoppedAnimation(
                  complete ? AppColors.success : AppColors.ice,
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              complete ? 'Норма закрыта' : 'Дневная норма $target',
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: complete ? AppColors.success : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent ? AppColors.accent : AppColors.surface3,
            border: Border.all(
              color: accent
                  ? AppColors.accentBright.withValues(alpha: 0.4)
                  : AppColors.border,
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: accent ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ProductionRow extends StatelessWidget {
  const _ProductionRow({required this.event, required this.onTap});

  final SmmEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = event.isStory
        ? AppColors.ice
        : event.isReel
            ? AppColors.accent
            : AppColors.info;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      radius: 16,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            alignment: Alignment.center,
            child: Text(
              event.timeLabel.isEmpty ? '—' : event.timeLabel,
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: color,
                fontFeatures: AppTypography.tabular,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 26, color: AppColors.borderSoft),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  event.projectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 10.5,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          AppChip(
            label: event.contentTypeLabel,
            tone: ChipTone.neutral,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = notification.type.contains('overdue') ||
            notification.type.contains('payment')
        ? AppColors.danger
        : notification.type.contains('task')
            ? AppColors.accent
            : AppColors.ice;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      radius: 16,
      onTap: onTap,
      child: Row(
        children: [
          SurfaceIcon(
            icon: Icons.notifications_none_rounded,
            size: 34,
            radius: 11,
            color: color,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    if (!notification.isRead)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: const BoxDecoration(
                          color: AppColors.accentBright,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  notification.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            notification.timeLabel,
            style: const TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 9.5,
              color: AppColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
    this.color = AppColors.accentBright,
  });

  final IconData icon;
  final String label;
  final String value;
  final String hint;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.number(size: 23, color: AppColors.text),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 9.5,
              color: AppColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskSkeleton extends StatelessWidget {
  const _TaskSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 2; i++) ...[
          const AppCard(
            padding: EdgeInsets.all(15),
            radius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 210, height: 13),
                SizedBox(height: 10),
                SkeletonBox(width: 120, height: 10),
              ],
            ),
          ),
          const SizedBox(height: 9),
        ],
      ],
    );
  }
}
