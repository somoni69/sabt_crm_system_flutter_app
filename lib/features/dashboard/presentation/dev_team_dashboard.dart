import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dependencies.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../shell/presentation/navigation_helpers.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/presentation/tasks_providers.dart';

const _stages = <int, (int, String)>{
  1: (10, 'Сбор требований и ТЗ'),
  2: (25, 'Проектирование и концепт'),
  3: (50, 'Активная фаза производства'),
  4: (75, 'Внутренняя приёмка и QA'),
  5: (90, 'Демонстрация и согласование'),
  6: (100, 'Внедрение и передача'),
};

/// Кабинет разработчика и проект-менеджера: карточки доски и обычные
/// поручения двумя отдельными блоками, как на вебе.
class DevTeamDashboard extends ConsumerStatefulWidget {
  const DevTeamDashboard({super.key});

  @override
  ConsumerState<DevTeamDashboard> createState() => _DevTeamDashboardState();
}

class _DevTeamDashboardState extends ConsumerState<DevTeamDashboard> {
  final Set<String> _keptDone = {};

  Future<void> _refresh() async {
    ref.read(dataRevisionProvider.notifier).bump();
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  Future<void> _toggle(TaskModel task, bool done) async {
    if (done) setState(() => _keptDone.add(task.id));
    try {
      await ref.read(tasksRepositoryProvider).updateStatus(
            task.id,
            done ? 'done' : 'in_progress',
          );
      ref.read(dataRevisionProvider.notifier).bump();
    } on ApiException catch (error) {
      if (done) setState(() => _keptDone.remove(task.id));
      ref.read(dependenciesProvider).banners.show(AppBanner(
            title: 'Не удалось обновить задачу',
            message: error.message,
            tone: BannerTone.danger,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider(TaskFeed.mine)).value?.data ??
        const <TaskModel>[];

    final cards = tasks.where((task) {
      return task.isDevBoardCard && !task.isClosed;
    }).toList()
      ..sort(_byDeadline);

    final plain = tasks.where((task) {
      if (task.isDevBoardCard || task.isCancelled) return false;
      if (task.isDone && !_keptDone.contains(task.id)) return false;
      return true;
    }).toList()
      ..sort(_byDeadline);

    return AppPage(
      header: const AppHeader(title: 'Панель'),
      onRefresh: _refresh,
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (cards.isEmpty && plain.isEmpty)
                EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'На панели пусто',
                  message:
                      'Карточки доски и поручения появятся здесь, как только их назначат.',
                  actionLabel: 'Открыть доску',
                  onAction: () => openShellTab(ref, 'work'),
                )
              else ...[
                if (cards.isNotEmpty) _DevCards(cards: cards),
                if (plain.isNotEmpty) ...[
                  if (cards.isNotEmpty) const SizedBox(height: 16),
                  _PlainTasks(tasks: plain, onToggle: _toggle),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String _plainMeta(TaskModel task, bool overdue) => [
      ?task.projectName,
      if (task.deadline != null) BizDate.dateShort(task.deadline!),
      if (overdue) 'просрочено',
    ].join(' · ');

int _byDeadline(TaskModel a, TaskModel b) {
  final da = a.deadline ?? DateTime(9999);
  final db = b.deadline ?? DateTime(9999);
  return da.compareTo(db);
}

class _DevCards extends StatelessWidget {
  const _DevCards({required this.cards});

  final List<TaskModel> cards;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BlockTitle(
            icon: Icons.construction_rounded,
            title: 'Мои карточки на доске разработки',
            count: cards.length,
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < cards.length; i++) ...[
            _DevCard(task: cards[i]),
            if (i != cards.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _DevCard extends StatelessWidget {
  const _DevCard({required this.task});

  final TaskModel task;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final stage = _stages[task.devStage];
    return Material(
      color: palette.surface2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/tasks/${task.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: palette.accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      stage == null ? '—' : '${stage.$1}%',
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: palette.accentBright,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      stage?.$2 ?? 'Этап не указан',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 11,
                        color: palette.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                task.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: palette.text,
                ),
              ),
              if (task.projectName != null) ...[
                const SizedBox(height: 4),
                Text(
                  task.projectName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 12,
                    color: palette.textSecondary,
                  ),
                ),
              ],
              if (task.deadline != null) ...[
                const SizedBox(height: 6),
                Text(
                  '${BizDate.dateShort(task.deadline!)}${task.isOverdue ? ' · просрочено' : ''}',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 11,
                    fontWeight: task.isOverdue ? FontWeight.w700 : FontWeight.w500,
                    color: task.isOverdue ? palette.danger : palette.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlainTasks extends StatelessWidget {
  const _PlainTasks({required this.tasks, required this.onToggle});

  final List<TaskModel> tasks;
  final Future<void> Function(TaskModel task, bool done) onToggle;

  @override
  Widget build(BuildContext context) {
    final open = tasks.where((task) => !task.isDone).length;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BlockTitle(
            icon: Icons.assignment_outlined,
            title: 'Мои задачи',
            count: open,
          ),
          const SizedBox(height: 6),
          for (final task in tasks) _PlainRow(task: task, onToggle: onToggle),
        ],
      ),
    );
  }
}

class _PlainRow extends StatelessWidget {
  const _PlainRow({required this.task, required this.onToggle});

  final TaskModel task;
  final Future<void> Function(TaskModel task, bool done) onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final done = task.isDone;
    final overdue = task.isOverdue;
    final border = done
        ? palette.success.withValues(alpha: 0.35)
        : overdue
            ? palette.danger.withValues(alpha: 0.45)
            : palette.borderSoft;
    final fill = done
        ? palette.success.withValues(alpha: 0.08)
        : overdue
            ? palette.danger.withValues(alpha: 0.08)
            : palette.surface2;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push('/tasks/${task.id}'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
            child: Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: done ? 'Снять отметку' : 'Отметить готовой',
                  onPressed: () => onToggle(task, !done),
                  icon: Icon(
                    done
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    color: done ? palette.success : palette.textTertiary,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          decoration: done ? TextDecoration.lineThrough : null,
                          color: done ? palette.textTertiary : palette.text,
                        ),
                      ),
                      if (_plainMeta(task, overdue).isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _plainMeta(task, overdue),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 11,
                            color: overdue ? palette.danger : palette.textTertiary,
                            fontWeight: overdue ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BlockTitle extends StatelessWidget {
  const _BlockTitle({
    required this.icon,
    required this.title,
    required this.count,
  });

  final IconData icon;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Icon(icon, size: 18, color: palette.accentBright),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: palette.text,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: palette.surface3,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: palette.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
