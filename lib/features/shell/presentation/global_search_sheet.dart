import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/rbac/permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../employees/domain/employee.dart';
import '../../employees/presentation/employees_providers.dart';
import '../../projects/domain/project.dart';
import '../../projects/presentation/projects_providers.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/presentation/tasks_providers.dart';

Future<void> showGlobalSearchSheet(BuildContext context) {
  return showGlassSheet<void>(
    context: context,
    title: 'Поиск по рабочему пространству',
    subtitle: 'Проекты, задачи и сотрудники',
    child: const _GlobalSearchSheetBody(),
  );
}

class _GlobalSearchSheetBody extends ConsumerStatefulWidget {
  const _GlobalSearchSheetBody();

  @override
  ConsumerState<_GlobalSearchSheetBody> createState() =>
      _GlobalSearchSheetBodyState();
}

class _GlobalSearchSheetBodyState
    extends ConsumerState<_GlobalSearchSheetBody> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final q = _query.trim().toLowerCase();
    final palette = context.palette;

    final canProjects = canSeeProjects(user);
    final canTasks = userCan(user, Perm.tasksView);
    final canEmployees = canSeeEmployees(user);

    final projects = canProjects
        ? (ref.watch(projectsProvider).value?.data ?? const <ProjectModel>[])
        : const <ProjectModel>[];
    final tasks = canTasks
        ? (ref.watch(tasksProvider(TaskFeed.mine)).value?.data ??
            const <TaskModel>[])
        : const <TaskModel>[];
    final employees = canEmployees
        ? (ref.watch(employeesProvider).value?.data ?? const <EmployeeModel>[])
        : const <EmployeeModel>[];

    final matchedProjects = q.isEmpty
        ? projects.take(3).toList()
        : projects
            .where((p) => p.name.toLowerCase().contains(q))
            .take(5)
            .toList();
    final matchedTasks = q.isEmpty
        ? tasks.take(3).toList()
        : tasks
            .where((t) =>
                t.title.toLowerCase().contains(q) ||
                (t.projectName?.toLowerCase().contains(q) ?? false))
            .take(5)
            .toList();
    final matchedEmployees = q.isEmpty
        ? employees.take(3).toList()
        : employees
            .where((e) =>
                e.fullName.toLowerCase().contains(q) ||
                e.position.toLowerCase().contains(q))
            .take(5)
            .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSearchField(
          controller: _ctrl,
          hint: 'Введите название проекта, задачи или имя…',
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 14),
        if (matchedProjects.isEmpty &&
            matchedTasks.isEmpty &&
            matchedEmployees.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'По запросу ничего не найдено',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 13,
                color: palette.textTertiary,
              ),
            ),
          ),
        if (matchedProjects.isNotEmpty) ...[
          Text(
            'ПРОЕКТЫ',
            style: AppTypography.overline(color: palette.textTertiary),
          ),
          const SizedBox(height: 6),
          for (final p in matchedProjects)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                radius: 14,
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/projects/${p.id}');
                },
                child: Row(
                  children: [
                    Icon(
                      Icons.workspaces_outline,
                      size: 18,
                      color: palette.ice,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          color: palette.text,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: palette.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
        if (matchedTasks.isNotEmpty) ...[
          Text(
            'ЗАДАЧИ',
            style: AppTypography.overline(color: palette.textTertiary),
          ),
          const SizedBox(height: 6),
          for (final t in matchedTasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                radius: 14,
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/tasks/${t.id}');
                },
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 18,
                      color: palette.accentBright,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          color: palette.text,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: palette.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
        if (matchedEmployees.isNotEmpty) ...[
          Text(
            'СОТРУДНИКИ',
            style: AppTypography.overline(color: palette.textTertiary),
          ),
          const SizedBox(height: 6),
          for (final e in matchedEmployees)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                radius: 14,
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/employees/${e.id}');
                },
                child: Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 18,
                      color: palette.warning,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${e.fullName} · ${e.position}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          color: palette.text,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: palette.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}
