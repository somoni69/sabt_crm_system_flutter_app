import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/motion.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/state/app_state.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/task.dart';
import 'management_tasks_page.dart';
import 'task_actions.dart';
import 'task_form_sheet.dart';
import 'tasks_providers.dart';
import 'widgets/task_card.dart';

enum _TaskFilter { all, overdue, today, done }

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  TaskFeed _feed = TaskFeed.mine;
  _TaskFilter _filter = _TaskFilter.all;
  final _search = TextEditingController();
  bool _searchOpen = false;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(TaskModel task) {
    switch (_filter) {
      case _TaskFilter.all:
        break;
      case _TaskFilter.overdue:
        if (!task.isOverdue) return false;
        break;
      case _TaskFilter.today:
        if (!task.isDueToday) return false;
        break;
      case _TaskFilter.done:
        if (!task.isDone) return false;
        break;
    }
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return task.title.toLowerCase().contains(query) ||
        (task.description ?? '').toLowerCase().contains(query) ||
        task.projectLabel.toLowerCase().contains(query) ||
        task.assigneeLabel.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user != null && !isDevLead(user)) {
      return const ManagementTasksPage();
    }
    final canCreate = canCreateTask(user);
    final async = ref.watch(tasksProvider(_feed));
    final snapshot = async.value;
    final all = snapshot?.data ?? const <TaskModel>[];
    final tasks = all.where(_matches).toList();
    final openCount = all.where((task) => !task.isClosed).length;
    final overdueCount = all.where((task) => task.isOverdue).length;
    final todayCount = all.where((task) => task.isDueToday).length;
    final doneCount = all.where((task) => task.isDone).length;

    final error = async.error;
    final errorMessage = error is ApiException
        ? error.message
        : error is StateError
        ? error.message
        : 'Не удалось загрузить задачи';

    Future<void> refresh() async {
      ref.read(dataRevisionProvider.notifier).bump();
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }

    final groups = _groupTasks(tasks);

    return AppPage(
      header: AppHeader(
        title: 'Задачи',
        subtitle: all.isEmpty
            ? 'Рабочий поток команды'
            : '$openCount в работе · $overdueCount просрочено',
        actions: [
          AppIconButton(
            icon: _searchOpen ? Icons.close_rounded : Icons.search_rounded,
            size: 40,
            onPressed: () {
              setState(() {
                _searchOpen = !_searchOpen;
                if (!_searchOpen) {
                  _search.clear();
                  _query = '';
                }
              });
            },
            tooltip: 'Поиск',
          ),
          if (canCreate)
            AppIconButton(
              icon: Icons.add_rounded,
              size: 40,
              onPressed: () async {
                final id = await showTaskForm(context, ref);
                if (id != null && id.isNotEmpty && context.mounted) {
                  context.push('/tasks/$id');
                }
              },
              tooltip: 'Новая задача',
            ),
        ],
      ),
      onRefresh: refresh,
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassSegmentedControl<TaskFeed>(
                selected: _feed,
                onChanged: (value) => setState(() => _feed = value),
                items: const [
                  SegmentItem(value: TaskFeed.mine, label: 'Мои'),
                  SegmentItem(
                    value: TaskFeed.management,
                    label: 'От руководства',
                  ),
                  SegmentItem(value: TaskFeed.assigned, label: 'Я выдал'),
                ],
              ),
              MotionSwap(
                duration: Motion.micro,
                scale: false,
                child: _searchOpen
                    ? Padding(
                        key: const ValueKey('task-search'),
                        padding: const EdgeInsets.only(top: 10),
                        child: AppSearchField(
                          controller: _search,
                          hint: 'Название, проект, исполнитель',
                          autofocus: true,
                          onChanged: (value) => setState(() => _query = value),
                        ),
                      )
                    : const SizedBox(
                        key: ValueKey('task-search-closed'),
                        width: double.infinity,
                      ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    AppFilterChip(
                      label: 'Все',
                      count: all.length,
                      active: _filter == _TaskFilter.all,
                      onTap: () => setState(() => _filter = _TaskFilter.all),
                    ),
                    const SizedBox(width: 7),
                    AppFilterChip(
                      label: 'Просроченные',
                      count: overdueCount,
                      active: _filter == _TaskFilter.overdue,
                      tone: ChipTone.danger,
                      onTap: () =>
                          setState(() => _filter = _TaskFilter.overdue),
                    ),
                    const SizedBox(width: 7),
                    AppFilterChip(
                      label: 'Сегодня',
                      count: todayCount,
                      active: _filter == _TaskFilter.today,
                      tone: ChipTone.warning,
                      onTap: () => setState(() => _filter = _TaskFilter.today),
                    ),
                    const SizedBox(width: 7),
                    AppFilterChip(
                      label: 'Готовые',
                      count: doneCount,
                      active: _filter == _TaskFilter.done,
                      tone: ChipTone.success,
                      onTap: () => setState(() => _filter = _TaskFilter.done),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (snapshot?.error != null && all.isEmpty)
                InlineError(message: errorMessage, onRetry: refresh)
              else ...[
                if (snapshot?.error != null) ...[
                  OfflineRibbon(
                    cachedAt: snapshot?.savedAt,
                    showRetry: true,
                    onRetry: refresh,
                  ),
                  const SizedBox(height: 14),
                ],
                if (async.isLoading && snapshot == null)
                  const _TasksSkeleton()
                else if (error != null && snapshot == null)
                  InlineError(message: errorMessage, onRetry: refresh)
                else if (tasks.isEmpty)
                  EmptyState(
                    icon: _feed == TaskFeed.assigned
                        ? Icons.outbox_outlined
                        : _filter == _TaskFilter.done
                        ? Icons.task_alt_rounded
                        : Icons.self_improvement_rounded,
                    title: _emptyTitle,
                    message: _emptyMessage,
                    actionLabel: canCreate && _feed == TaskFeed.mine
                        ? 'Создать задачу'
                        : null,
                    onAction: canCreate
                        ? () => showTaskForm(context, ref)
                        : null,
                  )
                else
                  for (final group in groups) ...[
                    SectionHeader(
                      overline: group.overline,
                      title: group.title,
                      actionLabel: '${group.tasks.length}',
                      onAction: null,
                      padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
                    ),
                    for (final task in group.tasks) ...[
                      TaskCard(
                        task: task,
                        showProject: true,
                        onTap: () => context.push('/tasks/${task.id}'),
                        onQuickDone: task.isClosed || _feed == TaskFeed.assigned
                            ? null
                            : () => quickCompleteTask(context, ref, task),
                      ),
                      const SizedBox(height: 9),
                    ],
                    const SizedBox(height: 12),
                  ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  String get _emptyTitle {
    if (_query.trim().isNotEmpty) return 'Ничего не нашлось';
    if (_filter == _TaskFilter.overdue) return 'Просрочек нет';
    if (_filter == _TaskFilter.done) return 'Пока нет завершённых';
    if (_feed == TaskFeed.assigned) return 'Вы ещё не выдавали задачи';
    if (_feed == TaskFeed.management) return 'От руководства пока тихо';
    return 'Все задачи закрыты';
  }

  String get _emptyMessage {
    if (_query.trim().isNotEmpty) {
      return 'Попробуйте изменить запрос или фильтр.';
    }
    if (_feed == TaskFeed.assigned) {
      return 'Назначьте задачу сотруднику — она появится в этом списке.';
    }
    return 'Хорошее время, чтобы спланировать контент или новые задачи.';
  }

  List<_TaskGroup> _groupTasks(List<TaskModel> tasks) {
    final overdue = <TaskModel>[];
    final today = <TaskModel>[];
    final upcoming = <TaskModel>[];
    final noDeadline = <TaskModel>[];
    final done = <TaskModel>[];

    for (final task in tasks) {
      if (task.isDone) {
        done.add(task);
      } else if (task.isCancelled) {
        noDeadline.add(task);
      } else if (task.isOverdue) {
        overdue.add(task);
      } else if (task.isDueToday) {
        today.add(task);
      } else if (task.deadline != null) {
        upcoming.add(task);
      } else {
        noDeadline.add(task);
      }
    }

    return [
      if (overdue.isNotEmpty)
        _TaskGroup(
          overline: 'ТРЕБУЮТ ВНИМАНИЯ',
          title: 'Просрочено',
          tasks: overdue,
        ),
      if (today.isNotEmpty)
        _TaskGroup(overline: 'СЕГОДНЯ', title: 'На сегодня', tasks: today),
      if (upcoming.isNotEmpty)
        _TaskGroup(overline: 'ДАЛЬШЕ', title: 'Ближайшие', tasks: upcoming),
      if (noDeadline.isNotEmpty)
        _TaskGroup(
          overline: 'БЕЗ СРОКА',
          title: 'Без дедлайна',
          tasks: noDeadline,
        ),
      if (done.isNotEmpty)
        _TaskGroup(overline: 'ГОТОВО', title: 'Завершённые', tasks: done),
    ];
  }
}

class _TaskGroup {
  const _TaskGroup({
    required this.overline,
    required this.title,
    required this.tasks,
  });

  final String overline;
  final String title;
  final List<TaskModel> tasks;
}

class _TasksSkeleton extends StatelessWidget {
  const _TasksSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 5; i++) ...[
          const AppCard(
            padding: EdgeInsets.all(15),
            radius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 230, height: 13),
                SizedBox(height: 10),
                Row(
                  children: [
                    SkeletonBox(width: 90, height: 9),
                    SizedBox(width: 10),
                    SkeletonBox(width: 70, height: 9),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
        ],
      ],
    );
  }
}
