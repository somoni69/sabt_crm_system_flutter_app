import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/access/presentation/employee_access_page.dart';
import '../../features/ai/presentation/ai_chat_page.dart';
import '../../features/analytics/presentation/analytics_page.dart';
import '../../features/archive/presentation/archive_page.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/calendar/presentation/calendar_page.dart';
import '../../features/clients/presentation/client_detail_page.dart';
import '../../features/clients/presentation/clients_page.dart';
import '../../features/dev_board/presentation/dev_board_page.dart';
import '../../features/dev_board/presentation/dev_board_subpages.dart';
import '../../features/employees/presentation/employee_detail_page.dart';
import '../../features/employees/presentation/employees_page.dart';
import '../../features/employees/presentation/employees_subpages.dart';
import '../../features/employees/presentation/sales_plan_page.dart';
import '../../features/files/presentation/files_page.dart';
import '../../features/finance/presentation/finance_extra_pages.dart';
import '../../features/finance/presentation/finance_page.dart';
import '../../features/finance/presentation/finance_sections.dart';
import '../../features/finance/presentation/finance_transport_page.dart';
import '../../features/misc/presentation/web_only_page.dart';
import '../../features/notes/presentation/notes_page.dart';
import '../../features/notifications/presentation/notifications_page.dart';
import '../../features/onboarding/presentation/onboarding_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/projects/presentation/project_detail_page.dart';
import '../../features/projects/presentation/projects_page.dart';
import '../../features/risks/presentation/risks_page.dart';
import '../../features/security_log/presentation/security_log_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/smm/presentation/smm_control_page.dart';
import '../../features/smm/presentation/stories_check_page.dart';
import '../../features/smm/presentation/stories_month_page.dart';
import '../../features/splash/presentation/splash_page.dart';
import '../../features/tariffs/presentation/tariffs_page.dart';
import '../../features/tasks/presentation/task_detail_page.dart';
import '../../features/transport/presentation/transport_page.dart';
import '../dependencies.dart';
import '../rbac/permissions.dart';
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
      if (!canAccessRoute(session.user, location)) return '/';
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
        path: '/employees/sales-plan',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const SalesPlanPage(),
        ),
      ),
      GoRoute(
        path: '/employees/org',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const EmployeesOrgPage(),
        ),
      ),
      GoRoute(
        path: '/employees/week',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const EmployeesWeekPage(),
        ),
      ),
      GoRoute(
        path: '/employees/activity',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const EmployeesActivityPage(),
        ),
      ),
      GoRoute(
        path: '/team-activity',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const EmployeesActivityPage(),
        ),
      ),
      GoRoute(
        path: '/employees/kpi',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const EmployeesKpiPage(),
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
        path: '/stories-check/month',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const StoriesMonthPage(),
        ),
      ),
      GoRoute(
        path: '/analytics',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const AnalyticsPage(),
        ),
      ),
      GoRoute(
        path: '/finance',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const FinancePage(),
        ),
      ),
      GoRoute(
        path: '/finance/income',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const FinanceIncomePage(),
        ),
      ),
      GoRoute(
        path: '/finance/income/:direction',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: FinanceIncomeDetailPage(
            direction: state.pathParameters['direction'] ?? 'smm',
          ),
        ),
      ),
      GoRoute(
        path: '/finance/expense',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const FinanceExpensePage(),
        ),
      ),
      GoRoute(
        path: '/finance/salary',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const FinanceSalaryPage(),
        ),
      ),
      GoRoute(
        path: '/finance/subscriptions',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const FinanceSubscriptionsPage(),
        ),
      ),
      GoRoute(
        path: '/finance/debts',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const FinanceDebtsPage(),
        ),
      ),
      GoRoute(
        path: '/finance/transactions',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const FinanceJournalPage(),
        ),
      ),
      GoRoute(
        path: '/finance/planning',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const FinancePlanningPage(),
        ),
      ),
      GoRoute(
        path: '/finance/inventory',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const FinanceInventoryPage(),
        ),
      ),
      GoRoute(
        path: '/finance/activity',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const FinanceActivityPage(),
        ),
      ),
      GoRoute(
        path: '/finance/settings',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const FinanceSettingsPage(),
        ),
      ),
      GoRoute(
        path: '/finance/salary/:id',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: FinanceEmployeeSalaryPage(
            employeeId: state.pathParameters['id'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/dev/projects',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const DevProjectsPage(),
        ),
      ),
      GoRoute(
        path: '/dev/projects/:id',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: DevProjectDetailPage(
            projectId: state.pathParameters['id'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/dev-board',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const DevBoardPage(),
        ),
      ),
      GoRoute(
        path: '/dev-board/kpi',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const DevBoardKpiPage(),
        ),
      ),
      GoRoute(
        path: '/dev-board/reports',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const DevBoardReportsPage(),
        ),
      ),
      GoRoute(
        path: '/dev-board/task/:id',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: DevTaskDetailPage(taskId: state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/files',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const FilesPage(),
        ),
      ),
      GoRoute(
        path: '/tariffs',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const TariffsPage(),
        ),
      ),
      GoRoute(
        path: '/archive',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const ArchivePage(),
        ),
      ),
      GoRoute(
        path: '/my-notes',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const MyNotesPage(),
        ),
      ),
      GoRoute(
        path: '/ai',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const AiChatPage(),
        ),
      ),
      GoRoute(
        path: '/risks',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const RisksPage(),
        ),
      ),
      GoRoute(
        path: '/security-log',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const SecurityLogPage(),
        ),
      ),
      GoRoute(
        path: '/transport',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const TransportPage(),
        ),
      ),
      GoRoute(
        path: '/finance/transport',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const FinanceTransportPage(),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const OnboardingPage(),
        ),
      ),
      GoRoute(
        path: '/employee-access',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const EmployeeAccessPage(),
        ),
      ),
      GoRoute(
        path: '/smm/control',
        pageBuilder: (context, state) => motionPage(
          context: context,
          pageKey: state.pageKey,
          child: const SmmControlPage(),
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
