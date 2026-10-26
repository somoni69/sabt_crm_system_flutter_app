import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sabt_crm/core/cache/snapshot.dart';
import 'package:sabt_crm/features/access/domain/access_models.dart';
import 'package:sabt_crm/features/access/presentation/access_providers.dart';
import 'package:sabt_crm/features/access/presentation/employee_access_page.dart';
import 'package:sabt_crm/features/ai/presentation/ai_chat_page.dart';
import 'package:sabt_crm/features/clients/domain/client_lead.dart';
import 'package:sabt_crm/features/clients/presentation/clients_providers.dart';
import 'package:sabt_crm/features/notes/domain/note.dart';
import 'package:sabt_crm/features/notes/presentation/notes_page.dart';
import 'package:sabt_crm/features/notes/presentation/notes_providers.dart';
import 'package:sabt_crm/features/onboarding/presentation/onboarding_page.dart';
import 'package:sabt_crm/features/risks/domain/risk_models.dart';
import 'package:sabt_crm/features/risks/presentation/risks_page.dart';
import 'package:sabt_crm/features/risks/presentation/risks_providers.dart';
import 'package:sabt_crm/features/security_log/domain/security_log_item.dart';
import 'package:sabt_crm/features/security_log/presentation/security_log_page.dart';
import 'package:sabt_crm/features/security_log/presentation/security_log_providers.dart';
import 'package:sabt_crm/features/smm/presentation/smm_control_page.dart';
import 'package:sabt_crm/features/smm/presentation/smm_control_providers.dart';
import 'package:sabt_crm/features/transport/domain/transport_request.dart';
import 'package:sabt_crm/features/transport/presentation/transport_page.dart';
import 'package:sabt_crm/features/transport/presentation/transport_providers.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru', null);
  });

  group('New Native Features Tests', () {
    test('Note model fromJson and copyWith', () {
      final json = {
        'id': 'note-1',
        'text': 'Купить реквизит',
        'date': '2026-10-27',
        'done': true,
      };
      final note = Note.fromJson(json);
      expect(note.id, 'note-1');
      expect(note.text, 'Купить реквизит');
      expect(note.done, true);
      expect(note.date, '2026-10-27');

      final updated = note.copyWith(done: false);
      expect(updated.done, false);
      expect(updated.text, 'Купить реквизит');
    });

    test('Risk models parsing', () {
      final prJson = {
        'projectId': 'p-1',
        'projectName': 'Mila Coffee',
        'level': 'yellow',
        'score': 45,
        'factors': [
          {'key': 'late', 'label': 'Отставание', 'triggered': true}
        ]
      };
      final pr = ProjectRisk.fromJson(prJson);
      expect(pr.projectName, 'Mila Coffee');
      expect(pr.level, 'yellow');
      expect(pr.factors.length, 1);
      expect(pr.factors.first.triggered, true);

      final ewJson = {
        'userId': 'u-1',
        'userName': 'Мадина',
        'role': 'SMM',
        'projectCount': 4,
        'tasksInProgress': 5,
        'overload': 'green',
      };
      final ew = EmployeeWorkload.fromJson(ewJson);
      expect(ew.userName, 'Мадина');
      expect(ew.projectCount, 4);
    });

    test('Transport request models parsing', () {
      final trJson = {
        'id': 'tr-1',
        'employeeName': 'Фарход',
        'projectName': 'Mila',
        'amount': 45.0,
        'date': '2026-10-26',
        'status': 'pending',
      };
      final tr = TransportRequestModel.fromJson(trJson);
      expect(tr.amount, 45.0);
      expect(tr.status, 'pending');

      final myData = MyTransportData.fromJson({
        'totalPaidThisMonth': 200,
        'totalPending': 45,
        'requests': [trJson],
      });
      expect(myData.totalPaidThisMonth, 200);
      expect(myData.requests.length, 1);
    });

    testWidgets('MyNotesPage renders without layout errors', (tester) async {
      final mockNotes = [
        const Note(id: '1', text: 'Первая задача', done: false),
        const Note(id: '2', text: 'Вторая задача', done: true),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myNotesProvider.overrideWith((ref) async => mockNotes),
          ],
          child: const MaterialApp(home: MyNotesPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Мои заметки'), findsOneWidget);
      expect(find.text('Первая задача'), findsOneWidget);
      expect(find.text('Вторая задача'), findsOneWidget);
    });

    testWidgets('AiChatPage renders message bubbles and quick chips', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: AiChatPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ИИ-помощник'), findsOneWidget);
      expect(find.textContaining('Здравствуйте!'), findsOneWidget);
      expect(find.text('Что по моим задачам на сегодня?'), findsOneWidget);
    });

    testWidgets('RisksPage renders projects and workload tabs', (tester) async {
      final mockProjects = [
        const ProjectRisk(projectId: 'p-1', projectName: 'Тестовый риск-проект', level: 'red'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectRisksProvider.overrideWith((ref) async => mockProjects),
            employeeWorkloadProvider.overrideWith((ref) async => const []),
          ],
          child: const MaterialApp(home: RisksPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Управление рисками'), findsOneWidget);
      expect(find.text('Тестовый риск-проект'), findsOneWidget);
      expect(find.text('Высокий риск'), findsOneWidget);
    });

    testWidgets('SecurityLogPage renders activity items', (tester) async {
      final mockLogs = [
        const SecurityLogItem(id: '1', action: 'LOGIN', userName: 'Фарход', details: 'Вход в систему'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            securityLogsProvider.overrideWith((ref) async => mockLogs),
          ],
          child: const MaterialApp(home: SecurityLogPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Журнал безопасности'), findsOneWidget);
      expect(find.text('LOGIN'), findsOneWidget);
      expect(find.text('Фарход'), findsOneWidget);
    });

    testWidgets('TransportPage renders KPI and requests', (tester) async {
      const mockData = MyTransportData(
        totalPaidThisMonth: 150,
        totalPending: 50,
        requests: [
          TransportRequestModel(
            id: '1',
            employeeName: 'Фарход',
            projectName: 'Mila Coffee',
            amount: 50,
            date: '2026-10-26',
            status: 'pending',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myTransportProvider.overrideWith((ref) async => mockData),
          ],
          child: const MaterialApp(home: TransportPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Транспорт и проезд'), findsOneWidget);
      expect(find.text('Mila Coffee'), findsOneWidget);
      expect(find.text('На рассмотрении'), findsNWidgets(2));
    });

    testWidgets('OnboardingPage renders client funnel stages', (tester) async {
      final mockClients = [
        const ClientLeadModel(
          id: 'c-1',
          name: 'Клиент Ресторан',
          onboardingStage: 'meeting',
          dealPotential: 12000,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clientsProvider.overrideWith((ref) => Stream.value(Snapshot(data: mockClients))),
          ],
          child: const MaterialApp(home: OnboardingPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Онбординг клиентов'), findsOneWidget);
      expect(find.text('Клиент Ресторан'), findsOneWidget);
      expect(find.text('Встреча'), findsNWidgets(2)); // in filter chip and in card badge
    });

    testWidgets('EmployeeAccessPage renders user access list', (tester) async {
      final mockUsers = [
        const AccessUser(
          id: 'u-1',
          name: 'Алишер Каримов',
          email: 'alisher@sabt.tj',
          role: 'smm_specialist',
          position: 'SMM-лид',
          extraPermissions: ['stories.manage'],
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accessUsersProvider.overrideWith((ref) async => mockUsers),
            accessCatalogProvider.overrideWith((ref) async => const []),
          ],
          child: const MaterialApp(home: EmployeeAccessPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Доступы сотрудников'), findsOneWidget);
      expect(find.text('Алишер Каримов'), findsOneWidget);
      expect(find.text('Персональных прав: 1'), findsOneWidget);
    });

    testWidgets('SmmControlPage renders projects overview', (tester) async {
      final mockProjects = [
        {
          'id': 'p-1',
          'name': 'Mila Coffee',
          'mood': 'good',
          'reels': {'done': 10, 'norm': 12},
          'posts': {'done': 15, 'norm': 15},
        }
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            smmControlProjectsProvider.overrideWith((ref) async => mockProjects),
          ],
          child: const MaterialApp(home: SmmControlPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Контроль SMM'), findsOneWidget);
      expect(find.text('Mila Coffee'), findsOneWidget);
      expect(find.text('Клиент доволен'), findsOneWidget);
    });
  });
}
