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
import '../domain/smm_models.dart';
import 'smm_providers.dart';

const _noAssignee = '__none__';

Future<void> showContentForm(
  BuildContext context,
  WidgetRef ref, {
  SmmProject? project,
  DateTime? date,
  SmmEvent? event,
}) async {
  final user = ref.read(currentUserProvider);
  if (user == null || isSmmViewOnly(user) || !canSeeSmmSection(user)) return;

  await showGlassSheet<void>(
    context: context,
    title: event == null ? 'Контент в план' : 'Редактировать контент',
    subtitle: event == null
        ? 'Запланируйте публикацию или макет на нужный день.'
        : 'Изменения появятся в SMM-календаре команды.',
    maxHeightFactor: 0.92,
    child: _ContentForm(project: project, date: date, event: event),
  );
}

class _ContentForm extends ConsumerStatefulWidget {
  const _ContentForm({this.project, this.date, this.event});

  final SmmProject? project;
  final DateTime? date;
  final SmmEvent? event;

  @override
  ConsumerState<_ContentForm> createState() => _ContentFormState();
}

class _ContentFormState extends ConsumerState<_ContentForm> {
  late final TextEditingController _topic =
      TextEditingController(text: widget.event?.topic ?? '');
  late final TextEditingController _script =
      TextEditingController(text: widget.event?.scriptText ?? '');
  late final TextEditingController _caption = TextEditingController();

