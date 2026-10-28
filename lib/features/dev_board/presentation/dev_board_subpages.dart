import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dependencies.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/json_utils.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/dev_board_repository.dart';
import '../domain/dev_task.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 1. ПРОЕКТЫ РАЗРАБОТКИ (/dev/projects & /dev/projects/:id)
// ═══════════════════════════════════════════════════════════════════════════

const _devStageNames = <int, String>{
  10: 'Бриф и оценка',
  20: 'Прототип / ТЗ',
  30: 'Дизайн',
  40: 'Вёрстка',
  50: 'Бэкенд и логика',
  60: 'Интеграции',
  70: 'Внутренний тест',
  80: 'Демо клиенту',
  90: 'Правки и деплой',
  100: 'Сдан клиенту',
};

bool _isDevProject(Map<String, dynamic> p) {
  final type = asStringOr(p['projectType'] ?? p['type'], '').toLowerCase();
  if (type == 'smm' || type == 'target') return false;
  if (type.isNotEmpty) return true;
  return p['devStage'] != null;
}

final devProjectsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(dataRevisionProvider);
  final raw = await ref.watch(dependenciesProvider).api.getJson('/projects');
  final list = raw is List ? raw : asList(asMap(raw)?['data']);
  return list
      .map(asMap)
      .whereType<Map<String, dynamic>>()
      .where(_isDevProject)
      .toList();
});

class DevProjectsPage extends ConsumerWidget {
  const DevProjectsPage({super.key});

