import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import 'risks_providers.dart';

class RisksPage extends ConsumerStatefulWidget {
  const RisksPage({super.key});

  @override
  ConsumerState<RisksPage> createState() => _RisksPageState();
}

class _RisksPageState extends ConsumerState<RisksPage> {
  int _tabIndex = 0; // 0: Проекты, 1: Нагрузка

  Color _levelColor(String level) {
    switch (level.toLowerCase()) {
      case 'red':
        return AppColors.danger;
      case 'yellow':
        return AppColors.warning;
      case 'green':
      default:
        return AppColors.success;
    }
  }

  String _levelLabel(String level) {
    switch (level.toLowerCase()) {
      case 'red':
        return 'Высокий риск';
      case 'yellow':
        return 'Внимание';
      case 'green':
      default:
        return 'Стабильно';
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectRisksProvider);
    final workloadAsync = ref.watch(employeeWorkloadProvider);

    return AppPage(
      header: AppHeader(
        title: 'Управление рисками',
        subtitle: 'План-факт, отставания и перегрузка',
        onBack: () => context.pop(),
      ),
      onRefresh: () async {
        ref.read(dataRevisionProvider.notifier).bump();
        if (_tabIndex == 0) {
          await ref.read(projectRisksProvider.future);
        } else {
          await ref.read(employeeWorkloadProvider.future);
        }
      },
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tab Switcher
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _tabIndex = 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _tabIndex == 0 ? AppColors.accent : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Риски проектов',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _tabIndex == 0 ? FontWeight.w700 : FontWeight.w500,
                              color: _tabIndex == 0 ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _tabIndex = 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _tabIndex == 1 ? AppColors.accent : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Нагрузка команды',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _tabIndex == 1 ? FontWeight.w700 : FontWeight.w500,
                              color: _tabIndex == 1 ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_tabIndex == 0) ...[
                projectsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                  ),
                  error: (e, _) => EmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Не удалось загрузить риски',
                    message: e.toString(),
                    actionLabel: 'Повторить',
                    onAction: () => ref.read(dataRevisionProvider.notifier).bump(),
                  ),
                  data: (projects) {
                    if (projects.isEmpty) {
                      return const EmptyState(
                        icon: Icons.verified_user_outlined,
                        title: 'Рисков не обнаружено',
                        message: 'Все проекты идут по плану без критических отклонений.',
                      );
                    }
                    return Column(
                      children: projects.map((p) {
                        final color = _levelColor(p.level);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface1,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        p.projectName,
                                        style: AppTypography.textTheme.titleMedium,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: color.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        _levelLabel(p.level),
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
                                      ),
                                    ),
                                  ],
                                ),
                                if (p.managerName != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Менеджер: ${p.managerName}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                                  ),
                                ],
                                if (p.factors.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  const Divider(color: AppColors.borderSoft, height: 1),
                                  const SizedBox(height: 8),
                                  ...p.factors.where((f) => f.triggered).map((f) => Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.warning_amber_rounded,
                                                size: 14, color: AppColors.warning),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                f.label,
                                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ] else ...[
                workloadAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                  ),
                  error: (e, _) => EmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Не удалось загрузить нагрузку',
                    message: e.toString(),
                    actionLabel: 'Повторить',
                    onAction: () => ref.read(dataRevisionProvider.notifier).bump(),
                  ),
                  data: (workloads) {
                    if (workloads.isEmpty) {
                      return const EmptyState(
                        icon: Icons.group_outlined,
                        title: 'Данных нет',
                        message: 'Нагрузка по сотрудникам пока не рассчитана.',
                      );
                    }
                    return Column(
                      children: workloads.map((w) {
                        final color = _levelColor(w.overload);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface1,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(w.userName, style: AppTypography.textTheme.titleMedium),
                                      const SizedBox(height: 2),
                                      Text(
                                        w.role,
                                        style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          _WorkloadBadge(
                                            label: 'Проектов: ${w.projectCount}',
                                          ),
                                          const SizedBox(width: 6),
                                          _WorkloadBadge(
                                            label: 'В работе: ${w.tasksInProgress}',
                                          ),
                                          const SizedBox(width: 6),
                                          _WorkloadBadge(
                                            label: 'В очереди: ${w.tasksInQueue}',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _WorkloadBadge extends StatelessWidget {
  const _WorkloadBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
      ),
    );
  }
}
