import 'package:flutter_test/flutter_test.dart';
import 'package:webrand_app/core/utils/date_utils.dart';
import 'package:webrand_app/features/tasks/domain/task.dart';

void main() {
  group('TaskModel', () {
    test('fromJson correctly parses complete task payload', () {
      final json = <String, dynamic>{
        'id': 'task-100',
        'title': 'Разработка лендинга',
        'status': 'in_progress',
        'priority': 'critical',
        'description': 'Создать промо-страницу',
        'project': {'id': 'proj-1', 'name': 'Sabt Mobile'},
        'assignees': [
          {
            'user': {'id': 'u-1', 'name': 'Алишер'},
            'isDone': true,
          },
          {
            'user': {'id': 'u-2', 'name': 'Зарина'},
            'isDone': false,
          }
        ],
        'checklist': [
          {'id': 'chk-1', 'text': 'Дизайн макет', 'done': true},
          {'id': 'chk-2', 'text': 'Вёрстка', 'done': false},
        ],
        'deadline': '2026-10-30T18:00:00+05:00',
        'loggedHours': 4.5,
        'estimatedHours': 10,
        'progress': 45,
      };

      final task = TaskModel.fromJson(json);

      expect(task.id, 'task-100');
      expect(task.title, 'Разработка лендинга');
      expect(task.status, 'in_progress');
      expect(task.priority, 'critical');
      expect(task.projectName, 'Sabt Mobile');
      expect(task.assignees.length, 2);
      expect(task.assignees[0].name, 'Алишер');
      expect(task.assignees[0].isDone, isTrue);
      expect(task.assigneeLabel, 'Алишер +1');
      expect(task.checklistDone, 1);
      expect(task.checklistTotal, 2);
      expect(task.isDone, isFalse);
      expect(task.loggedHours, 4.5);
      expect(task.progress, 45);
    });

    test('overdue and dueToday properties calculate correctly', () {
      final now = BizDate.now();
      final overdueTask = TaskModel(
        id: 't-overdue',
        title: 'Старая задача',
        status: 'in_progress',
        priority: 'high',
        deadline: now.subtract(const Duration(days: 3)),
      );

      final todayTask = TaskModel(
        id: 't-today',
        title: 'Сегодняшняя задача',
        status: 'in_progress',
        priority: 'medium',
        deadline: now,
      );

      final doneTask = TaskModel(
        id: 't-done',
        title: 'Выполненная задача',
        status: 'done',
        priority: 'high',
        deadline: now.subtract(const Duration(days: 3)),
      );

      expect(overdueTask.isOverdue, isTrue);
      expect(todayTask.isDueToday, isTrue);
      // Completed tasks must not be counted as overdue even if deadline passed
      expect(doneTask.isOverdue, isFalse);
      expect(doneTask.isDone, isTrue);
    });
  });
}
