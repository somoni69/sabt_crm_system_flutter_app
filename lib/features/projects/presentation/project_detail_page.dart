import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
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
import '../../smm/domain/smm_models.dart';
import '../../smm/presentation/smm_providers.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/presentation/task_actions.dart';
import '../../tasks/presentation/task_form_sheet.dart';
import '../../tasks/presentation/tasks_providers.dart';
import '../../tasks/presentation/widgets/task_card.dart';
import '../domain/project.dart';
import 'projects_providers.dart';

class ProjectDetailPage extends ConsumerWidget {
  const ProjectDetailPage({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (!canSeeProjects(user)) {
      return AppPage(
        showBottomBarSpace: false,
        header: AppHeader(title: 'Проект', onBack: () => context.pop()),
        slivers: const [
          EmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'Проект недоступен',
            message: 'У вашей роли нет доступа к проектам.',
          ),
        ],
      );
    }

    final async = ref.watch(projectProvider(projectId));
    final snapshot = async.value;
    final project = snapshot?.data;
    final canCreate = canCreateTask(user);

    Future<void> refresh() async {
      ref.read(dataRevisionProvider.notifier).bump();
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }

    return AppPage(
      showBottomBarSpace: false,
      header: AppHeader(
        title: project?.name ?? 'Проект',
        subtitle: project?.typeLabel,
        onBack: () => context.pop(),
        actions: [
          if (project != null && canCreate)
            AppIconButton(
              icon: Icons.add_task_rounded,
              size: 40,
              filled: true,
              color: Colors.white,
              onPressed: () => showTaskForm(context, ref, projectId: project.id),
              tooltip: 'Задача в проект',
            ),
        ],
      ),
      onRefresh: refresh,
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: project == null
              ? _buildPlaceholder(async, refresh)
              : _ProjectBody(
                  project: project,
                  snapshotError: snapshot?.error,
                  savedAt: snapshot?.savedAt,
                  onRefresh: refresh,
                ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(AsyncValue<dynamic> async, Future<void> Function() retry) {
    if (async.hasError) {
      final error = async.error;
      return InlineError(
        message: error is ApiException ? error.message : 'Проект не найден',
        onRetry: retry,
      );
    }
    return const Column(
      children: [
        SkeletonBox(height: 150, radius: 24),
        SizedBox(height: 14),
        SkeletonBox(height: 180, radius: 20),
        SizedBox(height: 14),
        SkeletonBox(height: 200, radius: 20),
      ],
    );
  }
}

class _ProjectBody extends ConsumerWidget {
  const _ProjectBody({
    required this.project,
    required this.snapshotError,
    required this.savedAt,
    required this.onRefresh,
  });

  final ProjectModel project;
  final String? snapshotError;
  final DateTime? savedAt;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final canCreate = canCreateTask(user);
    final showFinance = canSeeFinance(user);
    final tasks = ref.watch(projectTasksProvider(project.id)).value?.data ??
        const <TaskModel>[];
    final planFact = project.isSmm
        ? ref.watch(planFactProvider(project.id)).value ?? const <PlanFactRow>[]
        : const <PlanFactRow>[];

    final openTasks = tasks.where((task) => !task.isClosed).toList();
    final completion = project.taskCount > 0
        ? project.doneTaskCount / project.taskCount
        : project.progress / 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (snapshotError != null) ...[
          OfflineRibbon(
            cachedAt: savedAt,
            showRetry: true,
            onRetry: onRefresh,
          ),
          const SizedBox(height: 14),
        ],
        _ProjectHero(project: project, completion: completion),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _MiniStat(
                icon: Icons.task_alt_rounded,
                label: 'Задачи',
                value: '${project.doneTaskCount}/${project.taskCount}',
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _MiniStat(
                icon: Icons.group_outlined,
                label: 'Команда',
                value: '${project.membersCount}',
                color: AppColors.ice,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _MiniStat(
                icon: Icons.bolt_outlined,
                label: 'Активность',
                value: project.lastActivityAt == null
                    ? '—'
                    : BizDate.relative(project.lastActivityAt!).split(' ').first,
                color: AppColors.accentBright,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const SectionHeader(overline: 'ПРОЕКТ', title: 'Детали'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          radius: 20,
          child: Column(
            children: [
              KeyValueRow(
                label: 'Менеджер',
                value: project.manager?.name ?? 'Не назначен',
                icon: Icons.support_agent_rounded,
              ),
              if (project.salesManager != null) ...[
                const Divider(height: 1, color: AppColors.borderSoft),
                KeyValueRow(
                  label: 'Менеджер продаж',
                  value: project.salesManager!.name,
                  icon: Icons.handshake_outlined,
                ),
              ],
              const Divider(height: 1, color: AppColors.borderSoft),
              KeyValueRow(
                label: 'Старт',
                value: project.startDate == null
                    ? '—'
                    : BizDate.dateWithYear(project.startDate!),
                icon: Icons.play_circle_outline_rounded,
              ),
              const Divider(height: 1, color: AppColors.borderSoft),
              KeyValueRow(
                label: 'Завершение',
                value: project.endDate == null
                    ? 'Бессрочно'
                    : BizDate.dateWithYear(project.endDate!),
                icon: Icons.flag_outlined,
              ),
              if (project.tariffNameSnapshot != null) ...[
                const Divider(height: 1, color: AppColors.borderSoft),
                KeyValueRow(
                  label: 'Тариф',
                  value: project.tariffNameSnapshot!,
                  icon: Icons.local_offer_outlined,
                ),
              ],
              if (showFinance && project.monthlyFee != null) ...[
                const Divider(height: 1, color: AppColors.borderSoft),
                KeyValueRow(
                  label: 'Ежемесячно',
                  value: Money.somoni(project.monthlyFee),
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ],
              if (showFinance && project.nextPaymentDate != null) ...[
                const Divider(height: 1, color: AppColors.borderSoft),
                KeyValueRow(
                  label: 'Следующая оплата',
                  value: BizDate.dateWithYear(project.nextPaymentDate!),
                  icon: Icons.event_repeat_outlined,
                ),
              ],
              if (project.paymentStatus != null) ...[
                const Divider(height: 1, color: AppColors.borderSoft),
                KeyValueRow(
                  label: 'Статус оплаты',
                  value: _paymentLabel(project.paymentStatus!),
                  icon: Icons.receipt_long_outlined,
                  valueColor: project.paymentStatus == 'paid'
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ],
            ],
          ),
        ),
        if (project.members.isNotEmpty) ...[
          const SizedBox(height: 20),
          SectionHeader(
            overline: 'КОМАНДА',
            title: 'На проекте',
            actionLabel: canSeeEmployees(user) ? 'Сотрудники' : null,
            onAction: canSeeEmployees(user)
                ? () => context.push('/employees')
                : null,
          ),
          AppCard(
            padding: const EdgeInsets.all(14),
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 14,
                  runSpacing: 12,
                  children: [
                    for (final member in project.members.take(8))
                      SizedBox(
                        width: 66,
                        child: Column(
                          children: [
                            AppAvatar(
                              name: member.name,
                              avatar: member.avatar,
                              size: 40,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              member.name.split(' ').first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: AppTypography.family,
                                fontSize: 10,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (project.isSmm) ...[
          const SizedBox(height: 20),
          const SectionHeader(overline: 'НОРМЫ', title: 'Контент в месяц'),
          AppCard(
            padding: const EdgeInsets.all(15),
            radius: 20,
            child: Row(
              children: [
                _NormCell(
                  label: 'Рилсы',
                  value: project.normReels,
                  icon: Icons.movie_outlined,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 10),
                _NormCell(
                  label: 'Посты',
                  value: project.normPosts,
                  icon: Icons.grid_view_rounded,
                  color: AppColors.info,
                ),
                const SizedBox(width: 10),
                _NormCell(
                  label: 'Сторис',
                  value: project.storiesPerMonth,
                  icon: Icons.auto_awesome_motion_rounded,
                  color: AppColors.ice,
                ),
              ],
            ),
          ),
          if (planFact.isNotEmpty) ...[
            const SizedBox(height: 20),
            const SectionHeader(overline: 'ПЛАН / ФАКТ', title: 'Производство'),
            AppCard(
              padding: const EdgeInsets.all(15),
              radius: 20,
              child: Column(
                children: [
                  for (var i = 0; i < planFact.length; i++) ...[
                    if (i > 0) const SizedBox(height: 14),
                    _PlanFactRowView(row: planFact[i]),
                  ],
                ],
              ),
            ),
          ],
        ],
        const SizedBox(height: 20),
        SectionHeader(
          overline: 'ЗАДАЧИ',
          title: openTasks.isEmpty
              ? 'Задачи проекта'
              : '${openTasks.length} в работе',
          actionLabel: canCreate ? 'Добавить' : null,
          onAction: canCreate
              ? () => showTaskForm(context, ref, projectId: project.id)
              : null,
        ),
        if (tasks.isEmpty)
          const EmptyState(
            icon: Icons.task_alt_rounded,
            title: 'Задач пока нет',
            message: 'Создайте первую задачу для этого проекта.',
            compact: true,
          )
        else
          for (final task in tasks.take(20)) ...[
            TaskCard(
              task: task,
              showProject: false,
              onTap: () => context.push('/tasks/${task.id}'),
              onQuickDone: task.isClosed
                  ? null
                  : () => quickCompleteTask(context, ref, task),
            ),
            const SizedBox(height: 9),
          ],
        const SizedBox(height: 10),
      ],
    );
  }

  static String _paymentLabel(String status) => switch (status) {
        'paid' => 'Оплачено',
        'pending' => 'Ожидает оплаты',
        'overdue' => 'Просрочено',
        'partial' => 'Частично оплачено',
        _ => status,
      };
}

class _ProjectHero extends StatelessWidget {
  const _ProjectHero({required this.project, required this.completion});

  final ProjectModel project;
  final double completion;

  IconData get _icon {
    if (project.isSmm) return Icons.auto_awesome_rounded;
    if (project.projectType == 'Телеграм бот') return Icons.smart_toy_outlined;
    if (project.isDev) return Icons.code_rounded;
    return Icons.folder_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2032), Color(0xFF111624), Color(0xFF171229)],
          stops: [0, 0.6, 1],
        ),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SurfaceIcon(
                icon: _icon,
                color: project.isSmm ? AppColors.accent : AppColors.ice,
                size: 48,
                radius: 15,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        AppChip(
                          label: project.typeLabel,
                          tone: project.isSmm ? ChipTone.accent : ChipTone.info,
                          compact: true,
                        ),
                        StatusBadge(
                          status: project.status,
                          label: project.statusFieldLabel,
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      project.name,
                      style: const TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 22,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (project.description != null &&
              project.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              project.description!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 12,
                height: 1.5,
                color: AppColors.textTertiary,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(completion * 100).round()}',
                style: AppTypography.number(
                  size: 44,
                  color: completion >= 1 ? AppColors.success : AppColors.text,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 2),
                child: Text(
                  '%',
                  style: AppTypography.number(
                    size: 16,
                    color: completion >= 1 ? AppColors.success : AppColors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'готовность проекта',
                  style: const TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              const Spacer(),
              if (project.hasActiveAd)
                const AppChip(
                  label: 'Активная реклама',
                  tone: ChipTone.warning,
                  compact: true,
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: completion.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.surface3,
              valueColor: AlwaysStoppedAnimation(
                completion >= 1 ? AppColors.success : AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      radius: 17,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.number(size: 19, color: AppColors.text),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 9.5,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NormCell extends StatelessWidget {
  const _NormCell({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int? value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Column(
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(height: 7),
            Text(
              value == null ? '—' : '$value',
              style: AppTypography.number(size: 20, color: AppColors.text),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 9.5,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanFactRowView extends StatelessWidget {
  const _PlanFactRowView({required this.row});

  final PlanFactRow row;

  @override
  Widget build(BuildContext context) {
    final fraction = row.planned <= 0
        ? 0.0
        : (row.published / row.planned).clamp(0.0, 1.0);
    final complete = row.planned > 0 && row.published >= row.planned;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                row.label,
                style: const TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Text(
              '${row.published} / ${row.planned}',
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: complete ? AppColors.success : AppColors.textTertiary,
                fontFeatures: AppTypography.tabular,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 4,
            backgroundColor: AppColors.surface3,
            valueColor: AlwaysStoppedAnimation(
              complete ? AppColors.success : AppColors.accent,
            ),
          ),
        ),
      ],
    );
  }
}
