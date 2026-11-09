import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_range_key.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../projects/domain/project.dart';
import '../../projects/presentation/projects_providers.dart';
import '../../shell/presentation/navigation_helpers.dart';
import '../../smm/domain/smm_models.dart';
import '../../smm/presentation/smm_providers.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/presentation/tasks_providers.dart';

/// Кабинет проект-менеджера в том же составе, что панель на вебе:
/// карточки доски, «Мои задачи», истории за день и активные проекты.
class OfficeHomePage extends ConsumerWidget {
  const OfficeHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final tasks = ref.watch(tasksProvider(TaskFeed.mine)).value?.data ??
        const <TaskModel>[];
    final projects = ref.watch(projectsProvider).value?.data ??
        const <ProjectModel>[];
    final today = BizDate.today();
    final monthLogs = ref
            .watch(storyLogsProvider(DateRangeKey(BizDate.monthStart(today), today)))
            .value
            ?.data ??
        const <StoryLog>[];
    final todayLogs = ref.watch(todayStoryLogsProvider);

    final cards = tasks.where((task) => task.isDevBoardCard && !task.isClosed).toList()
      ..sort(_byDeadline);
    final mine = tasks.where((task) => !task.isCancelled).take(6).toList();
    final storyProjects = _storyProjects(projects, user?.id);
    final active = projects
        .where((project) => !project.isArchived && project.status == 'in_progress')
        .take(4)
        .toList();

    Future<void> refresh() async {
      ref.read(dataRevisionProvider.notifier).bump();
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }

    return AppPage(
      header: const AppHeader(title: 'Панель'),
      onRefresh: refresh,
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (cards.isNotEmpty) ...[
                _WebCard(
                  title: 'Мои карточки на доске разработки',
                  trailing: '${cards.length}',
                  child: Column(
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        _DevStageRow(task: cards[i]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _WebCard(
                title: 'Мои задачи',
                action: 'Все',
                onAction: () => openShellTab(ref, 'tasks'),
                child: mine.isEmpty
                    ? const _QuietLine('Задач пока нет')
                    : Column(
                        children: [
                          for (var i = 0; i < mine.length; i++) ...[
                            if (i > 0) Divider(height: 1, color: context.palette.borderSoft),
                            _TaskRow(task: mine[i], userId: user?.id),
                          ],
                        ],
                      ),
              ),
              if (storyProjects.isNotEmpty) ...[
                const SizedBox(height: 12),
                _StoriesCard(
                  projects: storyProjects,
                  todayLogs: todayLogs,
                  monthLogs: monthLogs,
                  day: today.day,
                ),
              ],
              const SizedBox(height: 12),
              _WebCard(
                title: 'Активные проекты',
                child: active.isEmpty
                    ? const _QuietLine('Нет активных проектов')
                    : Column(
                        children: [
                          for (final project in active) ...[
                            _ProjectRow(project: project),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

int _byDeadline(TaskModel a, TaskModel b) {
  final da = a.deadline ?? DateTime(9999);
  final db = b.deadline ?? DateTime(9999);
  return da.compareTo(db);
}

List<ProjectModel> _storyProjects(List<ProjectModel> projects, String? userId) {
  return projects.where((project) {
    if (project.isArchived || !project.isSmm) return false;
    if (userId == null) return false;
    final member = project.members.any((person) => person.id == userId);
    final manager = project.manager?.id == userId || project.salesManager?.id == userId;
    return member || manager;
  }).toList();
}

int _dailyTarget(ProjectModel project) {
  final data = project.smmData ?? const <String, dynamic>{};
  final month = data['storiesPerMonth'];
  if (month is num && month > 0) {
    final days = BizDate.daysInMonth(BizDate.today());
    final value = (month / days).round();
    return value < 1 ? 1 : value;
  }
  final day = data['storiesPerDay'];
  if (day is num && day > 0) return day.round();
  return 2;
}

class _WebCard extends StatelessWidget {
  const _WebCard({
    required this.title,
    required this.child,
    this.action,
    this.onAction,
    this.trailing,
  });

  final String title;
  final Widget child;
  final String? action;
  final VoidCallback? onAction;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.palette.text,
                  ),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 12,
                    color: context.palette.textTertiary,
                  ),
                ),
              if (action != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(action!),
                ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.userId});

  final TaskModel task;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final overdue = task.isOverdue;
    final from = _fromLabel(task, userId);
    return InkWell(
      onTap: () => context.push('/tasks/${task.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: task.title,
                          style: TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: palette.text,
                          ),
                        ),
                        if (from != null)
                          TextSpan(
                            text: '  $from',
                            style: TextStyle(
                              fontFamily: AppTypography.family,
                              fontSize: 12,
                              color: palette.textTertiary,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (task.deadline != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    _dotDate(task.deadline!),
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 12,
                      fontFeatures: AppTypography.tabular,
                      color: overdue ? palette.danger : palette.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Badge(label: _priorityLabel(task.priority), color: palette.priority(task.priority)),
                _Badge(label: _statusLabel(task.status), color: palette.status(task.status)),
                if (task.projectName != null && task.projectName!.isNotEmpty)
                  Text(
                    task.projectName!,
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
      ),
    );
  }
}

class _StoriesCard extends StatelessWidget {
  const _StoriesCard({
    required this.projects,
    required this.todayLogs,
    required this.monthLogs,
    required this.day,
  });

  final List<ProjectModel> projects;
  final List<StoryLog> todayLogs;
  final List<StoryLog> monthLogs;
  final int day;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final done = projects.where((project) {
      final target = _dailyTarget(project);
      return _count(todayLogs, project.id) >= target;
    }).length;
    final monthActual = monthLogs.fold<int>(0, (sum, log) => sum + log.storiesCount);
    final monthExpected = projects.fold<int>(
      0,
      (sum, project) => sum + _dailyTarget(project) * day,
    );
    final monthPct = monthExpected == 0
        ? 0
        : ((monthActual / monthExpected) * 100).round().clamp(0, 100);

    return _WebCard(
      title: 'Истории сегодня',
      trailing: '$done/${projects.length} проектов',
      child: Column(
        children: [
          for (final project in projects)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 13,
                        color: palette.text,
                      ),
                    ),
                  ),
                  _Dots(
                    count: _count(todayLogs, project.id),
                    target: _dailyTarget(project),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${_count(todayLogs, project.id)}/${_dailyTarget(project)}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 11,
                        fontFeatures: AppTypography.tabular,
                        color: _count(todayLogs, project.id) == 0
                            ? palette.danger
                            : palette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Divider(height: 1, color: palette.borderSoft),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'За месяц',
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 12,
                  color: palette.textTertiary,
                ),
              ),
              const Spacer(),
              Text(
                '$monthPct%  $monthActual/$monthExpected',
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 12,
                  fontFeatures: AppTypography.tabular,
                  color: monthPct == 0 ? palette.danger : palette.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: monthExpected == 0
                  ? 0
                  : (monthActual / monthExpected).clamp(0, 1).toDouble(),
              minHeight: 4,
              backgroundColor: palette.surface3,
              color: palette.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: () => context.push('/projects/${project.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: palette.text,
                  ),
                ),
              ),
              Text(
                '${project.progress}%',
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 12,
                  fontFeatures: AppTypography.tabular,
                  color: palette.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: project.progress / 100,
              minHeight: 4,
              backgroundColor: palette.surface3,
              color: palette.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _DevStageRow extends StatelessWidget {
  const _DevStageRow({required this.task});

  final TaskModel task;

  @override
  Widget build(BuildContext context) {
    final stage = _stageLabel(task.devStage);
    return InkWell(
      onTap: () => context.push('/tasks/${task.id}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stage,
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 11,
                color: context.palette.accentBright,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              task.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.palette.text,
              ),
            ),
            if (task.projectName != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  task.projectName!,
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 12,
                    color: context.palette.textTertiary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.target});

  final int count;
  final int target;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final total = target.clamp(1, 8);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(left: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < count
                  ? (count >= target ? palette.success : palette.textTertiary)
                  : palette.surface4,
            ),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTypography.family,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: color,
        ),
      ),
    );
  }
}

class _QuietLine extends StatelessWidget {
  const _QuietLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppTypography.family,
          fontSize: 13,
          color: context.palette.textTertiary,
        ),
      ),
    );
  }
}