  Future<void> _createDevProject(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    var projectType = 'website';
    final ok = await showGlassSheet<bool>(
      context: context,
      title: 'Новый проект разработки',
      child: StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Название проекта'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in const [
                  ('website', 'Сайт'),
                  ('mobile_app', 'Мобильное приложение'),
                  ('crm', 'CRM / ERP'),
                  ('bot', 'Telegram-бот'),
                  ('design', 'Дизайн'),
                ])
                  AppFilterChip(
                    label: t.$2,
                    active: projectType == t.$1,
                    onTap: () => setState(() => projectType = t.$1),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Создать проект',
              expand: true,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (ok != true || name.isEmpty) return;
    try {
      await ref.read(dependenciesProvider).api.postJson(
        '/projects',
        body: {
          'name': name,
          'projectType': projectType,
          'devStage': 10,
        },
      );
      ref.read(dataRevisionProvider.notifier).bump();
    } on ApiException catch (e) {
      ref.read(dependenciesProvider).banners.show(
            AppBanner(
              title: 'Ошибка',
              message: e.message,
              tone: BannerTone.danger,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final canCreate = userCan(user, Perm.projectsCreate);
    final async = ref.watch(devProjectsProvider);
    final palette = context.palette;

    return AppPage(
      header: AppHeader(
        title: 'Проекты разработки',
        subtitle: 'Этапы, сроки сдачи и задачи',
        onBack: () => context.pop(),
        actions: [
          if (canCreate)
            AppIconButton(
              icon: Icons.add_rounded,
              size: 40,
              onPressed: () => _createDevProject(context, ref),
            ),
        ],
      ),
      onRefresh: () async {
        ref.read(dataRevisionProvider.notifier).bump();
        await ref.read(devProjectsProvider.future);
      },
      slivers: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: async.when(
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(vertical: 64),
              child: Center(
                child: CircularProgressIndicator(color: palette.accent),
              ),
            ),
            error: (err, _) => InlineError(
              message: err.toString(),
              onRetry: () => ref.invalidate(devProjectsProvider),
            ),
            data: (projects) {
              if (projects.isEmpty) {
                return const EmptyState(
                  icon: Icons.code_rounded,
                  title: 'Проектов разработки пока нет',
                  message: 'Создайте проект, чтобы отслеживать этапы и задачи.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final p in projects) ...[
                    _DevProjectCard(project: p),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DevProjectCard extends StatelessWidget {
  const _DevProjectCard({required this.project});

  final Map<String, dynamic> project;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final id = asStringOr(project['id'], '');
    final name = asStringOr(project['name'], 'Проект');
    final stagePct = asIntOr(project['devStage'], 0).clamp(0, 100);
    final stageLabel = _devStageNames[stagePct] ?? 'Этап не задан';
    final endDate = BizDate.parse(project['endDate']);

    return AppCard(
      padding: const EdgeInsets.all(15),
      radius: 18,
      onTap: id.isEmpty ? null : () => context.push('/dev/projects/$id'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
              ),
              AppChip(
                label: asStringOr(project['projectType'], 'Dev').toUpperCase(),
                tone: ChipTone.info,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                stagePct > 0
                    ? 'Этап ${stagePct ~/ 10} · $stageLabel'
                    : 'Этап не задан',
                style: TextStyle(
                  fontSize: 12.5,
                  color: palette.textSecondary,
                ),
              ),
              Text(
                stagePct > 0 ? '$stagePct %' : '—',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                  fontFeatures: AppTypography.tabular,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: stagePct / 100,
              minHeight: 6,
              backgroundColor: palette.surface3,
              valueColor: AlwaysStoppedAnimation<Color>(palette.accentBright),
            ),
          ),
          if (endDate != null) ...[
            const SizedBox(height: 8),
            Text(
              'Срок сдачи: ${BizDate.dateWithYear(endDate)}',
              style: TextStyle(
                fontSize: 11.5,
                color: palette.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class DevProjectDetailPage extends ConsumerStatefulWidget {
  const DevProjectDetailPage({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<DevProjectDetailPage> createState() =>
      _DevProjectDetailPageState();
}

class _DevProjectDetailPageState extends ConsumerState<DevProjectDetailPage> {
  bool _savingStage = false;

  Future<void> _setStage(int stage) async {
    if (_savingStage) return;
    setState(() => _savingStage = true);
    try {
      await ref.read(dependenciesProvider).api.patchJson(
        '/projects/${widget.projectId}/dev-stage',
        body: {'devStage': stage},
      );
      ref.read(dataRevisionProvider.notifier).bump();
    } on ApiException catch (e) {
      ref.read(dependenciesProvider).banners.show(
            AppBanner(
              title: 'Ошибка',
              message: e.message,
              tone: BannerTone.danger,
            ),
          );
    } finally {
      if (mounted) setState(() => _savingStage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncProject = ref.watch(_singleDevProjectProvider(widget.projectId));
    final asyncTasks = ref.watch(_projectDevTasksProvider(widget.projectId));
    final palette = context.palette;

    return AppPage(
      header: AppHeader(
        title: asyncProject.value?['name']?.toString() ?? 'Проект разработки',
        subtitle: 'Этап и задачи проекта',
        onBack: () => context.pop(),
      ),
      onRefresh: () async {
        ref.read(dataRevisionProvider.notifier).bump();
      },
      slivers: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: asyncProject.when(
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(vertical: 64),
              child: Center(
                child: CircularProgressIndicator(color: palette.accent),
              ),
            ),
            error: (err, _) => InlineError(
              message: err.toString(),
              onRetry: () =>
                  ref.invalidate(_singleDevProjectProvider(widget.projectId)),
            ),
            data: (project) {
              final stagePct = asIntOr(project['devStage'], 10);
              final tasks = asyncTasks.value ?? const <DevTask>[];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(15),
                    radius: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ЭТАП РАЗРАБОТКИ ($stagePct %)',
                          style: AppTypography.overline(
                            color: palette.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _devStageNames[stagePct] ?? 'Этап $stagePct%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: palette.text,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final st in _devStageNames.keys)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: AppFilterChip(
                                    label: '$st%',
                                    active: stagePct == st,
                                    onTap: _savingStage
                                        ? () {}
                                        : () => _setStage(st),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SectionHeader(
                    overline: 'ДОСКА РАЗРАБОТКИ',
                    title: 'Задачи проекта (${tasks.length})',
                    actionLabel: 'Вся доска',
                    onAction: () => context.push('/dev-board'),
                  ),
                  if (tasks.isEmpty)
                    const EmptyState(
                      icon: Icons.task_alt_rounded,
                      title: 'Задач по проекту пока нет',
                      message: 'Создайте задачу на доске разработки.',
                      compact: true,
                    )
                  else
                    for (final t in tasks) ...[
                      AppCard(
                        padding: const EdgeInsets.all(13),
                        radius: 16,
                        onTap: () => context.push('/dev-board/task/${t.id}'),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                      color: palette.text,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    DevTask.statusLabel(t.status),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: palette.textTertiary,
                                    ),
                                  ),
                                ],
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
                      const SizedBox(height: 8),
                    ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

final _singleDevProjectProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
  ref.watch(dataRevisionProvider);
  final raw = await ref.watch(dependenciesProvider).api.getJson('/projects/$id');
  return asMap(raw) ?? const <String, dynamic>{};
});

final _projectDevTasksProvider =
    FutureProvider.autoDispose.family<List<DevTask>, String>((ref, id) async {
  ref.watch(dataRevisionProvider);
  return ref.watch(devBoardRepositoryProvider).getTasks(projectId: id);
});

// ═══════════════════════════════════════════════════════════════════════════
// 2. ДЕТАЛЬНАЯ КАРТОЧКА ЗАДАЧИ РАЗРАБОТКИ (/dev-board/task/:id)
// ═══════════════════════════════════════════════════════════════════════════

final devTaskDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
  ref.watch(dataRevisionProvider);
  final raw =
      await ref.watch(dependenciesProvider).api.getJson('/dev-tracker/$id');
  return asMap(raw) ?? const <String, dynamic>{};
});

class DevTaskDetailPage extends ConsumerStatefulWidget {
  const DevTaskDetailPage({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<DevTaskDetailPage> createState() => _DevTaskDetailPageState();
}

class _DevTaskDetailPageState extends ConsumerState<DevTaskDetailPage> {
  final _commentCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _patchTask(Map<String, dynamic> body) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(dependenciesProvider)
          .api
          .patchJson('/dev-tracker/${widget.taskId}', body: body);
      ref.invalidate(devTaskDetailProvider(widget.taskId));
      ref.read(dataRevisionProvider.notifier).bump();
    } on ApiException catch (e) {
      ref.read(dependenciesProvider).banners.show(
            AppBanner(
              title: 'Ошибка',
              message: e.message,
              tone: BannerTone.danger,
            ),
          );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeStatus(String status) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(devBoardRepositoryProvider)
          .updateStatus(widget.taskId, status);
      ref.invalidate(devTaskDetailProvider(widget.taskId));
      ref.read(dataRevisionProvider.notifier).bump();
    } on ApiException catch (e) {
      ref.read(dependenciesProvider).banners.show(
            AppBanner(
              title: 'Ошибка',
              message: e.message,
              tone: BannerTone.danger,
            ),
          );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(dependenciesProvider).api.postJson(
        '/dev-tracker/${widget.taskId}/comments',
        body: {'text': text},
      );
      _commentCtrl.clear();
      ref.invalidate(devTaskDetailProvider(widget.taskId));
    } on ApiException catch (e) {
      ref.read(dependenciesProvider).banners.show(
            AppBanner(
              title: 'Комментарий не отправлен',
              message: e.message,
              tone: BannerTone.danger,
            ),
          );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cloneTask() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(dependenciesProvider)
          .api
          .postJson('/dev-tracker/${widget.taskId}/clone', body: {});
      ref.read(dataRevisionProvider.notifier).bump();
      ref.read(dependenciesProvider).banners.show(
            const AppBanner(
              title: 'Задача скопирована',
              message: 'Копия создана на доске разработки.',
              tone: BannerTone.success,
            ),
          );
    } on ApiException catch (e) {
      ref.read(dependenciesProvider).banners.show(
            AppBanner(
              title: 'Ошибка клонирования',
              message: e.message,
              tone: BannerTone.danger,
            ),
          );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteTask() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(dependenciesProvider)
          .api
          .deleteJson('/dev-tracker/${widget.taskId}');
      ref.read(dataRevisionProvider.notifier).bump();
      if (mounted) context.pop();
    } on ApiException catch (e) {
      ref.read(dependenciesProvider).banners.show(
            AppBanner(
              title: 'Ошибка удаления',
              message: e.message,
              tone: BannerTone.danger,
            ),
          );
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(devTaskDetailProvider(widget.taskId));
    final palette = context.palette;

    return AppPage(
      header: AppHeader(
        title: 'Задача разработки',
        subtitle: 'Карточка трекера',
        onBack: () => context.pop(),
        actions: [
          AppIconButton(
            icon: Icons.copy_rounded,
            size: 38,
            tooltip: 'Клонировать',
            onPressed: _busy ? null : _cloneTask,
          ),
          const SizedBox(width: 6),
          AppIconButton(
            icon: Icons.delete_outline_rounded,
            size: 38,
            tooltip: 'Удалить',
            onPressed: _busy ? null : _deleteTask,
          ),
        ],
      ),
      onRefresh: () async {
        ref.invalidate(devTaskDetailProvider(widget.taskId));
      },
      slivers: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: async.when(
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(vertical: 64),
              child: Center(
                child: CircularProgressIndicator(color: palette.accent),
              ),
            ),
            error: (err, _) => InlineError(
              message: err.toString(),
              onRetry: () => ref.invalidate(devTaskDetailProvider(widget.taskId)),
            ),
            data: (data) {
              final title = asStringOr(data['title'], 'Без названия');
              final description = asStringOr(data['description'], '');
              final status = asStringOr(data['status'], 'todo');
              final priority = asStringOr(data['priority'], 'medium');
              final isBlocked = asBool(data['isBlocked']);
              final blockedReason = asString(data['blockedReason']);
              final assignee = asMap(data['assignee'] ?? data['user']);
              final project = asMap(data['project']);
              final subtasks = asList(data['subtasks'])
                  .map(asMap)
                  .whereType<Map<String, dynamic>>()
                  .toList();
              final comments = asList(data['comments'])
                  .map(asMap)
                  .whereType<Map<String, dynamic>>()
                  .toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    radius: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AppChip(
                              label: DevTask.typeLabel(
                                asStringOr(
                                  data['taskType'] ?? data['type'],
                                  'task',
                                ),
                              ),
                              tone: ChipTone.info,
                              compact: true,
                            ),
                            if (isBlocked) ...[
                              const SizedBox(width: 6),
                              const AppChip(
                                label: 'Заблокировано',
                                tone: ChipTone.danger,
                                compact: true,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: palette.text,
                          ),
                        ),
                        if (isBlocked &&
                            blockedReason != null &&
                            blockedReason.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Причина блокера: $blockedReason',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: palette.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final st in DevTask.statuses)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: AppFilterChip(
                                    label: DevTask.statusLabel(st),
                                    active: status == st,
                                    onTap: () => _changeStatus(st),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Divider(height: 1, color: palette.borderSoft),
                        KeyValueRow(
                          label: 'Исполнитель',
                          value: asStringOr(assignee?['name'], 'Не назначен'),
                          icon: Icons.person_outline_rounded,
                        ),
                        Divider(height: 1, color: palette.borderSoft),
                        KeyValueRow(
                          label: 'Проект',
                          value: asStringOr(project?['name'], 'Без проекта'),
                          icon: Icons.workspaces_outline,
                        ),
                        Divider(height: 1, color: palette.borderSoft),
                        KeyValueRow(
                          label: 'Приоритет',
                          value: priority.toUpperCase(),
                          icon: Icons.flag_outlined,
                        ),
                        const SizedBox(height: 8),
                        AppButton(
                          label: isBlocked
                              ? 'Снять блокер'
                              : 'Отметить как заблокированную',
                          variant: ButtonVariant.ghost,
                          compact: true,
                          onPressed: () =>
                              _patchTask({'isBlocked': !isBlocked}),
                        ),
                      ],
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const SectionHeader(
                      overline: 'ОПИСАНИЕ',
                      title: 'Детали задачи',
                    ),
                    AppCard(
                      padding: const EdgeInsets.all(15),
                      radius: 18,
                      child: Text(
                        description,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                  ],
                  if (subtasks.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SectionHeader(
                      overline: 'ПОДЗАДАЧИ',
                      title: 'Чеклист (${subtasks.length})',
                    ),
                    for (final sub in subtasks) ...[
                      AppCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 10,
                        ),
                        radius: 14,
                        onTap: () => context.push(
                          '/dev-board/task/${asStringOr(sub['id'], '')}',
                        ),
                        child: Row(
                          children: [
                            Icon(
                              sub['status'] == 'done'
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 18,
                              color: sub['status'] == 'done'
                                  ? palette.success
                                  : palette.textTertiary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                asStringOr(sub['title'], 'Подзадача'),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: palette.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ],
                  const SizedBox(height: 16),
                  SectionHeader(
                    overline: 'ОБСУЖДЕНИЕ',
                    title: 'Комментарии (${comments.length})',
                  ),
                  for (final c in comments) ...[
                    AppCard(
                      padding: const EdgeInsets.all(13),
                      radius: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              AppAvatar(
                                name: asStringOr(
                                  asMap(c['author'] ?? c['user'])?['name'],
                                  'Сотрудник',
                                ),
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  asStringOr(
                                    asMap(c['author'] ?? c['user'])?['name'],
                                    'Сотрудник',
                                  ),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                    color: palette.text,
                                  ),
                                ),
                              ),
                              Text(
                                switch (BizDate.parse(c['createdAt'])) {
                                  final dt? => BizDate.relative(dt),
                                  null => '',
                                },
                                style: TextStyle(
                                  fontSize: 11,
                                  color: palette.textTertiary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            asStringOr(c['text'] ?? c['message'], ''),
                            style: TextStyle(
                              fontSize: 13,
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  AppCard(
                    padding: const EdgeInsets.all(12),
                    radius: 16,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Написать комментарий…',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AppButton(
                          label: 'Отправить',
                          icon: Icons.send_rounded,
                          compact: true,
                          busy: _busy,
                          onPressed: _sendComment,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 3. KPI РАЗРАБОТКИ (/dev-board/kpi)
// ═══════════════════════════════════════════════════════════════════════════

final devBoardKpiProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(dataRevisionProvider);
  final raw =
      await ref.watch(dependenciesProvider).api.getJson('/dev-tracker/kpi');
  return asMap(raw) ?? const <String, dynamic>{};
});

class DevBoardKpiPage extends ConsumerWidget {
  const DevBoardKpiPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(devBoardKpiProvider);
    final palette = context.palette;

    return AppPage(
      header: AppHeader(
        title: 'KPI разработки',
        subtitle: 'Эффективность и соблюдение сроков',
        onBack: () => context.pop(),
        actions: [
          AppIconButton(
            icon: Icons.refresh_rounded,
            size: 40,
            onPressed: () => ref.invalidate(devBoardKpiProvider),
          ),
        ],
      ),
      onRefresh: () async {
        ref.invalidate(devBoardKpiProvider);
        await ref.read(devBoardKpiProvider.future);
      },
      slivers: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: async.when(
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(vertical: 64),
              child: Center(
                child: CircularProgressIndicator(color: palette.accent),
              ),
            ),
            error: (err, _) => InlineError(
              message: err.toString(),
              onRetry: () => ref.invalidate(devBoardKpiProvider),
            ),
            data: (data) {
              final team = asMap(data['team']) ?? const <String, dynamic>{};
              final members = asList(data['members'])
                  .map(asMap)
                  .whereType<Map<String, dynamic>>()
                  .toList();

              final total = asIntOr(team['total'], 0);
              final done = asIntOr(team['done'], 0);
              final inProgress = asIntOr(team['inProgress'], 0);
              final overdue = asIntOr(team['overdue'], 0);
              final onTimeRate = asInt(team['onTimeRate']);
              final avgCycle = asDouble(team['avgCycleDays']);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _DevStatCard(
                          label: 'Всего задач',
                          value: '$total',
                          sub: 'в работе: $inProgress',
                          color: palette.accentBright,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DevStatCard(
                          label: 'Завершено',
                          value: '$done',
                          sub: onTimeRate != null
                              ? 'в срок: $onTimeRate %'
                              : 'нет с дедлайном',
                          color: palette.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _DevStatCard(
                          label: 'Просрочено',
                          value: '$overdue',
                          sub: 'открытых с долгом',
                          color:
                              overdue > 0 ? palette.danger : palette.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DevStatCard(
                          label: 'Средний цикл',
                          value: avgCycle == null
                              ? '—'
                              : '${avgCycle.toStringAsFixed(1)} дн.',
                          sub: 'от старта до Готово',
                          color: palette.info,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const SectionHeader(
                    overline: 'КОМАНДА РАЗРАБОТКИ',
                    title: 'Показатели по участникам',
                  ),
                  if (members.isEmpty)
                    const EmptyState(
                      icon: Icons.groups_outlined,
                      title: 'Данных по участникам пока нет',
                      message: 'Назначьте задачи разработчикам на доске.',
                      compact: true,
                    )
                  else
                    for (final m in members) ...[
                      AppCard(
                        padding: const EdgeInsets.all(14),
                        radius: 16,
                        child: Row(
                          children: [
                            AppAvatar(
                              name: asStringOr(m['name'], 'Разработчик'),
                              avatar: asString(m['avatarUrl']),
                              size: 38,
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    asStringOr(m['name'], 'Разработчик'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                      color: palette.text,
                                    ),
                                  ),
                                  Text(
                                    'Готово: ${asIntOr(m['done'], 0)} из ${asIntOr(m['total'], 0)}'
                                    '${asIntOr(m['overdue'], 0) > 0 ? ' · просрочено ${asIntOr(m['overdue'], 0)}' : ''}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: palette.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AppChip(
                              label: asInt(m['onTimeRate']) != null
                                  ? '${asInt(m['onTimeRate'])} % в срок'
                                  : '—',
                              tone: (asInt(m['onTimeRate']) ?? 0) >= 80
                                  ? ChipTone.success
                                  : (asInt(m['onTimeRate']) ?? 0) >= 60
                                      ? ChipTone.warning
                                      : ChipTone.neutral,
                              compact: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DevStatCard extends StatelessWidget {
  const _DevStatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  final String label;
  final String value;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      padding: const EdgeInsets.all(14),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.overline(color: palette.textTertiary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: AppTypography.tabular,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(
              fontSize: 11.5,
              color: palette.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 4. ОТЧЁТЫ РАЗРАБОТКИ (/dev-board/reports)
// ═══════════════════════════════════════════════════════════════════════════

class DevBoardReportsPage extends ConsumerStatefulWidget {
  const DevBoardReportsPage({super.key});

  @override
  ConsumerState<DevBoardReportsPage> createState() =>
      _DevBoardReportsPageState();
}

class _DevBoardReportsPageState extends ConsumerState<DevBoardReportsPage> {
  String _days = '7';
  bool _loading = false;
  Map<String, dynamic>? _report;

  Future<void> _generate() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final raw = await ref.read(dependenciesProvider).api.getJson(
        '/dev-tracker/reports',
        query: {'type': 'week', 'days': int.tryParse(_days) ?? 7},
      );
      if (mounted) {
        setState(() => _report = asMap(raw) ?? const <String, dynamic>{});
      }
    } on ApiException catch (e) {
      ref.read(dependenciesProvider).banners.show(
            AppBanner(
              title: 'Отчёт недоступен',
              message: e.message,
              tone: BannerTone.warning,
            ),
          );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyMarkdown(String markdown) async {
    if (markdown.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: markdown));
    ref.read(dependenciesProvider).banners.show(
          const AppBanner(
            title: 'Скопировано',
            message: 'Markdown-отчёт скопирован в буфер обмена.',
            tone: BannerTone.success,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final stats = asMap(_report?['stats']) ?? const <String, dynamic>{};
    final blockers = asList(_report?['blockers'])
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .toList();
    final markdown = asStringOr(_report?['markdown'], '');

    return AppPage(
      header: AppHeader(
        title: 'Отчёты разработки',
        subtitle: 'Сводка для руководства',
        onBack: () => context.pop(),
      ),
      slivers: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                padding: const EdgeInsets.all(15),
                radius: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'ПЕРИОД ОТЧЁТА',
                      style: AppTypography.overline(
                        color: palette.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (final d in const [
                          ('7', '7 дней'),
                          ('14', '14 дней'),
                          ('30', '30 дней'),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: AppFilterChip(
                              label: d.$2,
                              active: _days == d.$1,
                              onTap: () => setState(() => _days = d.$1),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    AppButton(
                      label: 'Сформировать отчёт',
                      icon: Icons.analytics_outlined,
                      busy: _loading,
                      expand: true,
                      onPressed: _generate,
                    ),
                  ],
                ),
              ),
              if (_report != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _DevStatCard(
                        label: 'Создано',
                        value: '${asIntOr(stats['created'], 0)}',
                        sub: 'открыто: ${asIntOr(stats['open'], 0)}',
                        color: palette.accentBright,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DevStatCard(
                        label: 'Выполнено',
                        value: '${asIntOr(stats['done'], 0)}',
                        sub: 'в срок: ${asIntOr(stats['doneOnTime'], 0)}',
                        color: palette.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _DevStatCard(
                        label: 'Просрочено',
                        value: '${asIntOr(stats['overdue'], 0)}',
                        sub: 'требуют внимания',
                        color: palette.danger,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DevStatCard(
                        label: 'Блокеры',
                        value: '${asIntOr(stats['blocked'], 0)}',
                        sub: 'остановлены',
                        color: palette.warning,
                      ),
                    ),
                  ],
                ),
                if (blockers.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const SectionHeader(
                    overline: 'БЛОКЕРЫ',
                    title: 'Заблокированные задачи',
                  ),
                  for (final b in blockers) ...[
                    AppCard(
                      padding: const EdgeInsets.all(13),
                      radius: 16,
                      onTap: () => context.push(
                        '/dev-board/task/${asStringOr(b['id'], '')}',
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            asStringOr(b['title'], 'Задача'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: palette.text,
                            ),
                          ),
                          if (b['reason'] != null)
                            Text(
                              'Причина: ${b['reason']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.danger,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
                if (markdown.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SectionHeader(
                    overline: 'ТЕКСТ ОТЧЁТА',
                    title: 'Markdown-сводка',
                    actionLabel: 'Копировать',
                    onAction: () => _copyMarkdown(markdown),
                  ),
                  AppCard(
                    padding: const EdgeInsets.all(14),
                    radius: 16,
                    child: Text(
                      markdown,
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontFeatures: AppTypography.tabular,
                        fontSize: 12,
                        height: 1.45,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