  String? _projectId;
  late String _type = widget.event?.contentType ?? 'reel';
  late DateTime _date = widget.event?.date ?? widget.date ?? BizDate.today();
  late String _status = widget.event?.status ?? 'planned';
  String? _time;
  String _assignee = _noAssignee;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _projectId = widget.project?.id ?? widget.event?.projectId;
    _assignee = widget.event?.assigneeId ?? _noAssignee;
    _time = widget.event?.time;
  }

  @override
  void dispose() {
    _topic.dispose();
    _script.dispose();
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: BizDate.today().add(const Duration(days: 365 * 3)),
      helpText: 'Дата публикации',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );
    if (value != null && mounted) setState(() => _date = value);
  }

  Future<void> _pickTime() async {
    final current = _time == null
        ? const TimeOfDay(hour: 18, minute: 0)
        : TimeOfDay(
            hour: int.tryParse(_time!.split(':').first) ?? 18,
            minute: int.tryParse(_time!.split(':').last) ?? 0,
          );
    final value = await showTimePicker(
      context: context,
      initialTime: current,
      helpText: 'Время публикации',
      cancelText: 'Отмена',
      confirmText: 'Готово',
    );
    if (value != null && mounted) {
      setState(() {
        _time =
            '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _submit(List<SmmProject> projects) async {
    if (_busy) return;
    final topic = _topic.text.trim();
    if (topic.isEmpty) {
      setState(() => _error = 'Введите тему публикации');
      return;
    }
    final projectId = _projectId;
    if (projectId == null || projectId.isEmpty) {
      setState(() => _error = 'Выберите проект');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final repo = ref.read(smmRepositoryProvider);
    final deps = ref.read(dependenciesProvider);
    try {
      if (widget.event?.itemId == null) {
        await repo.createContentItem(
          projectId: projectId,
          contentType: _type,
          topic: topic,
          publishDate: _date,
          publishTime: _time,
          assigneeId: _assignee == _noAssignee ? null : _assignee,
          scriptText: _script.text.trim(),
          caption: _caption.text.trim(),
        );
        deps.banners.show(const AppBanner(
          title: 'Добавлено в контент-план',
          message: 'Позиция появилась в календаре.',
          tone: BannerTone.success,
          icon: Icons.check_circle_outline_rounded,
        ));
      } else {
        await repo.updateContentItem(widget.event!.itemId!, {
          'contentType': _type,
          'topic': topic,
          'publishDate': BizDate.toApiDate(_date),
          if (_assignee != _noAssignee) 'assigneeId': _assignee,
          'scriptText': _script.text.trim(),
          'caption': _caption.text.trim(),
          'status': _status,
        });
        await repo.updateSmartItem(
          widget.event!.itemId!,
          date: _date,
          time: _time ?? '',
          status: _status,
        );
        deps.banners.show(const AppBanner(
          title: 'Контент обновлён',
          message: 'Календарь и карточка синхронизированы.',
          tone: BannerTone.success,
        ));
      }
      ref.read(dataRevisionProvider.notifier).bump();
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось сохранить контент');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(smmProjectsProvider);
    final employees = ref.watch(assignableEmployeesProvider);
    if (_projectId == null && projects.isNotEmpty) {
      _projectId = projects.first.id;
    }
    final assigneeValue = _assignee == _noAssignee ||
            employees.any((employee) => employee.id == _assignee)
        ? _assignee
        : _noAssignee;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_error != null) ...[
          InlineError(message: _error!, compact: true),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _topic,
          enabled: !_busy,
          autofocus: widget.event == null,
          maxLength: 300,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
          decoration: const InputDecoration(
            hintText: 'Тема публикации',
            counterText: '',
          ),
        ),
        const FormSectionLabel('Проект'),
        if (projects.isEmpty)
          const InlineError(
            message: 'Нет доступных SMM-проектов для планирования.',
            compact: true,
          )
        else
          AppSelectField<String>(
            value: projects.any((project) => project.id == _projectId)
                ? _projectId
                : projects.first.id,
            items: projects.map((project) => project.id).toList(),
            icon: Icons.folder_outlined,
            labelOf: (id) => projects
                .firstWhere((project) => project.id == id,
                    orElse: () => projects.first)
                .name,
            onChanged: (value) {
              if (value != null) setState(() => _projectId = value);
            },
          ),
        const FormSectionLabel('Формат'),
        AppChoiceChips<String>(
          selected: _type,
          onChanged: (value) => setState(() => _type = value),
          options: const [
            AppChoice(
              value: 'reel',
              label: 'Рилс',
              icon: Icons.movie_outlined,
            ),
            AppChoice(
              value: 'post',
              label: 'Пост',
              icon: Icons.grid_view_rounded,
              color: AppColors.info,
            ),
            AppChoice(
              value: 'design',
              label: 'Макет',
              icon: Icons.brush_outlined,
              color: AppColors.ice,
            ),
          ],
        ),
        const FormSectionLabel('Дата публикации'),
        AppFieldRow(
          label: 'Дата',
          onTrailingTap: _busy ? null : _pickDate,
          trailing: const Icon(Icons.edit_calendar_outlined,
              size: 18, color: AppColors.accentBright),
          child: GestureDetector(
            onTap: _busy ? null : _pickDate,
            child: Text(
              BizDate.fullDate(_date),
              style: const TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        AppFieldRow(
          label: 'Время',
          onTrailingTap: _busy
              ? null
              : () {
                  setState(() => _time = null);
                },
          trailing: _time == null
              ? const Icon(Icons.schedule_rounded,
                  size: 18, color: AppColors.accentBright)
              : const Icon(Icons.close_rounded,
                  size: 17, color: AppColors.textTertiary),
          child: GestureDetector(
            onTap: _busy ? null : _pickTime,
            child: Text(
              _time ?? 'Весь день',
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: _time == null ? AppColors.textTertiary : AppColors.text,
              ),
            ),
          ),
        ),
        if (widget.event != null) ...[
          const FormSectionLabel('Статус'),
          AppSelectField<String>(
            value: _status,
            items: const [
              'planned',
              'preparing',
              'in_production',
              'on_review',
              'on_approval',
              'approved',
              'published',
              'cancelled',
            ],
            labelOf: _statusLabel,
            onChanged: (value) {
              if (value != null) setState(() => _status = value);
            },
          ),
        ],
        if (employees.isNotEmpty) ...[
          const FormSectionLabel('Ответственный'),
          AppSelectField<String>(
            value: assigneeValue,
            items: [_noAssignee, ...employees.map((employee) => employee.id)],
            icon: Icons.person_outline_rounded,
            labelOf: (id) => id == _noAssignee
                ? 'Не назначен'
                : employees
                    .firstWhere((employee) => employee.id == id,
                        orElse: () => employees.first)
                    .fullName,
            onChanged: (value) {
              if (value != null) setState(() => _assignee = value);
            },
          ),
        ],
        const FormSectionLabel('Сценарий'),
        TextField(
          controller: _script,
          enabled: !_busy,
          minLines: 2,
          maxLines: 5,
          maxLength: 10000,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 13.5,
            height: 1.5,
            color: AppColors.text,
          ),
          decoration: const InputDecoration(
            hintText: 'Хук, сцены, CTA…',
            counterText: '',
          ),
        ),
        const FormSectionLabel('Подпись'),
        TextField(
          controller: _caption,
          enabled: !_busy,
          minLines: 1,
          maxLines: 3,
          maxLength: 5000,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 13.5,
            height: 1.5,
            color: AppColors.text,
          ),
          decoration: const InputDecoration(
            hintText: 'Текст публикации',
            counterText: '',
          ),
        ),
        const SizedBox(height: 20),
        AppButton(
          label: widget.event == null ? 'Добавить в план' : 'Сохранить',
          icon: Icons.check_rounded,
          loading: _busy,
          onPressed: _busy ? null : () => _submit(projects),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  static String _statusLabel(String status) => switch (status) {
        'planned' => 'Запланировано',
        'preparing' => 'Готовится',
        'in_production' => 'В производстве',
        'on_review' => 'На проверке',
        'on_approval' => 'На согласовании',
        'approved' => 'Согласовано',
        'published' => 'Опубликовано',
        'cancelled' => 'Отменено',
        _ => status,
      };
}
