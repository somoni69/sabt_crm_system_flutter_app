import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dependencies.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_form.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../employees/presentation/employees_providers.dart';
import '../../projects/presentation/projects_providers.dart';
import '../domain/task.dart';
import 'tasks_providers.dart';

const _noProject = '__none__';
const _noAssignee = '__none__';

Future<String?> showTaskForm(
  BuildContext context,
  WidgetRef ref, {
  TaskModel? task,
  String? projectId,
  DateTime? initialDeadline,
  String initialKind = 'task',
}) async {
  final user = ref.read(currentUserProvider);
  if (user == null) return null;
  if (task == null && !canCreateTask(user)) {
    ref.read(dependenciesProvider).banners.show(const AppBanner(
          title: 'Недостаточно прав',
          message: 'Ваша роль не позволяет создавать задачи.',
          tone: BannerTone.warning,
        ));
    return null;
  }

  return showGlassSheet<String>(
    context: context,
    title: task == null ? 'Новая задача' : 'Редактировать задачу',
    subtitle: task == null
        ? 'Поставьте задачу себе, команде или проекту.'
        : 'Изменения сразу увидят участники задачи.',
    maxHeightFactor: 0.92,
    child: _TaskForm(
      task: task,
      projectId: projectId,
      initialDeadline: initialDeadline,
      initialKind: initialKind,
    ),
  );
}

class _TaskForm extends ConsumerStatefulWidget {
  const _TaskForm({
    this.task,
    this.projectId,
    this.initialDeadline,
    this.initialKind = 'task',
  });

  final TaskModel? task;
  final String? projectId;
  final DateTime? initialDeadline;
  final String initialKind;

