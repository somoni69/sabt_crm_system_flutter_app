import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:webrand_app/core/cache/snapshot.dart';
import 'package:webrand_app/features/analytics/domain/analytics_data.dart';
import 'package:webrand_app/features/analytics/presentation/analytics_page.dart';
import 'package:webrand_app/features/analytics/presentation/analytics_providers.dart';
import 'package:webrand_app/features/archive/presentation/archive_page.dart';
import 'package:webrand_app/features/archive/presentation/archive_providers.dart';
import 'package:webrand_app/features/dev_board/domain/dev_task.dart';
import 'package:webrand_app/features/dev_board/presentation/dev_board_page.dart';
import 'package:webrand_app/features/dev_board/presentation/dev_board_providers.dart';
import 'package:webrand_app/features/dev_board/presentation/dev_board_subpages.dart';
import 'package:webrand_app/features/employees/domain/employee.dart';
import 'package:webrand_app/features/employees/presentation/employees_providers.dart';
import 'package:webrand_app/features/employees/presentation/employees_subpages.dart';
import 'package:webrand_app/features/files/domain/app_file.dart';
import 'package:webrand_app/features/files/presentation/files_page.dart';
import 'package:webrand_app/features/files/presentation/files_providers.dart';
import 'package:webrand_app/features/finance/domain/finance_models.dart';
import 'package:webrand_app/features/finance/presentation/finance_extra_pages.dart';
import 'package:webrand_app/features/finance/presentation/finance_page.dart';
import 'package:webrand_app/features/finance/presentation/finance_providers.dart';
import 'package:webrand_app/features/projects/domain/project.dart';
import 'package:webrand_app/features/projects/presentation/projects_providers.dart';
import 'package:webrand_app/features/tariffs/domain/tariff.dart';
import 'package:webrand_app/features/tariffs/presentation/tariffs_page.dart';
import 'package:webrand_app/features/tariffs/presentation/tariffs_providers.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru', null);
  });

  group('Native Pages Render Tests (Zero RenderSliverToBoxAdapter bugs)', () {
    testWidgets('DevBoardPage renders without layout exceptions', (tester) async {
      final List<DevTask> mockTasks = [
        const DevTask(
          id: 'task-1',
          title: 'Тестовая задача',
          projectName: 'SABT CRM',
          status: 'in_progress',
          type: 'task',
          assigneeName: 'Фарзод',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            devBoardTasksProvider.overrideWith((ref) async => mockTasks),
          ],
          child: const MaterialApp(
            home: DevBoardPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Доска разработки'), findsOneWidget);
      expect(find.text('Тестовая задача'), findsOneWidget);
      expect(find.text('SABT CRM'), findsOneWidget);
    });

    testWidgets('FilesPage renders empty and populated states without layout exceptions', (tester) async {
      final List<ProjectModel> mockProjects = [
        const ProjectModel(
          id: 'proj-1',
          name: 'Проект Альфа',
          status: 'active',
          progress: 50,
          membersCount: 3,
          taskCount: 10,
          doneTaskCount: 5,
        ),
      ];

      final List<AppFile> mockFiles = [
        const AppFile(
          id: 'file-1',
          name: 'договор.pdf',
          size: 1048576,
          mimeType: 'application/pdf',
          url: 'https://example.com/file.pdf',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visibleProjectsProvider.overrideWithValue(mockProjects),
            projectFilesProvider.overrideWith(
              (ref, projectId) => Stream.value(mockFiles),
            ),
          ],
          child: const MaterialApp(
            home: FilesPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Файлы'), findsOneWidget);
      expect(find.text('договор.pdf'), findsOneWidget);
    });

    testWidgets('AnalyticsPage renders KPI cards without layout exceptions', (tester) async {
      const mockData = AnalyticsDashboardData(
        overview: AnalyticsOverview(
          totalProjects: 10,
          activeProjects: 5,
          totalTasks: 50,
          doneTasks: 30,
          completionRate: 60,
          totalEmployees: 8,
          overdueTasks: 2,
          hoursThisMonth: 120.0,
        ),
        employeeActivity: [],
        tasksByStatus: [],
        projectsByStatus: [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            analyticsDashboardProvider.overrideWith((ref) async => mockData),
          ],
          child: const MaterialApp(
            home: AnalyticsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Аналитика'), findsOneWidget);
      expect(find.text('Всего задач'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
    });

    testWidgets('FinancePage renders overview and KPI cards without layout exceptions', (tester) async {
      const mockOverview = FinanceOverviewData(
        ym: '2026-10',
        income: 150000,
        expense: 45000,
        profit: 105000,
        receivables: 3000,
        accounts: [
          FinanceAccount(
            id: 'acc-1',
            name: 'Основной расчетный счет',
            balance: 105000,
            currency: 'TJS',
          ),
        ],
        recentTransactions: [
          FinanceTransaction(
            id: 'tx-1',
            type: 'income',
            amount: 5000,
            category: 'Оплата услуг',
            description: 'Оплата за разработку',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financeOverviewProvider.overrideWith((ref) async => mockOverview),
          ],
          child: const MaterialApp(
            home: FinancePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Финансы'), findsOneWidget);
      expect(find.text('Основной расчетный счет'), findsOneWidget);
      expect(find.text('Оплата за разработку'), findsOneWidget);
    });

    testWidgets('TariffsPage renders tariff cards without layout exceptions', (tester) async {
      final List<Tariff> mockTariffs = [
        const Tariff(
          id: 'tariff-1',
          name: 'Тариф PRO',
          description: 'Полный пакет услуг',
          monthlyPrice: 2500,
          storiesPerMonth: 30,
          reelsPerMonth: 10,
          isActive: true,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tariffsListProvider.overrideWith((ref) async => mockTariffs),
          ],
          child: const MaterialApp(
            home: TariffsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Тарифы'), findsOneWidget);
      expect(find.text('Тариф PRO'), findsOneWidget);
      expect(find.text('Полный пакет услуг'), findsOneWidget);
    });

    testWidgets('ArchivePage renders archived projects without layout exceptions', (tester) async {
      final List<ProjectModel> mockArchived = [
        const ProjectModel(
          id: 'arch-1',
          name: 'Старый проект 2025',
          status: 'completed',
          progress: 100,
          membersCount: 2,
          taskCount: 20,
          doneTaskCount: 20,
          isArchived: true,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            archivedProjectsProvider.overrideWith((ref) async => mockArchived),
          ],
          child: const MaterialApp(
            home: ArchivePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Архив'), findsOneWidget);
      expect(find.text('Старый проект 2025'), findsOneWidget);
    });

    testWidgets('EmployeesOrgPage renders org structure without layout exceptions', (tester) async {
      final mockEmployees = [
        const EmployeeModel(
          id: 'emp-1',
          userId: 'user-1',
          fullName: 'Фарзод Сафаров',
          position: 'CEO / Founder',
          department: 'management',
          role: 'founder',
          status: 'active',
        ),
        const EmployeeModel(
          id: 'emp-2',
          userId: 'user-2',
          fullName: 'Алишер Каримов',
          position: 'Senior Flutter Dev',
          department: 'dev',
          role: 'developer',
          status: 'active',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            employeesProvider.overrideWith(
              (ref) => Stream.value(
                Snapshot(
                  data: mockEmployees,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: EmployeesOrgPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Оргструктура'), findsOneWidget);
      expect(find.text('Фарзод Сафаров'), findsOneWidget);
      expect(find.text('Алишер Каримов'), findsOneWidget);
    });

    testWidgets('DevProjectsPage renders without layout exceptions', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            devProjectsProvider.overrideWith(
              (ref) async => [
                {
                  'id': 'dev-proj-1',
                  'name': 'SABT Mobile App',
                  'status': 'in_progress',
                  'projectType': 'mobile_app',
                  'devStage': 60,
                  'progress': 60,
                },
              ],
            ),
          ],
          child: const MaterialApp(
            home: DevProjectsPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Проекты разработки'), findsOneWidget);
      expect(find.text('SABT Mobile App'), findsOneWidget);
    });

    testWidgets('DevBoardKpiPage renders without layout exceptions', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            devBoardKpiProvider.overrideWith(
              (ref) async => {
                'team': {
                  'total': 22,
                  'done': 18,
                  'inProgress': 4,
                  'overdue': 0,
                  'onTimeRate': 94,
                  'avgCycleDays': 2.4,
                },
                'members': [
                  {
                    'id': 'dev-1',
                    'name': 'Алишер Каримов',
                    'total': 22,
                    'done': 18,
                    'inProgress': 4,
                    'overdue': 0,
                    'onTimeRate': 94,
                  },
                ],
              },
            ),
          ],
          child: const MaterialApp(
            home: DevBoardKpiPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('KPI разработки'), findsOneWidget);
      expect(find.text('Алишер Каримов'), findsOneWidget);
    });

    testWidgets('FinanceInventoryPage renders without layout exceptions', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financeAssetsProvider.overrideWith(
              (ref) async => [
                {
                  'id': 'asset-1',
                  'name': 'Sony A7 IV',
                  'category': 'Камеры',
                  'price': 28000,
                  'residual': 21000,
                  'monthlyDep': 777,
                  'status': 'in_use',
                  'assignee': 'Оператор',
                },
              ],
            ),
          ],
          child: const MaterialApp(
            home: FinanceInventoryPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Инвентарь'), findsOneWidget);
      expect(find.text('Sony A7 IV'), findsOneWidget);
    });

    testWidgets('FinanceActivityPage renders without layout exceptions', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financeActivityProvider.overrideWith(
              (ref) async => [
                {
                  'id': 'act-1',
                  'action': 'Создана транзакция +15 000 с.',
                  'userName': 'Фарзод',
                  'createdAt': '2026-10-28T10:00:00Z',
                },
              ],
            ),
          ],
          child: const MaterialApp(
            home: FinanceActivityPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Активность финансов'), findsOneWidget);
      expect(find.text('Создана транзакция +15 000 с.'), findsOneWidget);
    });
  });
}
