import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dependencies.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_form.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../data/dev_board_repository.dart';
import '../domain/dev_task.dart';
import 'dev_board_providers.dart';

class DevBoardPage extends ConsumerWidget {
  const DevBoardPage({super.key});

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

  void _showChangeStatusDialog(BuildContext context, WidgetRef ref, DevTask task) {
    showGlassSheet(
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
              isCurrent ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: isCurrent ? AppColors.accentBright : AppColors.textTertiary,
            ),
            title: Text(
              DevTask.statusLabel(status),
              style: TextStyle(
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                color: isCurrent ? AppColors.text : AppColors.textSecondary,
              ),
            ),
            onTap: () async {
              Navigator.of(context).pop();
              try {
                await ref.read(devBoardRepositoryProvider).updateStatus(task.id, status);
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
    final statusFilter = ref.watch(devBoardStatusFilterProvider);
    final asyncTasks = ref.watch(devBoardTasksProvider);

    return AppPage(
      header: AppHeader(
        title: 'Dev-доска',
        subtitle: 'Канбан разработки',
        onBack: () => context.pop(),
        actions: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIconButton(
                  icon: Icons.add_rounded,
                  size: 40,
                  tooltip: 'Новая задача',
                  onPressed: () => _createTask(context, ref),
                ),
                const SizedBox(width: 7),
                AppIconButton(
                  icon: Icons.refresh_rounded,
                  size: 40,
                  tooltip: 'Обновить',
                  onPressed: () => ref.read(dataRevisionProvider.notifier).bump(),
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
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Все',
                      selected: statusFilter == null,
                      onTap: () => ref.read(devBoardStatusFilterProvider.notifier).setStatus(null),
                    ),
                    ...DevTask.statuses.map((st) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _FilterChip(
                          label: DevTask.statusLabel(st),
                          selected: statusFilter == st,
                          onTap: () => ref.read(devBoardStatusFilterProvider.notifier).setStatus(st),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              asyncTasks.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  ),
                ),
                error: (error, _) => EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Не удалось загрузить задачи',
                  message: error.toString(),
                  actionLabel: 'Повторить',
                  onAction: () => ref.read(dataRevisionProvider.notifier).bump(),
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
                          onChangeStatus: () => _showChangeStatusDialog(context, ref, task),
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.accentBright : AppColors.borderSoft,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DevTaskCard extends StatelessWidget {
  const _DevTaskCard({
    required this.task,
    required this.onChangeStatus,
  });

  final DevTask task;
  final VoidCallback onChangeStatus;

  Color _priorityColor(String priority) => switch (priority) {
        'urgent' || 'critical' => AppColors.danger,
        'high' => const Color(0xFFFF9F43),
        'medium' => AppColors.accentBright,
        _ => AppColors.textTertiary,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (task.projectName != null)
                Text(
                  task.projectName!.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                  ),
                )
              else
                const SizedBox.shrink(),
              GestureDetector(
                onTap: onChangeStatus,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface3,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DevTask.statusLabel(task.status),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentBright,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down_rounded, size: 14, color: AppColors.accentBright),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            task.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          if (task.description != null && task.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              task.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
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
                  color: _priorityColor(task.priority),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                DevTask.typeLabel(task.type),
                style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
              const Spacer(),
              if (task.deadline != null) ...[
                const Icon(Icons.schedule_rounded, size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  BizDate.dateShort(task.deadline!),
                  style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
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
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