  @override
  ConsumerState<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends ConsumerState<_TaskForm> {
  late final TextEditingController _title =
      TextEditingController(text: widget.task?.title ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.task?.description ?? '');

  late String _project;
  late String _priority;
  late String _kind;
  late String _scope;
  late String _assignee;
  late DateTime _deadline;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _project = widget.projectId ?? widget.task?.projectId ?? _noProject;
    _priority = widget.task?.priority ?? 'medium';
    _kind = widget.task?.kind ?? widget.initialKind;
    _scope = widget.task?.scope ?? 'business';
    _assignee = widget.task?.assigneeId ?? _noAssignee;
    final today = BizDate.today();
    _deadline = widget.task?.deadline ??
        widget.initialDeadline ??
        DateTime(today.year, today.month, today.day, 18, 0);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final initial = _deadline.isBefore(BizDate.now()) ? BizDate.now() : _deadline;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: BizDate.today().add(const Duration(days: 365 * 4)),
      helpText: 'Срок задачи',
      cancelText: 'Отмена',
      confirmText: 'Далее',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_deadline),
      helpText: 'Время дедлайна',
      cancelText: 'Отмена',
      confirmText: 'Готово',
    );
    if (!mounted) return;
    setState(() {
      _deadline = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _deadline.hour,
        time?.minute ?? _deadline.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Введите название задачи');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final body = <String, dynamic>{
      'title': title,
      'description': _description.text.trim(),
      'priority': _priority,
      'deadline': BizDate.toApiIso(_deadline),
      'scope': _scope,
      'kind': _kind,
      if (_project != _noProject) 'projectId': _project,
      if (_assignee != _noAssignee) 'assigneeId': _assignee,
    };

    final deps = ref.read(dependenciesProvider);
    try {
      if (widget.task == null) {
        final created = await ref.read(tasksRepositoryProvider).createTask(body);
        ref.read(dataRevisionProvider.notifier).bump();
        deps.banners.show(const AppBanner(
          title: 'Задача создана',
          message: 'Исполнитель получил уведомление.',
          tone: BannerTone.success,
          icon: Icons.check_circle_outline_rounded,
        ));
        if (mounted) Navigator.of(context).pop('${created['id'] ?? ''}');
      } else {
        await ref.read(tasksRepositoryProvider).updateTask(widget.task!.id, body);
        ref.read(dataRevisionProvider.notifier).bump();
        deps.banners.show(const AppBanner(
          title: 'Задача обновлена',
          message: 'Изменения сохранены.',
          tone: BannerTone.success,
        ));
        if (mounted) Navigator.of(context).pop(widget.task!.id);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось сохранить задачу');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(visibleProjectsProvider);
    final employees = ref.watch(assignableEmployeesProvider);
    final canAssign = employees.isNotEmpty;
    final projectIds = <String>[
      _noProject,
      ...projects.map((project) => project.id),
    ];
    final projectValue = projectIds.contains(_project) ? _project : _noProject;
    final assigneeIds = <String>[
      _noAssignee,
      ...employees.map((employee) => employee.id),
    ];
    final assigneeValue = assigneeIds.contains(_assignee) ? _assignee : _noAssignee;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_error != null) ...[
          InlineError(message: _error!, compact: true),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _title,
          enabled: !_busy,
          autofocus: widget.task == null,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          maxLength: 200,
          style:  TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: context.palette.text,
          ),
          decoration: const InputDecoration(
            hintText: 'Что нужно сделать?',
            counterText: '',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _description,
          enabled: !_busy,
          minLines: 2,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          style:  TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 14,
            height: 1.5,
            color: context.palette.text,
          ),
          decoration: const InputDecoration(
            hintText: 'Описание, ссылки, детали…',
          ),
        ),
        const FormSectionLabel('Проект'),
        AppSelectField<String>(
          value: projectValue,
          items: projectIds,
          icon: Icons.folder_outlined,
          labelOf: (id) => id == _noProject
              ? 'Без проекта'
              : projects
                  .firstWhere((project) => project.id == id,
                      orElse: () => projects.first)
                  .name,
          onChanged: (value) {
            if (value != null) setState(() => _project = value);
          },
        ),
        if (canAssign) ...[
          const FormSectionLabel('Исполнитель'),
          AppSelectField<String>(
            value: assigneeValue,
            items: assigneeIds,
            icon: Icons.person_outline_rounded,
            labelOf: (id) => id == _noAssignee
                ? 'Назначить на себя'
                : employees
                    .firstWhere((employee) => employee.id == id,
                        orElse: () => employees.first)
                    .fullName,
            onChanged: (value) {
              if (value != null) setState(() => _assignee = value);
            },
          ),
        ],
        const FormSectionLabel('Приоритет'),
        AppChoiceChips<String>(
          selected: _priority,
          onChanged: (value) => setState(() => _priority = value),
          options:  [
            AppChoice(
              value: 'low',
              label: 'Низкий',
              color: context.palette.textTertiary,
            ),
            AppChoice(
              value: 'medium',
              label: 'Средний',
              color: context.palette.info,
            ),
            AppChoice(
              value: 'high',
              label: 'Высокий',
              color: context.palette.warning,
            ),
            AppChoice(
              value: 'critical',
              label: 'Критичный',
              color: context.palette.danger,
            ),
          ],
        ),
        const FormSectionLabel('Срок'),
        AppFieldRow(
          label: 'Дедлайн',
          onTrailingTap: _busy ? null : _pickDeadline,
          trailing:  Icon(Icons.edit_calendar_outlined,
              size: 18, color: context.palette.accentBright),
          child: GestureDetector(
            onTap: _busy ? null : _pickDeadline,
            child: Row(
              children: [
                Text(
                  '${BizDate.fullDate(_deadline)} · ${BizDate.time(_deadline)}',
                  style:  TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.palette.text,
                  ),
                ),
                const SizedBox(width: 8),
                if (_deadline.isBefore(BizDate.now()))
                  const AppChip(
                    label: 'Просрочен',
                    tone: ChipTone.danger,
                    compact: true,
                  ),
              ],
            ),
          ),
        ),
        const FormSectionLabel('Тип'),
        AppChoiceChips<String>(
          selected: _kind,
          onChanged: (value) => setState(() => _kind = value),
          options:  [
            AppChoice(
              value: 'task',
              label: 'Задача',
              icon: Icons.checklist_rounded,
            ),
            AppChoice(
              value: 'meeting',
              label: 'Встреча',
              icon: Icons.videocam_outlined,
            ),
          ],
        ),
        const FormSectionLabel('Доступ'),
        AppChoiceChips<String>(
          selected: _scope,
          onChanged: (value) => setState(() => _scope = value),
          options:  [
            AppChoice(
              value: 'business',
              label: 'Рабочая',
              icon: Icons.work_outline_rounded,
            ),
            AppChoice(
              value: 'personal',
              label: 'Личная',
              icon: Icons.lock_outline_rounded,
            ),
          ],
        ),
        const SizedBox(height: 20),
        AppButton(
          label: widget.task == null ? 'Создать задачу' : 'Сохранить изменения',
          icon: Icons.check_rounded,
          loading: _busy,
          onPressed: _busy ? null : _submit,
        ),
        const SizedBox(height: 4),
         Text(
          'Исполнитель получит push-уведомление и увидит задачу в приложении.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 10,
            height: 1.35,
            color: context.palette.textDisabled,
          ),
        ),
      ],
    );
  }
}
