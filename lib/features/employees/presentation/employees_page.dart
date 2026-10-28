import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/rbac/permissions.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/employee.dart';
import 'employees_providers.dart';

class EmployeesPage extends ConsumerStatefulWidget {
  const EmployeesPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends ConsumerState<EmployeesPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final canSee = canSeeEmployees(user);
    final async = ref.watch(employeesProvider);
    final snapshot = async.value;
    final employees = snapshot?.data ?? const <EmployeeModel>[];
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? employees
        : employees
            .where((employee) =>
                employee.fullName.toLowerCase().contains(query) ||
                employee.position.toLowerCase().contains(query) ||
                employee.department.toLowerCase().contains(query) ||
                employee.email.toLowerCase().contains(query))
            .toList();

    final groups = <String, List<EmployeeModel>>{};
    for (final employee in filtered) {
      groups.putIfAbsent(employee.department, () => []).add(employee);
    }
    final departments = groups.keys.toList()..sort();

    Future<void> refresh() async {
      ref.read(dataRevisionProvider.notifier).bump();
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }

    return AppPage(
      showBottomBarSpace: widget.embedded,
      header: AppHeader(
        title: 'Сотрудники',
        subtitle: employees.isEmpty ? 'Команда WeBrand' : '${employees.length} в команде',
        onBack: widget.embedded ? null : () => context.pop(),
      ),
      onRefresh: canSee ? refresh : null,
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.embedded)
                const PageIntro(
                  overline: 'КОМАНДА',
                  title: 'Сотрудники',
                  subtitle: 'Контакты, роли и загрузка команды агентства.',
                ),
              if (!canSee)
                const EmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: 'Раздел недоступен',
                  message: 'У вашей роли нет доступа к справочнику сотрудников.',
                )
              else ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      AppFilterChip(
                        label: 'Оргструктура',
                        icon: Icons.account_tree_outlined,
                        active: false,
                        onTap: () => context.push('/employees/org'),
                      ),
                      if (canManageAccess(user)) ...[
                        const SizedBox(width: 8),
                        AppFilterChip(
                          label: 'KPI',
                          icon: Icons.speed_rounded,
                          active: false,
                          onTap: () => context.push('/employees/kpi'),
                        ),
                        const SizedBox(width: 8),
                        AppFilterChip(
                          label: 'Задачи недели',
                          icon: Icons.calendar_view_week_rounded,
                          active: false,
                          onTap: () => context.push('/employees/week'),
                        ),
                        const SizedBox(width: 8),
                        AppFilterChip(
                          label: 'Активность и смены',
                          icon: Icons.history_toggle_off_rounded,
                          active: false,
                          onTap: () => context.push('/employees/activity'),
                        ),
                      ],
                      if (user?.isFounder ?? false) ...[
                        const SizedBox(width: 8),
                        AppFilterChip(
                          label: 'План продаж',
                          icon: Icons.flag_outlined,
                          active: false,
                          onTap: () => context.push('/employees/sales-plan'),
                        ),
                      ],
                    ],
                  ),
                ),
                AppSearchField(
                  controller: _search,
                  hint: 'Имя, должность или отдел',
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 14),
                if (snapshot?.error != null && employees.isEmpty)
                  InlineError(
                    message: snapshot!.error!,
                    onRetry: refresh,
                  )
                else if (snapshot?.error != null)
                  OfflineRibbon(cachedAt: snapshot?.savedAt, showRetry: true, onRetry: refresh),
                if (async.isLoading && snapshot == null) ...[
                  const SizedBox(height: 8),
                  for (var i = 0; i < 4; i++) ...[
                    const _EmployeeSkeleton(),
                    const SizedBox(height: 9),
                  ],
                ] else if (filtered.isEmpty) ...[
                  const SizedBox(height: 10),
                  const EmptyState(
                    icon: Icons.group_off_outlined,
                    title: 'Никого не нашли',
                    message: 'Попробуйте изменить запрос или проверьте другой отдел.',
                    compact: true,
                  ),
                ] else
                  for (final department in departments) ...[
                    const SizedBox(height: 6),
                    SectionHeader(
                      overline: 'ОТДЕЛ',
                      title: department,
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
                    ),
                    for (final employee in groups[department]!) ...[
                      _EmployeeTile(employee: employee),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 6),
                  ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  const _EmployeeTile({required this.employee});

  final EmployeeModel employee;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      radius: 18,
      onTap: () => context.push('/employees/${employee.id}'),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AppAvatar(
                name: employee.fullName,
                avatar: employee.avatar,
                size: 44,
              ),
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: employee.isActive ? context.palette.success : context.palette.textDisabled,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.palette.surface1, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        employee.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:  TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: context.palette.text,
                        ),
                      ),
                    ),
                    if (employee.isStoryMaker) ...[
                      const SizedBox(width: 5),
                       Tooltip(
                        message: 'Сторисмейкер',
                        child: Icon(Icons.auto_awesome_motion_rounded,
                            size: 13, color: context.palette.ice),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  employee.position,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:  TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 11,
                    color: context.palette.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          AppChip(
            label: UserModel.roleLabels[employee.role] ?? departmentShort(employee.department),
            tone: employee.isSubAdmin ? ChipTone.accent : ChipTone.neutral,
            compact: true,
          ),
          const SizedBox(width: 2),
           Icon(Icons.chevron_right_rounded, size: 18, color: context.palette.textTertiary),
        ],
      ),
    );
  }

  static String departmentShort(String department) =>
      department.length > 14 ? '${department.substring(0, 13)}…' : department;
}

class _EmployeeSkeleton extends StatelessWidget {
  const _EmployeeSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      padding: EdgeInsets.all(13),
      radius: 18,
      child: Row(
        children: [
          SkeletonBox(width: 44, height: 44, radius: 22),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 150, height: 12),
                SizedBox(height: 8),
                SkeletonBox(width: 100, height: 9),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
