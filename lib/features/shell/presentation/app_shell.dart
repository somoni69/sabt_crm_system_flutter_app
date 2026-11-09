import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dependencies.dart';
import '../../../core/design/liquid_glass_bar.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/realtime/realtime_service.dart';
import '../../../core/state/app_state.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../clients/presentation/clients_page.dart';
import '../../dashboard/presentation/dashboard_page.dart';
import '../../dev_board/presentation/dev_board_page.dart';
import '../../projects/presentation/projects_page.dart';
import '../../smm/presentation/smm_page.dart';
import '../../smm/presentation/stories_check_page.dart';
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
        label: 'Панель',
        icon: Icons.grid_view_outlined,
        activeIcon: Icons.grid_view_rounded,
        page: DashboardPage(),
      ),
    ];

    final isPureStoriesChecker = user != null &&
        user.isStoriesChecker &&
        !canManageAccess(user) &&
        user.role != 'smm_director';

    if (isPureStoriesChecker) {
      if (canCheckStories(user)) {
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
      return tabs;
    }

    if (user != null) {
      if (canSeeSmmSection(user)) {
        tabs.add(const _ShellTab(
          id: 'work',
          label: 'СММ',
          icon: Icons.campaign_outlined,
          activeIcon: Icons.campaign_rounded,
          page: SmmPage(),
        ));
      } else if (canSeeDevSection(user)) {
        tabs.add(const _ShellTab(
          id: 'work',
          label: 'Разработка',
          icon: Icons.code_rounded,
          activeIcon: Icons.code_rounded,
          page: DevBoardPage(embedded: true),
        ));
      } else if (canSeeProjects(user)) {
        tabs.add(const _ShellTab(
          id: 'work',
          label: 'Проекты',
          icon: Icons.folder_outlined,
          activeIcon: Icons.folder_rounded,
          page: ProjectsPage(),
        ));
      } else if (canSeeClients(user)) {
        tabs.add(const _ShellTab(
          id: 'work',
          label: 'Клиенты',
          icon: Icons.contacts_outlined,
          activeIcon: Icons.contacts_rounded,
          page: ClientsPage(embedded: true),
        ));
      }
      if (canCheckStories(user) && !user.isStoriesChecker) {
        tabs.add(const _ShellTab(
          id: 'checks',
          label: 'Сторис',
          icon: Icons.fact_check_outlined,
          activeIcon: Icons.fact_check_rounded,
          page: StoriesCheckPage(embedded: true),
        ));
      }
    }

    if (user != null && userCan(user, Perm.tasksView)) {
      tabs.add(_ShellTab(
        id: 'tasks',
        label: isDevLead(user) ? 'Задачи' : 'Поручения',
        icon: Icons.assignment_outlined,
        activeIcon: Icons.assignment_rounded,
        page: const TasksPage(),
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
                bottom: MediaQuery.paddingOf(context).bottom + 82,
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

