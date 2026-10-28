import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dependencies.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_form.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/dev_board_repository.dart';
import '../domain/dev_task.dart';
import 'dev_board_providers.dart';

class DevBoardPage extends ConsumerWidget {
  const DevBoardPage({super.key, this.embedded = false});

  final bool embedded;

  Future<void> _createTask(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final description = TextEditingController();
    var priority = 'medium';
    final created = await showGlassSheet<bool>(
      context: context,
      title: 'Задача разработки',
      child: StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: description,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Описание'),
            ),
            const SizedBox(height: 12),
            AppChoiceChips<String>(
              selected: priority,
              onChanged: (value) => setState(() => priority = value),
              options: const [
                AppChoice(value: 'low', label: 'Низкий'),
                AppChoice(value: 'medium', label: 'Средний'),
                AppChoice(value: 'high', label: 'Высокий'),
                AppChoice(value: 'critical', label: 'Критичный'),
              ],
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Создать',
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
    final name = title.text.trim();
    final text = description.text.trim();
    title.dispose();
    description.dispose();
    if (created != true || name.isEmpty) return;
    try {
      await ref.read(devBoardRepositoryProvider).createTask({
        'title': name,
        'status': 'todo',
        'priority': priority,
        if (text.isNotEmpty) 'description': text,
      });
      ref.read(dataRevisionProvider.notifier).bump();
    } catch (error) {
      ref.read(dependenciesProvider).banners.show(AppBanner(
            title: 'Задача не создана',
            message: error.toString(),
            tone: BannerTone.danger,
          ));
    }
  }

  void _showChangeStatusDialog(
    BuildContext context,
    WidgetRef ref,
    DevTask task,
  ) {
    showGlassSheet<void>(
      context: context,
      title: 'Сменить статус',
      subtitle: task.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: DevTask.statuses.map((status) {
          final isCurrent = task.status == status;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              isCurrent
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isCurrent
                  ? context.palette.accentBright
                  : context.palette.textTertiary,
            ),
            title: Text(
              DevTask.statusLabel(status),
              style: TextStyle(
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                color: isCurrent
                    ? context.palette.text
                    : context.palette.textSecondary,
              ),
            ),
            onTap: () async {
              Navigator.of(context).pop();
              try {
                await ref
                    .read(devBoardRepositoryProvider)
                    .updateStatus(task.id, status);
                ref.read(dataRevisionProvider.notifier).bump();
              } catch (e) {
                ref.read(dependenciesProvider).banners.show(AppBanner(
                      title: 'Ошибка обновления статуса',
                      message: e.toString(),
                      tone: BannerTone.danger,
                    ));
              }
            },
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final canManage = isDevDirector(user) ||
        isDevLead(user) ||
        userCan(user, Perm.devTrackerManage);
    final statusFilter = ref.watch(devBoardStatusFilterProvider);
    final asyncTasks = ref.watch(devBoardTasksProvider);

    return AppPage(
      showBottomBarSpace: embedded,
      header: AppHeader(
        title: 'Dev-доска',
        subtitle: 'Канбан разработки',
        onBack: embedded ? null : () => context.pop(),
        actions: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canManage) ...[
                  AppIconButton(
                    icon: Icons.add_rounded,
                    size: 40,
                    tooltip: 'Новая задача',
                    onPressed: () => _createTask(context, ref),
                  ),
                  const SizedBox(width: 7),
                ],
                AppIconButton(
                  icon: Icons.refresh_rounded,
                  size: 40,
                  tooltip: 'Обновить',
                  onPressed: () =>
                      ref.read(dataRevisionProvider.notifier).bump(),
                ),
              ],
            ),
          ),
        ],
      ),
      onRefresh: () async {
        ref.read(dataRevisionProvider.notifier).bump();
        await ref.read(devBoardTasksProvider.future);
      },
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(top: 6, bottom: 4),
                child: Row(
                  children: [
                    AppFilterChip(
                      label: 'Проекты',
                      icon: Icons.workspaces_outline,
                      active: false,
                      onTap: () => context.push('/dev/projects'),
                    ),
                    const SizedBox(width: 8),
                    AppFilterChip(
                      label: 'KPI',
                      icon: Icons.speed_rounded,
                      active: false,
                      onTap: () => context.push('/dev-board/kpi'),
                    ),
                    if (canManage) ...[
                      const SizedBox(width: 8),
                      AppFilterChip(
                        label: 'Отчёты',
                        icon: Icons.summarize_outlined,
                        active: false,
                        onTap: () => context.push('/dev-board/reports'),
                      ),
                    ],
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    AppFilterChip(
                      label: 'Все',
                      active: statusFilter == null,
                      onTap: () => ref
                          .read(devBoardStatusFilterProvider.notifier)
                          .setStatus(null),
                    ),
                    ...DevTask.statuses.map((st) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: AppFilterChip(
                          label: DevTask.statusLabel(st),
                          active: statusFilter == st,
                          onTap: () => ref
                              .read(devBoardStatusFilterProvider.notifier)
                              .setStatus(st),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              asyncTasks.when(
                loading: () => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 80),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: context.palette.accent,
                    ),
                  ),
                ),
                error: (error, _) => EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Не удалось загрузить задачи',
                  message: error.toString(),
                  actionLabel: 'Повторить',
                  onAction: () =>
                      ref.read(dataRevisionProvider.notifier).bump(),
                ),
                data: (allTasks) {
                  final tasks = statusFilter == null
                      ? allTasks
                      : allTasks.where((t) => t.status == statusFilter).toList();

                  if (tasks.isEmpty) {
                    return const EmptyState(
                      icon: Icons.developer_board_rounded,
                      title: 'Задач нет',
                      message: 'В этой колонке сейчас пусто.',
                    );
                  }

                  return Column(
                    children: tasks.map((task) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _DevTaskCard(
                          task: task,
                          onTap: () =>
                              context.push('/dev-board/task/${task.id}'),
                          onChangeStatus: () =>
                              _showChangeStatusDialog(context, ref, task),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DevTaskCard extends StatelessWidget {
  const _DevTaskCard({
    required this.task,
    required this.onTap,
    required this.onChangeStatus,
  });

  final DevTask task;
  final VoidCallback onTap;
  final VoidCallback onChangeStatus;

  Color _priorityColor(AppPalette palette, String priority) =>
      switch (priority) {
        'urgent' || 'critical' => palette.danger,
        'high' => const Color(0xFFFF9F43),
        'medium' => palette.accentBright,
        _ => palette.textTertiary,
      };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 18,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (task.projectName != null)
                Text(
                  task.projectName!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w700,
                    color: context.palette.textTertiary,
                  ),
                )
              else
                const SizedBox.shrink(),
              GestureDetector(
                onTap: onChangeStatus,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.palette.surface3,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.palette.borderSoft),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DevTask.statusLabel(task.status),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.palette.accentBright,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 14,
                        color: context.palette.accentBright,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            task.title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.palette.text,
            ),
          ),
          if (task.description != null && task.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              task.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                color: context.palette.textSecondary,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _priorityColor(context.palette, task.priority),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                DevTask.typeLabel(task.type),
                style: TextStyle(
                  fontSize: 11,
                  color: context.palette.textTertiary,
                ),
              ),
              const Spacer(),
              if (task.deadline != null) ...[
                Icon(
                  Icons.schedule_rounded,
                  size: 13,
                  color: context.palette.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  BizDate.dateShort(task.deadline!),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.palette.textTertiary,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              if (task.assigneeName != null) ...[
                AppAvatar(
                  name: task.assigneeName!,
                  avatar: task.assigneeAvatar,
                  size: 20,
                ),
                const SizedBox(width: 5),
                Text(
                  task.assigneeName!,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.palette.textSecondary,
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
