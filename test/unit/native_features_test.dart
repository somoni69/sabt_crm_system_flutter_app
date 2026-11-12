import 'package:flutter_test/flutter_test.dart';
import 'package:webrand_app/features/analytics/domain/analytics_data.dart';
import 'package:webrand_app/features/dev_board/domain/dev_task.dart';
import 'package:webrand_app/features/files/domain/app_file.dart';
import 'package:webrand_app/features/finance/domain/finance_models.dart';
import 'package:webrand_app/features/tariffs/domain/tariff.dart';

void main() {
  group('AnalyticsDashboardData model', () {
    test('fromJson parses full analytics payload', () {
      final json = {
        'overview': {
          'totalProjects': 15,
          'activeProjects': 8,
          'totalTasks': 120,
          'doneTasks': 95,
          'completionRate': 79,
          'totalEmployees': 12,
          'overdueTasks': 4,
          'hoursThisMonth': 160.5,
        },
        'employeeActivity': [
          {
            'id': 'emp-1',
            'name': 'Farhod',
            'completedTasks': 42,
            'loggedHours': 88.0,
          }
        ],
        'taskByStatus': [
          {'status': 'done', 'count': 95},
          {'status': 'in_progress', 'count': 25},
        ],
      };

      final data = AnalyticsDashboardData.fromJson(json);
      expect(data.overview.totalTasks, 120);
      expect(data.overview.doneTasks, 95);
      expect(data.overview.activeProjects, 8);
      expect(data.overview.overdueTasks, 4);
      expect(data.overview.completionRate, 79);
      expect(data.overview.hoursThisMonth, 160.5);

      expect(data.employeeActivity.length, 1);
      expect(data.employeeActivity.first.name, 'Farhod');
      expect(data.employeeActivity.first.completedTasks, 42);

      expect(data.tasksByStatus.length, 2);
      expect(data.tasksByStatus.first.status, 'done');
      expect(data.tasksByStatus.first.count, 95);
    });

    test('fromJson handles empty or partial payload safely', () {
      final data = AnalyticsDashboardData.fromJson({});
      expect(data.overview.totalTasks, 0);
      expect(data.employeeActivity, isEmpty);
      expect(data.tasksByStatus, isEmpty);
      expect(data.projectsByStatus, isEmpty);
    });
  });

  group('Finance models', () {
    test('FinanceOverviewData fromJson parses overview metrics and collections', () {
      final json = {
        'income': 150000.0,
        'expense': 90000.0,
        'profit': 60000.0,
        'receivables': 25000.0,
        'totalBalance': 320000.0,
        'accounts': [
          {'id': 'acc-1', 'name': 'Основной расчётный счёт', 'type': 'bank', 'balance': 250000.0, 'currency': 'TJS'},
          {'id': 'acc-2', 'name': 'Касса', 'type': 'cash', 'balance': 70000.0, 'currency': 'TJS'},
        ],
        'recentTransactions': [
          {
            'id': 'tx-1',
            'amount': 15000.0,
            'type': 'income',
            'description': 'Оплата за маркетинг',
            'accountName': 'Основной расчётный счёт',
            'date': '2026-10-25T10:00:00Z',
          },
          {
            'id': 'tx-2',
            'amount': 4000.0,
            'type': 'expense',
            'description': 'Серверы и подписки',
            'accountName': 'Основной расчётный счёт',
            'date': '2026-10-26T12:00:00Z',
          },
        ],
      };

      final overview = FinanceOverviewData.fromJson(json, '2026-10');
      expect(overview.ym, '2026-10');
      expect(overview.income, 150000.0);
      expect(overview.expense, 90000.0);
      expect(overview.profit, 60000.0);
      expect(overview.accounts.length, 2);
      expect(overview.accounts.first.name, 'Основной расчётный счёт');

      expect(overview.recentTransactions.length, 2);
      expect(overview.recentTransactions.first.isIncome, isTrue);
      expect(overview.recentTransactions.last.isIncome, isFalse);
    });
  });

  group('DevTask model', () {
    test('fromJson and status helpers', () {
      final json = {
        'id': 'task-101',
        'title': 'Интеграция нативных экранов в Flutter',
        'description': 'Заменить WebOnlyPage на нативные реализации',
        'status': 'in_progress',
        'priority': 'high',
        'type': 'feature',
        'assignee': {'name': 'Agent'},
        'createdAt': '2026-10-26T08:00:00Z',
      };

      final devTask = DevTask.fromJson(json);
      expect(devTask.id, 'task-101');
      expect(devTask.title, 'Интеграция нативных экранов в Flutter');
      expect(devTask.assigneeName, 'Agent');
      expect(DevTask.statusLabel(devTask.status), 'В работе');
      expect(DevTask.typeLabel(devTask.type), 'Фича');
    });
  });

  group('AppFile model', () {
    test('fromJson and size formatted string', () {
      final json = {
        'id': 'f-1',
        'name': 'brandbook_final.pdf',
        'size': 2097152, // 2 MB
        'mimeType': 'application/pdf',
        'url': 'https://sabt.tj/files/brandbook_final.pdf',
        'uploadedBy': {'name': 'Designer'},
        'createdAt': '2026-10-20T14:30:00Z',
      };

      final file = AppFile.fromJson(json);
      expect(file.id, 'f-1');
      expect(file.name, 'brandbook_final.pdf');
      expect(file.sizeLabel, '2.0 MB');
      expect(file.uploadedByName, 'Designer');
    });
  });

  group('Tariff model', () {
    test('fromJson parses tariff specifications', () {
      final json = {
        'id': 'tariff-pro',
        'name': 'SMM Pro Max',
        'monthlyPrice': 4500,
        'storiesPerMonth': 60,
        'reelsPerMonth': 15,
        'postsPerMonth': 20,
        'designsPerMonth': 30,
        'shootingDaysPerMonth': 4,
        'isActive': true,
      };

      final tariff = Tariff.fromJson(json);
      expect(tariff.id, 'tariff-pro');
      expect(tariff.name, 'SMM Pro Max');
      expect(tariff.monthlyPrice, 4500);
      expect(tariff.storiesPerMonth, 60);
      expect(tariff.reelsPerMonth, 15);
      expect(tariff.postsPerMonth, 20);
      expect(tariff.isActive, isTrue);
    });
  });
}
