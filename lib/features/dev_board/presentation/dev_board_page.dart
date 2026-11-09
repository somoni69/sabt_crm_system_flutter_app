import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dependencies.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
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

class DevBoardPage extends ConsumerStatefulWidget {
  const DevBoardPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<DevBoardPage> createState() => _DevBoardPageState();
}

class _DevBoardPageState extends ConsumerState<DevBoardPage> {
  final _search = TextEditingController();
  String _query = '';
  bool _onlyMine = false;
  bool _overdueOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _createTask({String status = 'todo'}) async {
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
    if (created != true || name.isEmpty || !mounted) return;
    try {
      await ref.read(devBoardRepositoryProvider).createTask({
        'title': name,
        'status': status,
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

  Future<void> _quickAdd(String title, String status) async {
    final name = title.trim();
    if (name.isEmpty) return;
    try {
      await ref.read(devBoardRepositoryProvider).createTask({
        'title': name,
        'status': status,
        'priority': 'medium',
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

  Future<void> _setStatus(DevTask task, String status) async {
    if (task.status == status) return;
    try {
      await ref.read(devBoardRepositoryProvider).updateStatus(task.id, status);
      ref.read(dataRevisionProvider.notifier).bump();
    } catch (error) {
      ref.read(dependenciesProvider).banners.show(AppBanner(
            title: 'Ошибка обновления статуса',
            message: error.toString(),
            tone: BannerTone.danger,
          ));
    }
  }

  void _shiftStatus(DevTask task, int delta) {
    final index = DevTask.statuses.indexOf(task.status);
    if (index < 0) return;
    final next = index + delta;
    if (next < 0 || next >= DevTask.statuses.length) return;
    _setStatus(task, DevTask.statuses[next]);
  }

  void _showChangeStatusDialog(DevTask task) {
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
            onTap: () {
              Navigator.of(context).pop();
              _setStatus(task, status);
            },
          );
        }).toList(),
      ),
    );
  }

  bool _matches(DevTask task, String? userId, String userName) {
    if (_onlyMine) {
      final byId = userId != null && task.assigneeId == userId;
      final byName = task.assigneeName != null &&
          userName.isNotEmpty &&
          task.assigneeName!.toLowerCase().contains(userName.toLowerCase());
      if (!byId && !byName) return false;
    }
    if (_overdueOnly && !task.isOverdue) return false;
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return task.title.toLowerCase().contains(query) ||
        (task.projectName ?? '').toLowerCase().contains(query) ||
        (task.assigneeName ?? '').toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final canManage = isDevDirector(user) ||
        isDevLead(user) ||
        userCan(user, Perm.devTrackerManage);
    final asyncTasks = ref.watch(devBoardTasksProvider);
    final palette = context.palette;
    final bottom = widget.embedded
        ? PageInsets.bottomNav(context)
        : MediaQuery.paddingOf(context).bottom + 12;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (!widget.embedded)
                    AppIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      size: 40,
                      tooltip: 'Назад',
                      onPressed: () => context.pop(),
                    ),
                  Expanded(
                    child: Text(
                      'Доска разработки',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: palette.text,
                      ),
                    ),
                  ),
                  if (canManage)
                    AppIconButton(
                      icon: Icons.add_rounded,
                      size: 40,
                      tooltip: 'Новая задача',
                      onPressed: () => _createTask(),
                    ),
                  AppIconButton(
                    icon: Icons.refresh_rounded,
                    size: 40,
                    tooltip: 'Обновить',
                    onPressed: () =>
                        ref.read(dataRevisionProvider.notifier).bump(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AppSearchField(
                controller: _search,
                hint: 'Поиск задачи, проекта, исполнителя',
                onChanged: (value) => setState(() => _query = value),
                onClear: () => setState(() => _query = ''),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppFilterChip(
                    label: 'Только мои',
                    active: _onlyMine,
                    onTap: () => setState(() => _onlyMine = !_onlyMine),
                  ),
                  AppFilterChip(
                    label: 'Просроченные',
                    active: _overdueOnly,
                    onTap: () => setState(() => _overdueOnly = !_overdueOnly),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: asyncTasks.when(
                  // Смена статуса обновляет список через dataRevision.
                  // Это перезагрузка, а не первый заход: доску не прячем за спиннер.
                  skipLoadingOnReload: true,
                  loading: () => Center(
                    child: CircularProgressIndicator(color: palette.accent),
                  ),
                  error: (error, _) => EmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Не удалось загрузить доску',
                    message: error.toString(),
                    actionLabel: 'Повторить',
                    onAction: () =>
                        ref.read(dataRevisionProvider.notifier).bump(),
                  ),
                  data: (allTasks) {
                    final tasks = allTasks
                        .where((task) => _matches(
                              task,
                              user?.id,
                              user?.name ?? '',
                            ))
                        .toList();
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final width = math.min(
                          320.0,
                          math.max(240.0, constraints.maxWidth * 0.86),
                        );
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            height: constraints.maxHeight,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final status in DevTask.statuses) ...[
                                  SizedBox(
                                    width: width,
                                    child: _StatusColumn(
                                      status: status,
                                      tasks: tasks
                                          .where((task) => task.status == status)
                                          .toList(),
                                      canManage: canManage,
                                      bottomPadding: bottom,
                                      onOpen: (task) => context.push(
                                        '/dev-board/task/${task.id}',
                                      ),
                                      onChangeStatus: _showChangeStatusDialog,
                                      onShiftStatus: _shiftStatus,
                                      onCreate: () => _createTask(status: status),
                                      onQuickAdd: (title) =>
                                          _quickAdd(title, status),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusColumn extends StatelessWidget {
  const _StatusColumn({
    required this.status,
    required this.tasks,
    required this.canManage,
    required this.bottomPadding,
    required this.onOpen,
    required this.onChangeStatus,
    required this.onShiftStatus,
    required this.onCreate,
    required this.onQuickAdd,
  });

  final String status;
  final List<DevTask> tasks;
  final bool canManage;
  final double bottomPadding;
  final ValueChanged<DevTask> onOpen;
  final ValueChanged<DevTask> onChangeStatus;
  final void Function(DevTask task, int delta) onShiftStatus;
  final VoidCallback onCreate;
  final ValueChanged<String> onQuickAdd;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final limit = DevTask.wipLimits[status];
    final over = limit != null && tasks.length > limit;
    final count = limit == null ? '${tasks.length}' : '${tasks.length}/$limit';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.isDark
            ? const Color(0x66191C22)
            : const Color(0xB3F3F5FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 8),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    DevTask.statusLabel(status),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: palette.text,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  count,
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 12,
                    fontWeight: over ? FontWeight.w800 : FontWeight.w600,
                    color: over ? palette.danger : palette.textTertiary,
                  ),
                ),
                const Spacer(),
                if (canManage)
                  IconButton(
                    tooltip: 'Добавить в «${DevTask.statusLabel(status)}»',
                    onPressed: onCreate,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
          if (canManage)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: _QuickAdd(onSubmit: onQuickAdd),
            ),
          Expanded(
            child: tasks.isEmpty
                ? Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPadding),
                    child: Text(
                      'Задач нет',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 12,
                        color: palette.textTertiary,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(8, 0, 8, bottomPadding),
                    itemCount: tasks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return _BoardCard(
                        task: task,
                        onTap: () => onOpen(task),
                        onChangeStatus: () => onChangeStatus(task),
                        onShift: (delta) => onShiftStatus(task, delta),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _QuickAdd extends StatefulWidget {
  const _QuickAdd({required this.onSubmit});

  final ValueChanged<String> onSubmit;

  @override
  State<_QuickAdd> createState() => _QuickAddState();
}

class _QuickAddState extends State<_QuickAdd> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final title = value.trim();
    if (title.isEmpty) return;
    widget.onSubmit(title);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.done,
      onSubmitted: _submit,
      style: TextStyle(
        fontFamily: AppTypography.family,
        fontSize: 13,
        color: context.palette.text,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Новая задача…',
        filled: true,
        fillColor: context.palette.surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.palette.borderSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.palette.borderSoft),
        ),
      ),
    );
  }
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({
    required this.task,
    required this.onTap,
    required this.onChangeStatus,
    required this.onShift,
  });

  final DevTask task;
  final VoidCallback onTap;
  final VoidCallback onChangeStatus;
  final ValueChanged<int> onShift;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final index = DevTask.statuses.indexOf(task.status);
    final previous = index > 0 ? DevTask.statuses[index - 1] : null;
    final next = index >= 0 && index < DevTask.statuses.length - 1
        ? DevTask.statuses[index + 1]
        : null;
    return Material(
      color: palette.isDark ? palette.surface2 : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.border),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onChangeStatus,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 2, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: palette.text,
                        ),
                      ),
                    ),
                  ),
                  _StatusStep(
                    icon: Icons.chevron_left_rounded,
                    tooltip: previous == null
                        ? 'Первая колонка'
                        : 'В «${DevTask.statusLabel(previous)}»',
                    enabled: previous != null,
                    onPressed: previous == null ? null : () => onShift(-1),
                  ),
                  _StatusStep(
                    icon: Icons.chevron_right_rounded,
                    tooltip: next == null
                        ? 'Последняя колонка'
                        : 'В «${DevTask.statusLabel(next)}»',
                    enabled: next != null,
                    onPressed: next == null ? null : () => onShift(1),
                  ),
                ],
              ),
              if (task.projectName != null) ...[
                const SizedBox(height: 4),
                Text(
                  task.projectName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 12,
                    color: palette.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Row(
                  children: [
                    Text(
                      DevTask.priorityLabel(task.priority),
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: switch (task.priority) {
                          'urgent' || 'critical' => palette.danger,
                          'high' => palette.warning,
                          _ => palette.textTertiary,
                        },
                      ),
                    ),
                    if (task.deadline != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        BizDate.dateShort(task.deadline!),
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 11,
                          fontWeight:
                              task.isOverdue ? FontWeight.w700 : FontWeight.w500,
                          color: task.isOverdue
                              ? palette.danger
                              : palette.textTertiary,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (task.assigneeName != null)
                      AppAvatar(
                        name: task.assigneeName!,
                        avatar: task.assigneeAvatar,
                        size: 18,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusStep extends StatelessWidget {
  const _StatusStep({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return IconButton(
      tooltip: tooltip,
      onPressed: enabled ? onPressed : null,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        foregroundColor: enabled ? palette.textTertiary : palette.textDisabled,
        disabledForegroundColor: palette.textDisabled.withValues(alpha: 0.35),
        backgroundColor: Colors.transparent,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 22),
    );
  }
}
