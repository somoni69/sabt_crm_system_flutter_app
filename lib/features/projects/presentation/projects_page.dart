import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dependencies.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/project.dart';
import 'projects_providers.dart';

enum _ProjectFilter { active, inProgress, planning, completed, archived }

class ProjectsPage extends ConsumerStatefulWidget {
  const ProjectsPage({
    super.key,
    this.embedded = true,
    this.standalone = false,
  });

  final bool embedded;
  final bool standalone;

  @override
  ConsumerState<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends ConsumerState<ProjectsPage> {
  final _search = TextEditingController();
  _ProjectFilter _filter = _ProjectFilter.active;
  bool _searchOpen = false;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(ProjectModel project) {
    switch (_filter) {
      case _ProjectFilter.active:
        if (project.isArchived) return false;
        break;
      case _ProjectFilter.inProgress:
        if (project.status != 'in_progress' || project.isArchived) return false;
        break;
      case _ProjectFilter.planning:
        if (project.status != 'planning' || project.isArchived) return false;
        break;
      case _ProjectFilter.completed:
        if (project.status != 'completed' || project.isArchived) return false;
        break;
      case _ProjectFilter.archived:
        if (!project.isArchived) return false;
        break;
    }
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return project.name.toLowerCase().contains(query) ||
        project.projectType.toLowerCase().contains(query) ||
        (project.manager?.name ?? '').toLowerCase().contains(query);
  }

  Future<void> _createProject(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var projectType = 'SMM';
    final ok = await showGlassSheet<bool>(
      context: context,
      title: 'Новый проект',
      subtitle: 'Добавьте проект в портфель агентства',
      child: StatefulBuilder(
        builder: (context, setModalState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Название проекта'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descCtrl,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Описание (необязательно)',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in const [
                  'SMM',
                  'Таргет',
                  'Сайт',
                  'Мобильное приложение',
                  'CRM система',
                  'Телеграм бот',
                ])
                  AppFilterChip(
                    label: t,
                    active: projectType == t,
                    onTap: () => setModalState(() => projectType = t),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Создать проект',
              icon: Icons.check_rounded,
              expand: true,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
    final name = nameCtrl.text.trim();
    final desc = descCtrl.text.trim();
    nameCtrl.dispose();
    descCtrl.dispose();
    if (ok != true || name.isEmpty) return;
    try {
      await ref.read(dependenciesProvider).api.postJson(
        '/projects',
        body: {
          'name': name,
          'projectType': projectType,
          if (desc.isNotEmpty) 'description': desc,
        },
      );
      ref.read(dataRevisionProvider.notifier).bump();
      ref.read(dependenciesProvider).banners.show(const AppBanner(
            title: 'Проект создан',
            message: 'Новый проект добавлен в список.',
            tone: BannerTone.success,
          ));
    } on ApiException catch (e) {
      ref.read(dependenciesProvider).banners.show(AppBanner(
            title: 'Ошибка создания проекта',
            message: e.message,
            tone: BannerTone.danger,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final canSee = canSeeProjects(user);
    final canCreate = canCreateProject(user);
    final async = ref.watch(projectsProvider);
    final snapshot = async.value;
    final all = snapshot?.data ?? const <ProjectModel>[];
    final projects = all.where(_matches).toList();
    final active = all.where((project) => !project.isArchived).length;
    final inProgress =
        all.where((project) => project.status == 'in_progress').length;
    final planning =
        all.where((project) => project.status == 'planning').length;
    final completed =
        all.where((project) => project.status == 'completed').length;
    final archived = all.where((project) => project.isArchived).length;

    final error = async.error;
    final errorMessage =
        error is ApiException ? error.message : 'Не удалось загрузить проекты';

    Future<void> refresh() async {
      ref.read(dataRevisionProvider.notifier).bump();
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }

    return AppPage(
      showBottomBarSpace: widget.embedded,
      header: AppHeader(
        title: 'Проекты',
        subtitle: all.isEmpty
            ? 'Портфель агентства'
            : '$active активных · $inProgress в работе',
        onBack: widget.standalone ? () => context.pop() : null,
        actions: [
          if (canCreate)
            AppIconButton(
              icon: Icons.add_rounded,
              size: 40,
              tooltip: 'Новый проект',
              onPressed: () => _createProject(context),
            ),
          AppIconButton(
            icon: _searchOpen ? Icons.close_rounded : Icons.search_rounded,
            size: 40,
            onPressed: () {
              setState(() {
                _searchOpen = !_searchOpen;
                if (!_searchOpen) {
                  _search.clear();
                  _query = '';
                }
              });
            },
          ),
        ],
      ),
      onRefresh: canSee ? refresh : null,
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.embedded) ...[
                const PageIntro(
                  overline: 'ПОРТФЕЛЬ',
                  title: 'Проекты',
                  subtitle: 'Прогресс, команда и нормы по каждому клиенту.',
                ),
              ],
              if (!canSee)
                const EmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: 'Раздел недоступен',
                  message: 'У вашей роли нет доступа к проектам.',
                )
              else ...[
                if (_searchOpen) ...[
                  AppSearchField(
                    controller: _search,
                    hint: 'Название, тип или менеджер',
                    autofocus: true,
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 12),
                ],
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      AppFilterChip(
                        label: 'Активные',
                        count: active,
                        active: _filter == _ProjectFilter.active,
                        onTap: () =>
                            setState(() => _filter = _ProjectFilter.active),
                      ),
                      const SizedBox(width: 7),
                      AppFilterChip(
                        label: 'В работе',
                        count: inProgress,
                        active: _filter == _ProjectFilter.inProgress,
                        onTap: () =>
                            setState(() => _filter = _ProjectFilter.inProgress),
                      ),
                      const SizedBox(width: 7),
                      AppFilterChip(
                        label: 'Планирование',
                        count: planning,
                        active: _filter == _ProjectFilter.planning,
                        onTap: () =>
                            setState(() => _filter = _ProjectFilter.planning),
                      ),
                      const SizedBox(width: 7),
                      AppFilterChip(
                        label: 'Завершённые',
                        count: completed,
                        active: _filter == _ProjectFilter.completed,
                        tone: ChipTone.success,
                        onTap: () =>
                            setState(() => _filter = _ProjectFilter.completed),
                      ),
                      const SizedBox(width: 7),
                      AppFilterChip(
                        label: 'Архив',
                        count: archived,
                        active: _filter == _ProjectFilter.archived,
                        onTap: () =>
                            setState(() => _filter = _ProjectFilter.archived),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (snapshot?.error != null && all.isEmpty)
                  InlineError(message: errorMessage, onRetry: refresh)
                else if (async.isLoading && snapshot == null)
                  const _ProjectsSkeleton()
                else if (error != null && snapshot == null)
                  InlineError(message: errorMessage, onRetry: refresh)
                else if (projects.isEmpty)
                  EmptyState(
                    icon: Icons.workspaces_outline,
                    title: _query.isEmpty
                        ? 'Здесь пока пусто'
                        : 'Проекты не найдены',
                    message: _query.isEmpty
                        ? 'Проекты появятся, когда менеджеры заведут клиентов.'
                        : 'Измените запрос или выберите другой фильтр.',
                  )
                else ...[
                  if (snapshot?.error != null) ...[
                    OfflineRibbon(
                      cachedAt: snapshot?.savedAt,
                      showRetry: true,
                      onRetry: refresh,
                    ),
                    const SizedBox(height: 14),
                  ],
                  for (final project in projects) ...[
                    _ProjectCard(project: project),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});

  final ProjectModel project;

  IconData get _icon {
    if (project.isSmm) return Icons.auto_awesome_rounded;
    if (project.projectType == 'Лендинг') return Icons.web_asset_rounded;
    if (project.projectType == 'Телеграм бот') return Icons.smart_toy_outlined;
    if (project.projectType == 'CRM система') {
      return Icons.dashboard_customize_outlined;
    }
    if (project.isDev) return Icons.code_rounded;
    return Icons.folder_outlined;
  }

  Color _colorFor(AppPalette palette) {
    if (project.isSmm) return palette.accent;
    if (project.isDev) return palette.ice;
    return palette.info;
  }

  @override
  Widget build(BuildContext context) {
    final completion = project.taskCount > 0
        ? project.doneTaskCount / project.taskCount
        : project.progress / 100;
    final progress = completion.clamp(0.0, 1.0);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      radius: 20,
      onTap: () => context.push('/projects/${project.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SurfaceIcon(
                icon: _icon,
                color: _colorFor(context.palette),
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.15,
                        color: context.palette.text,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        AppChip(
                          label: project.typeLabel,
                          tone: project.isSmm ? ChipTone.accent : ChipTone.info,
                          compact: true,
                        ),
                        const SizedBox(width: 6),
                        StatusBadge(
                          status: project.status,
                          label: project.statusFieldLabel,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 19,
                color: context.palette.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: context.palette.surface3,
                    valueColor: AlwaysStoppedAnimation(
                      progress >= 1
                          ? context.palette.success
                          : _colorFor(context.palette),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(progress * 100).round()}%',
                style: AppTypography.number(
                  size: 12,
                  color: context.palette.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.task_alt_rounded,
                size: 13,
                color: context.palette.textTertiary,
              ),
              const SizedBox(width: 5),
              Text(
                project.taskCount == 0
                    ? 'Задач пока нет'
                    : '${project.doneTaskCount} из ${project.taskCount} задач',
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 10.5,
                  color: context.palette.textTertiary,
                ),
              ),
              const SizedBox(width: 12),
              if (project.manager != null) ...[
                AppAvatar(
                  name: project.manager!.name,
                  avatar: project.manager!.avatar,
                  size: 20,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    project.manager!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 10.5,
                      color: context.palette.textTertiary,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (project.hasActiveAd)
                const AppChip(
                  label: 'Реклама',
                  tone: ChipTone.warning,
                  compact: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProjectsSkeleton extends StatelessWidget {
  const _ProjectsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 4; i++) ...[
          const AppCard(
            padding: EdgeInsets.all(15),
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SkeletonBox(width: 44, height: 44, radius: 14),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 180, height: 13),
                          SizedBox(height: 9),
                          SkeletonBox(width: 100, height: 10),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 18),
                SkeletonBox(height: 5, radius: 99),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
