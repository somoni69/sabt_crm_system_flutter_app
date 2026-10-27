import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../domain/analytics_data.dart';
import 'analytics_providers.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(analyticsDashboardProvider);

    return AppPage(
      header: AppHeader(
        title: 'Аналитика',
        subtitle: 'Сводные показатели и эффективность',
        onBack: () => context.pop(),
        actions: [
          AppIconButton(
            icon: Icons.refresh_rounded,
            size: 40,
            onPressed: () {
              ref.read(dataRevisionProvider.notifier).bump();
            },
          ),
        ],
      ),
      onRefresh: () async {
        ref.read(dataRevisionProvider.notifier).bump();
        await ref.read(analyticsDashboardProvider.future);
      },
      slivers: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          child: asyncData.when(
            loading: () =>  Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(
                child: CircularProgressIndicator(color: context.palette.accent),
              ),
            ),
            error: (error, _) => EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Не удалось загрузить аналитику',
              message: error.toString(),
              actionLabel: 'Повторить',
              onAction: () => ref.read(dataRevisionProvider.notifier).bump(),
            ),
            data: (data) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildKpiGrid(context, data.overview),
                const SizedBox(height: 20),
                _buildSectionHeader(context, 'Статусы задач'),
                const SizedBox(height: 10),
                _buildStatusBreakdown(context, data),
                const SizedBox(height: 20),
                _buildSectionHeader(context, 'Задачи по приоритетам'),
                const SizedBox(height: 10),
                _buildPriorityBreakdown(context, data),
                if (data.employeeActivity.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildSectionHeader(context, 'Активность команды'),
                  const SizedBox(height: 10),
                  _buildEmployeeActivity(context, data.employeeActivity),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: AppTypography.overline(color: context.palette.textTertiary),
    );
  }

  Widget _buildKpiGrid(BuildContext context, AnalyticsOverview o) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Всего задач',
                value: '${o.totalTasks}',
                subtext: 'Выполнено: ${o.doneTasks}',
                icon: Icons.check_circle_outline_rounded,
                color: context.palette.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'Процент готовности',
                value: '${o.completionRate}%',
                subtext: 'Активных проектов: ${o.activeProjects}',
                icon: Icons.pie_chart_outline_rounded,
                color: context.palette.accentBright,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Просрочено',
                value: '${o.overdueTasks}',
                subtext: o.overdueTasks > 0 ? 'Требует внимания' : 'Всё в графике',
                icon: Icons.alarm_outlined,
                color: o.overdueTasks > 0 ? context.palette.danger : context.palette.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'Часов в этом месяце',
                value: o.hoursThisMonth.toStringAsFixed(1),
                subtext: 'Команда: ${o.totalEmployees}',
                icon: Icons.schedule_rounded,
                color: context.palette.ice,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBreakdown(BuildContext context, AnalyticsDashboardData data) {
    if (data.tasksByStatus.isEmpty) {
      return  _GlassBox(
        child: Text('Нет данных по статусам', style: TextStyle(color: context.palette.textTertiary)),
      );
    }

    final total = data.tasksByStatus.fold<int>(0, (sum, item) => sum + item.count);

    return _GlassBox(
      child: Column(
        children: data.tasksByStatus.map((item) {
          final pct = total > 0 ? (item.count / total) : 0.0;
          final color = context.palette.status(item.status);
          final label = _statusLabel(item.status);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                    Text('${item.count} (${(pct * 100).toStringAsFixed(0)}%)',
                        style:  TextStyle(color: context.palette.textSecondary, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: context.palette.surface3,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPriorityBreakdown(BuildContext context, AnalyticsDashboardData data) {
    if (data.tasksByPriority.isEmpty) {
      return  _GlassBox(
        child: Text('Нет данных по приоритетам', style: TextStyle(color: context.palette.textTertiary)),
      );
    }

    return _GlassBox(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: data.tasksByPriority.map((p) {
          final color = context.palette.priority(p.priority);
          final label = _priorityLabel(p.priority);

          return Column(
            children: [
              Text(
                '${p.count}',
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style:  TextStyle(fontSize: 11, color: context.palette.textTertiary),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmployeeActivity(BuildContext context, List<EmployeeStat> activity) {
    return _GlassBox(
      child: Column(
        children: activity.map((emp) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                AppAvatar(name: emp.name, avatar: emp.avatar, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(emp.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                      const SizedBox(height: 2),
                      Text(
                        'Задач закрыто: ${emp.completedTasks}',
                        style:  TextStyle(fontSize: 11.5, color: context.palette.textTertiary),
                      ),
                    ],
                  ),
                ),
                if (emp.loggedHours > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.palette.surface3,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${emp.loggedHours.toStringAsFixed(1)} ч',
                      style:  TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.palette.ice),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  static String _statusLabel(String status) => switch (status) {
        'new' => 'Новые',
        'in_progress' => 'В работе',
        'on_review' => 'На проверке',
        'done' => 'Готово',
        'cancelled' => 'Отменено',
        _ => status,
      };

  static String _priorityLabel(String priority) => switch (priority) {
        'critical' => 'Критический',
        'high' => 'Высокий',
        'medium' => 'Средний',
        'low' => 'Низкий',
        _ => priority,
      };
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.subtext,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String subtext;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.surface1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 20, color: color),
              Text(
                value,
                style:  TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: context.palette.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style:  TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.palette.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style:  TextStyle(fontSize: 10.5, color: context.palette.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _GlassBox extends StatelessWidget {
  const _GlassBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.palette.surface1,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.palette.borderSoft),
      ),
      child: child,
    );
  }
}
