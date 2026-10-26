import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/calendar/presentation/calendar_page.dart';
import '../../features/clients/presentation/client_detail_page.dart';
import '../../features/clients/presentation/clients_page.dart';
import '../../features/employees/presentation/employee_detail_page.dart';
import '../../features/employees/presentation/employees_page.dart';
import '../../features/misc/presentation/web_only_page.dart';
import '../../features/notifications/presentation/notifications_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/projects/presentation/project_detail_page.dart';
import '../../features/projects/presentation/projects_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/smm/presentation/stories_check_page.dart';
import '../../features/splash/presentation/splash_page.dart';
import '../../features/tasks/presentation/task_detail_page.dart';
import '../dependencies.dart';
import 'motion_page.dart';

/// The router is created once and refreshed by auth transitions. The auth
/// controller never sets `AsyncLoading` during a sign-in attempt, so the login
/// screen owns its own busy state and this redirect stays stable.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(authControllerProvider, (previous, next) => refresh.value++);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      final booting = auth.isLoading && !auth.hasValue;

      if (booting) return location == '/splash' ? null : '/splash';

      final session = auth.value;
      if (session == null) return location == '/login' ? null : '/login';
      if (location == '/login' || location == '/splash') return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const SplashPage(),
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const LoginPage(),
        ),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const AppShell(),
        ),
      ),
      GoRoute(
        path: '/tasks/:id',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: TaskDetailPage(taskId: state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/projects',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const ProjectsPage(standalone: true),
        ),
      ),
      GoRoute(
        path: '/projects/:id',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: ProjectDetailPage(projectId: state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/calendar',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const CalendarPage(),
        ),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const NotificationsPage(),
        ),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const ProfilePage(),
        ),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const SettingsPage(),
        ),
      ),
      GoRoute(
        path: '/clients',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const ClientsPage(),
        ),
      ),
      GoRoute(
        path: '/clients/:id',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: ClientDetailPage(clientId: state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/employees',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const EmployeesPage(),
        ),
      ),
      GoRoute(
        path: '/employees/:id',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: EmployeeDetailPage(
            employeeId: state.pathParameters['id'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/stories-check',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const StoriesCheckPage(),
        ),
      ),
      GoRoute(
        path: '/web-only',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: WebOnlyPage(path: state.uri.queryParameters['path'] ?? '/'),
        ),
      ),
    ],
    errorBuilder: (context, state) => const _RouteErrorPage(),
  );

  ref.read(dependenciesProvider).navigation.attachRouter(router);
  ref.onDispose(router.dispose);
  return router;
});

class _RouteErrorPage extends StatelessWidget {
  const _RouteErrorPage();

  @override
  Widget build(BuildContext context) {
    return const SplashPage();
  }
}
