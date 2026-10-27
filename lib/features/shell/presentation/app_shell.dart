import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/liquid_glass_bar.dart';
import '../../../core/dependencies.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/realtime/realtime_service.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../clients/presentation/clients_page.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../projects/presentation/projects_page.dart';
import '../../smm/presentation/content_form_sheet.dart';
import '../../smm/presentation/smm_page.dart';
import '../../smm/presentation/stories_check_page.dart';
import '../../smm/presentation/story_sheet.dart';
import '../../tasks/presentation/task_form_sheet.dart';
import '../../tasks/presentation/tasks_page.dart';
import 'more_page.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;
  final Set<String> _visited = {'home'};
  List<_ShellTab> _tabs = const [];

  StreamSubscription<RealtimeEvent>? _realtimeSub;
  StreamSubscription<dynamic>? _pushSub;
  bool _listenerAttached = false;

  @override
  void initState() {
    super.initState();
    final deps = ref.read(dependenciesProvider);
    _realtimeSub = deps.realtime.events.listen(_onRealtimeEvent);
    _pushSub = deps.push.foregroundMessages.listen((_) {
      ref.read(dataRevisionProvider.notifier).bump();
    });
    deps.navigation.requestedSection.addListener(_onSectionRequested);
    _listenerAttached = true;
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _pushSub?.cancel();
    if (_listenerAttached) {
      ref.read(navigationServiceProvider).requestedSection.removeListener(_onSectionRequested);
    }
    super.dispose();
  }

  void _onRealtimeEvent(RealtimeEvent event) {
    final deps = ref.read(dependenciesProvider);
    if (event.name == 'notification') {
      final raw = event.map ?? const <String, dynamic>{};
      final nested = raw['notification'];
      final payload = nested is Map
          ? Map<String, dynamic>.from(nested)
          : raw;
      final title = '${payload['title'] ?? 'Sabt'}';
      final message = '${payload['message'] ?? payload['body'] ?? ''}';
      if (message.isNotEmpty) {
        deps.banners.notification(
          title: title,
          message: message,
          link: payload['link']?.toString(),
          type: payload['type']?.toString(),
          id: payload['id']?.toString(),
        );
      }
    }
    ref.read(dataRevisionProvider.notifier).bump();
  }

  void _onSectionRequested() {
    final section = ref.read(navigationServiceProvider).requestedSection.value;
    if (section == null) return;
    ref.read(navigationServiceProvider).requestedSection.value = null;
    final index = _tabs.indexWhere((tab) => tab.id == section);
    if (index < 0 || !mounted) return;
    setState(() {
      _index = index;
      _visited.add(section);
    });
  }

  void _select(int index) {
    if (index == _index) return;
    setState(() {
      _index = index;
      _visited.add(_tabs[index].id);
    });
  }

  List<_ShellTab> _buildTabs(UserModel? user) {
    final tabs = <_ShellTab>[
      const _ShellTab(
        id: 'home',
        label: 'Главная',
        icon: Icons.grid_view_outlined,
        activeIcon: Icons.grid_view_rounded,
        page: DashboardPage(),
      ),
    ];

    if (user != null && userCan(user, Perm.tasksView)) {
      tabs.add(const _ShellTab(
        id: 'tasks',
        label: 'Задачи',
        icon: Icons.checklist_outlined,
        activeIcon: Icons.checklist_rounded,
        page: TasksPage(),
      ));
    }

    if (user != null) {
      if (canSeeSmmSection(user)) {
        tabs.add(const _ShellTab(
          id: 'work',
          label: 'SMM',
          icon: Icons.auto_awesome_outlined,
          activeIcon: Icons.auto_awesome,
          page: SmmPage(),
        ));
      } else if (canSeeProjects(user)) {
        tabs.add(const _ShellTab(
          id: 'work',
          label: 'Проекты',
          icon: Icons.workspaces_outline,
          activeIcon: Icons.workspaces_rounded,
          page: ProjectsPage(),
        ));
      } else if (canSeeClients(user)) {
        tabs.add(const _ShellTab(
          id: 'work',
          label: 'Клиенты',
          icon: Icons.people_outline_rounded,
          activeIcon: Icons.people_rounded,
          page: ClientsPage(embedded: true),
        ));
      }
    }

    if (user != null && user.isStoriesChecker && canCheckStories(user)) {
      tabs.add(const _ShellTab(
        id: 'checks',
        label: 'Проверки',
        icon: Icons.fact_check_outlined,
        activeIcon: Icons.fact_check_rounded,
        page: StoriesCheckPage(embedded: true),
      ));
    }

    tabs.add(const _ShellTab(
      id: 'more',
      label: 'Ещё',
      icon: Icons.more_horiz_rounded,
      activeIcon: Icons.more_rounded,
      page: MorePage(),
    ));

    return tabs.take(5).toList();
  }

  Future<void> _openQuickCreate() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final actions = <_QuickAction>[
      if (canCreateTask(user))
        _QuickAction(
          icon: Icons.add_task_rounded,
          color: context.palette.accentBright,
          title: 'Новая задача',
          subtitle: 'Поставить задачу себе или команде',
          onTap: () => showTaskForm(context, ref),
        ),
      if (canCreateTask(user))
        _QuickAction(
          icon: Icons.videocam_outlined,
          color: context.palette.ice,
          title: 'Встреча',
          subtitle: 'Создать встречу или звонок в календаре',
          onTap: () => showTaskForm(
            context,
            ref,
            initialKind: 'meeting',
            initialDeadline: _nextRoundHour(),
          ),
        ),
      if (canSeeSmmSection(user) && !isSmmViewOnly(user))
        _QuickAction(
          icon: Icons.auto_awesome_rounded,
          color: context.palette.accent,
          title: 'Контент в план',
          subtitle: 'Рилс, пост или макет на дату',
          onTap: () => showContentForm(context, ref),
        ),
      if (isStoryWriter(user))
        _QuickAction(
          icon: Icons.auto_awesome_motion_rounded,
          color: context.palette.success,
          title: 'Внести сторис',
          subtitle: 'Отметить количество историй за сегодня',
          onTap: () => showStorySheet(context, ref),
        ),
      if (canCheckStories(user) && !user.isStoriesChecker)
        _QuickAction(
          icon: Icons.fact_check_outlined,
          color: context.palette.warning,
          title: 'Проверка сторис',
          subtitle: 'Кто не закрыл дневную норму',
          onTap: () => context.push('/stories-check'),
        ),
    ];

    if (actions.isEmpty) {
      ref.read(dependenciesProvider).banners.show(const AppBanner(
            title: 'Нет доступных действий',
            message: 'Для вашей роли создание записей недоступно.',
            tone: BannerTone.info,
          ));
      return;
    }

    await showGlassSheet<void>(
      context: context,
      title: 'Быстрое действие',
      subtitle: 'Создайте запись, не покидая текущий экран',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _QuickActionRow(
              action: actions[i],
              onTap: () {
                Navigator.of(context).pop();
                Future<void>.delayed(const Duration(milliseconds: 220), () {
                  if (mounted) actions[i].onTap();
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  DateTime _nextRoundHour() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, now.hour + 1);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final tabs = _buildTabs(user);
    _tabs = tabs;
    final index = _index.clamp(0, tabs.length - 1);
    if (index != _index) _index = index;

    final offline = !ref.watch(onlineProvider);

    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _select(0);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: IndexedStack(
                index: index,
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    _visited.contains(tabs[i].id)
                        ? RepaintBoundary(
                            key: ValueKey(tabs[i].id),
                            child: tabs[i].page,
                          )
                        : const SizedBox.shrink(),
                ],
              ),
            ),
            if (offline)
              Positioned(
                left: 16,
                right: 16,
                bottom: MediaQuery.paddingOf(context).bottom + 88,
                child: const IgnorePointer(child: OfflineRibbon()),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LiquidGlassNavBar(
                items: [
                  for (final tab in tabs)
                    GlassNavItem(
                      icon: tab.icon,
                      activeIcon: tab.activeIcon,
                      label: tab.label,
                    ),
                ],
                selectedIndex: index,
                onSelected: _select,
                onAction: _openQuickCreate,
                actionTooltip: 'Создать',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShellTab {
  const _ShellTab({
    required this.id,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.page,
  });

  final String id;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget page;
}

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow({required this.action, required this.onTap});

  final _QuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.palette.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.palette.borderSoft),
          ),
          child: Row(
            children: [
              SurfaceIcon(icon: action.icon, color: action.color, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style:  TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: context.palette.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      action.subtitle,
                      style:  TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 11.5,
                        color: context.palette.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
               Icon(Icons.chevron_right_rounded,
                  size: 18, color: context.palette.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
