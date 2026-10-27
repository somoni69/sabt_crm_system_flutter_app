import '../../../core/utils/date_utils.dart';
import '../../../core/utils/json_utils.dart';

class DevTask {
  const DevTask({
    required this.id,
    required this.title,
    this.description,
    this.status = 'todo',
    this.priority = 'medium',
    this.type = 'task',
    this.projectId,
    this.projectName,
    this.assigneeName,
    this.assigneeAvatar,
    this.deadline,
    this.taskNumber,
  });

  final String id;
  final String title;
  final String? description;
  final String status;
  final String priority;
  final String type;
  final String? projectId;
  final String? projectName;
  final String? assigneeName;
  final String? assigneeAvatar;
  final DateTime? deadline;
  final int? taskNumber;

  factory DevTask.fromJson(Map<String, dynamic> json) {
    final project = asMap(json['project']);
    final assignee = asMap(json['assignee'] ?? json['user']);

    return DevTask(
      id: asStringOr(json['id'], ''),
      title: asStringOr(json['title'], 'Без названия'),
      description: asString(json['description']),
      status: asStringOr(json['status'], 'todo'),
      priority: asStringOr(json['priority'], 'medium'),
      type: asStringOr(json['type'], 'task'),
      projectId: asString(json['projectId'] ?? project?['id']),
      projectName: asString(project?['name'] ?? json['projectName']),
      assigneeName: asString(assignee?['name'] ?? json['assigneeName']),
      assigneeAvatar: asString(assignee?['avatar'] ?? json['assigneeAvatar']),
      deadline: BizDate.parse(json['deadline']),
      taskNumber: asInt(json['taskNumber'] ?? json['number']),
    );
  }

  static const List<String> statuses = [
    'backlog',
    'todo',
    'in_progress',
    'testing',
    'done',
  ];

  static String statusLabel(String status) => switch (status) {
        'backlog' => 'Бэклог',
        'todo' => 'К выполнению',
        'in_progress' => 'В работе',
        'testing' => 'Тестирование',
        'done' => 'Готово',
        _ => status,
      };

  static String typeLabel(String type) => switch (type) {
        'feature' => 'Фича',
        'bug' => 'Баг',
        'refactor' => 'Рефакторинг',
        _ => 'Задача',
      };
}
