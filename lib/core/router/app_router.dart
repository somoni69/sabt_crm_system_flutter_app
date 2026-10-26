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
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const AppShell(),
      ),
      GoRoute(
        path: '/tasks/:id',
        builder: (context, state) => TaskDetailPage(
          taskId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/projects',
        builder: (context, state) => const ProjectsPage(standalone: true),
      ),
      GoRoute(
        path: '/projects/:id',
        builder: (context, state) => ProjectDetailPage(
          projectId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/calendar',
        builder: (context, state) => const CalendarPage(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/clients',
        builder: (context, state) => const ClientsPage(),
      ),
      GoRoute(
        path: '/clients/:id',
        builder: (context, state) => ClientDetailPage(
          clientId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/employees',
        builder: (context, state) => const EmployeesPage(),
      ),
      GoRoute(
        path: '/employees/:id',
        builder: (context, state) => EmployeeDetailPage(
          employeeId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/stories-check',
        builder: (context, state) => const StoriesCheckPage(),
      ),
      GoRoute(
        path: '/web-only',
        builder: (context, state) => WebOnlyPage(
          path: state.uri.queryParameters['path'] ?? '/',
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