int _count(List<StoryLog> logs, String projectId) {
  var total = 0;
  for (final log in logs) {
    if (log.projectId == projectId) total += log.storiesCount;
  }
  return total;
}

String? _fromLabel(TaskModel task, String? userId) {
  final author = task.createdByName?.trim();
  if (author == null || author.isEmpty) return null;
  if (task.createdById != null && task.createdById == task.assigneeId) return 'сам';
  if (userId != null && task.createdById == userId) return 'сам';
  return 'от ${author.split(' ').first}';
}

String _dotDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month';
}

String _stageLabel(int? stage) => switch (stage) {
  1 => '10% · Сбор требований и ТЗ',
  2 => '25% · Проектирование и концепт',
  3 => '50% · Активная фаза производства',
  4 => '75% · Внутренняя приёмка и QA',
  5 => '90% · Демонстрация и согласование',
  6 => '100% · Внедрение и передача',
  _ => 'Этап не указан',
};

String _priorityLabel(String priority) => switch (priority) {
  'critical' => 'КРИТИЧНЫЙ',
  'high' => 'ВЫСОКИЙ',
  'medium' => 'СРЕДНИЙ',
  'low' => 'НИЗКИЙ',
  _ => priority.toUpperCase(),
};

String _statusLabel(String status) => switch (status) {
  'done' => 'ГОТОВО',
  'in_progress' => 'В РАБОТЕ',
  'review' || 'on_review' => 'ПРОВЕРКА',
  'todo' || 'new' || 'open' => 'НОВАЯ',
  'cancelled' => 'ОТМЕНА',
  _ => status.toUpperCase(),
};
