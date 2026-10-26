import '../../../core/utils/date_utils.dart';
import '../../../core/utils/json_utils.dart';

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.type,
    this.description,
    this.status,
    this.priority,
    this.projectName,
    this.assigneeName,
    this.assigneeId,
    this.taskId,
    this.clientId,
    this.scope = 'business',
    this.kind = 'task',
    this.location,
    this.progress = 0,
    this.link,
    this.time,
    this.payState,
    this.fromFounder = false,
  });

  final String id;
  final String title;
  final DateTime date;
  final String type;
  final String? description;
  final String? status;
  final String? priority;
  final String? projectName;
  final String? assigneeName;
  final String? assigneeId;
  final String? taskId;
  final String? clientId;
  final String scope;
  final String kind;
  final String? location;
  final int progress;
  final String? link;
  final String? time;
  final String? payState;
  final bool fromFounder;

  bool get isTask => type == 'task';
  bool get isMeeting => type == 'client_meeting' || kind == 'meeting';
  bool get isRepeatCall => type == 'client_repeat_call';
  bool get isShoot => type == 'shoot';
  bool get isPayment => type == 'client_payment';
  bool get isProjectMilestone => type == 'project_start' || type == 'project_end';
  bool get isDone => status == 'done' || status == 'completed';

  bool get isOverdue =>
      isTask && !isDone && status != 'cancelled' && date.isBefore(BizDate.now());

  String get timeLabel {
    if (time != null && time!.isNotEmpty) return time!;
    if (BizDate.isMidnight(date)) return 'Весь день';
    return BizDate.time(date);
  }

  String get typeLabel => switch (type) {
        'task' => isMeeting ? 'Встреча' : 'Задача',
        'client_meeting' => 'Встреча с клиентом',
        'client_repeat_call' => 'Повторный звонок',
        'shoot' => 'Съёмка',
        'client_payment' => 'Оплата клиента',
        'project_start' => 'Старт проекта',
        'project_end' => 'Завершение проекта',
        _ => type,
      };

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    final date = BizDate.parse(json['date'] ?? json['startDate']) ?? BizDate.now();
    return CalendarEvent(
      id: asStringOr(json['id'], ''),
      title: asStringOr(json['title'], 'Событие'),
      date: date,
      type: asStringOr(json['type'], 'task'),
      description: asString(json['description']),
      status: asString(json['status']),
      priority: asString(json['priority']),
      projectName: asString(json['projectName']),
      assigneeName: asString(json['assigneeName']),
      assigneeId: asString(json['assigneeId']),
      taskId: asString(json['taskId']),
      clientId: asString(json['clientId']),
      scope: asStringOr(json['scope'], 'business'),
      kind: asStringOr(json['kind'], 'task'),
      location: asString(json['location']),
      progress: asIntOr(json['progress'], 0),
      link: asString(json['link']),
      time: asString(json['time']),
      payState: asString(json['payState']),
      fromFounder: asBool(json['fromFounder']),
    );
  }
}
