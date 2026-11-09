import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dependencies.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../domain/task.dart';
import 'tasks_providers.dart';

/// Кабинет поручений исполнителя: «мне выдали» и, если есть, «я выдал».
/// Статус меняется одной кнопкой, без перехода в карточку.
class ManagementTasksPage extends ConsumerStatefulWidget {
  const ManagementTasksPage({super.key});

  @override
  ConsumerState<ManagementTasksPage> createState() => _ManagementTasksPageState();
}

class _ManagementTasksPageState extends ConsumerState<ManagementTasksPage> {
  bool _assignedTab = false;
  String? _busyId;

  Future<void> _refresh() async {
    ref.read(dataRevisionProvider.notifier).bump();
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  Future<void> _setStatus(TaskModel task, String status) async {
    setState(() => _busyId = task.id);
    try {
      await ref.read(tasksRepositoryProvider).updateStatus(task.id, status);
      ref.read(dataRevisionProvider.notifier).bump();
      ref.read(dependenciesProvider).banners.show(AppBanner(
            title: 'Статус обновлён',
            message: task.title,
            tone: BannerTone.success,
          ));
    } on ApiException catch (error) {
      ref.read(dependenciesProvider).banners.show(AppBanner(
            title: 'Не удалось обновить статус',
            message: error.message,
            tone: BannerTone.danger,
          ));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(tasksProvider(TaskFeed.management)).value?.data ??
        const <TaskModel>[];
    final assigned = ref.watch(tasksProvider(TaskFeed.assigned)).value?.data ??
        const <TaskModel>[];
    final canAssign = assigned.isNotEmpty;
    final showAssigned = canAssign && _assignedTab;
    final list = showAssigned ? assigned : mine;

    return AppPage(
      header: const AppHeader(title: 'Задачи от руководителя'),
      onRefresh: _refresh,
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (canAssign) ...[
                Row(
                  children: [
                    _TabChip(
                      label: 'Мне · ${mine.length}',
                      selected: !showAssigned,
                      onTap: () => setState(() => _assignedTab = false),
                    ),
                    const SizedBox(width: 8),
                    _TabChip(
                      label: 'Я выдал · ${assigned.length}',
                      selected: showAssigned,
                      onTap: () => setState(() => _assignedTab = true),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (list.isEmpty)
                EmptyState(
                  icon: Icons.assignment_outlined,
                  title: showAssigned
                      ? 'Вы пока не выдавали задач'
                      : 'Задач от руководителя нет',
                  message: showAssigned
                      ? 'Поставьте задачу сотруднику — она появится здесь со статусом.'
                      : 'Здесь появятся поручения от основателя и руководителей направлений.',
                )
              else
                for (final task in list) ...[
                  _AssignmentCard(
                    task: task,
                    assignedView: showAssigned,
                    busy: _busyId == task.id,
                    onStatus: (status) => _setStatus(task, status),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: selected ? palette.accent : palette.surface3,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.task,
    required this.assignedView,
    required this.busy,
    required this.onStatus,
  });

  final TaskModel task;
  final bool assignedView;
  final bool busy;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final canChange = !assignedView && task.status != 'done' && task.status != 'cancelled';

    return AppCard(
      padding: const EdgeInsets.all(14),
      radius: 12,
      onTap: () => context.push('/tasks/${task.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 15,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: task.status),
            ],
          ),
          if ((task.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              task.description!.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 12,
                height: 1.35,
                color: palette.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _meta(task, assignedView),
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 11.5,
              height: 1.35,
              color: task.isOverdue ? palette.danger : palette.textTertiary,
              fontWeight: task.isOverdue ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          if (canChange) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (task.status != 'in_progress')
                  TextButton.icon(
                    onPressed: busy ? null : () => onStatus('in_progress'),
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: const Text('Взять в работу'),
                  ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.success,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: busy ? null : () => onStatus('done'),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Выполнено'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _meta(TaskModel task, bool assignedView) {
    final who = assignedView
        ? 'Исполнитель: ${task.assigneeLabel}'
        : (task.createdByName == null ? null : 'от ${task.createdByName}');
    final priority = switch (task.priority) {
      'low' => 'Низкий',
      'medium' => 'Средний',
      'high' => 'Высокий',
      'critical' => 'Критический',
      'urgent' => 'Срочный',
      _ => null,
    };
    return [
      ?who,
      ?task.projectName,
      ?priority,
      if (task.deadline != null)
        '${_dotDate(task.deadline!)}${task.isOverdue ? ' · просрочено' : ''}',
    ].join(' · ');
  }
}

String _dotDate(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year}';
}
