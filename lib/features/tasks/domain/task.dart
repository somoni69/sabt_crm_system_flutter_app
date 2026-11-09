import '../../../core/utils/date_utils.dart';
import '../../../core/utils/json_utils.dart';

class TaskPerson {
  const TaskPerson({
    required this.id,
    required this.name,
    this.avatar,
    this.isDone = false,
    this.position = 0,
    this.note,
  });

  final String id;
  final String name;
  final String? avatar;
  final bool isDone;
  final int position;
  final String? note;

  factory TaskPerson.fromJson(Map<String, dynamic> json) {
    final user = asMap(json['user']);
    return TaskPerson(
      id: asStringOr(json['userId'] ?? json['id'] ?? user?['id'], ''),
      name: asStringOr(user?['name'] ?? json['name'], 'Сотрудник'),
      avatar: asString(user?['avatar'] ?? json['avatar']),
      isDone: asBool(json['isDone']),
      position: asIntOr(json['position'], 0),
      note: asString(json['note']),
    );
  }
}

class AcceptanceItem {
  const AcceptanceItem({
    required this.id,
    required this.text,
    required this.done,
    this.doneAt,
  });

  final String id;
  final String text;
  final bool done;
  final DateTime? doneAt;

  factory AcceptanceItem.fromJson(Map<String, dynamic> json) => AcceptanceItem(
        id: asStringOr(json['id'], ''),
        text: asStringOr(json['text'], ''),
        done: asBool(json['done'] ?? json['isDone']),
        doneAt: BizDate.parse(json['doneAt']),
      );
}

class TaskModel {
  const TaskModel({
    required this.id,
    required this.title,
    required this.status,
    required this.priority,
    this.description,
    this.projectId,
    this.projectName,
    this.projectType,
    this.assigneeId,
    this.assigneeName,
    this.assigneeAvatar,
    this.createdById,
    this.createdByName,
    this.createdByAvatar,
    this.deadline,
    this.startDate,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
    this.loggedHours = 0,
    this.estimatedHours = 0,
    this.progress = 0,
    this.scope = 'business',
    this.kind = 'task',
    this.location,
    this.fromFounder = false,
    this.repeatWeekly = false,
    this.tags = const [],
    this.acceptanceCriteria = const [],
    this.assignees = const [],
    this.devStage,
  });

  final String id;
  final String title;
  final String status;
  final String priority;
  final String? description;
  final String? projectId;
  final String? projectName;
  final String? projectType;
  final String? assigneeId;
  final String? assigneeName;
  final String? assigneeAvatar;
  final String? createdById;
  final String? createdByName;
  final String? createdByAvatar;
  final DateTime? deadline;
  final DateTime? startDate;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final double loggedHours;
  final double estimatedHours;
  final int progress;
  final String scope;
  final String kind;
  final String? location;
  final bool fromFounder;
  final bool repeatWeekly;
  final List<String> tags;
  final List<AcceptanceItem> acceptanceCriteria;
  final List<TaskPerson> assignees;

  /// Этап доски разработки. Карточка этапа — это не обычное поручение.
  final int? devStage;

  bool get isDevBoardCard => (devStage ?? 0) >= 1;
  bool get isDone => status == 'done';
  bool get isCancelled => status == 'cancelled';
  bool get isClosed => isDone || isCancelled;
  bool get isOverdue =>
      !isClosed && deadline != null && deadline!.isBefore(BizDate.now());
  bool get isDueToday => deadline != null && BizDate.isToday(deadline) && !isClosed;
  bool get isMeeting => kind == 'meeting';
  bool get isPersonal => scope == 'personal';
  bool get isGeneral => scope == 'general';

  String get projectLabel => projectName ?? 'Без проекта';

  String get deadlineLabel => BizDate.deadline(deadline, done: isDone);

  int get checklistDone => acceptanceCriteria.where((item) => item.done).length;
  int get checklistTotal => acceptanceCriteria.length;

  String get assigneeLabel {
    if (assignees.isNotEmpty) {
      if (assignees.length == 1) return assignees.first.name;
      return '${assignees.first.name} +${assignees.length - 1}';
    }
    return assigneeName ?? 'Без исполнителя';
  }

  TaskModel copyWith({
    String? status,
    String? priority,
    DateTime? deadline,
    int? progress,
  }) =>
      TaskModel(
        id: id,
        title: title,
        status: status ?? this.status,
        priority: priority ?? this.priority,
        description: description,
        projectId: projectId,
        projectName: projectName,
        projectType: projectType,
        assigneeId: assigneeId,
        assigneeName: assigneeName,
        assigneeAvatar: assigneeAvatar,
        createdById: createdById,
        createdByName: createdByName,
        createdByAvatar: createdByAvatar,
        deadline: deadline ?? this.deadline,
        startDate: startDate,
        completedAt: completedAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
        loggedHours: loggedHours,
        estimatedHours: estimatedHours,
        progress: progress ?? this.progress,
        scope: scope,
        kind: kind,
        location: location,
        fromFounder: fromFounder,
        repeatWeekly: repeatWeekly,
        tags: tags,
        acceptanceCriteria: acceptanceCriteria,
        assignees: assignees,
        devStage: devStage,
      );

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    final project = asMap(json['project']);
    final assignee = asMap(json['assignee']);
    final createdBy = asMap(json['createdBy']);
    final rawAcceptance = json['acceptanceCriteria'] ?? json['checklist'];
    final acceptance = asList(rawAcceptance)
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .map(AcceptanceItem.fromJson)
        .toList();
    final people = asList(json['assignees'])
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .map(TaskPerson.fromJson)
        .toList();

    var progress = asIntOr(json['progress'], -1);
    if (progress < 0) {
      if (acceptance.isNotEmpty) {
        progress = ((acceptance.where((a) => a.done).length / acceptance.length) * 100).round();
      } else {
        progress = switch (asStringOr(json['status'], 'new')) {
          'done' => 100,
          'in_progress' => 50,
          _ => 0,
        };
      }
    }

    return TaskModel(
      id: asStringOr(json['id'], ''),
      title: asStringOr(json['title'], 'Без названия'),
      status: asStringOr(json['status'], 'new'),
      priority: asStringOr(json['priority'], 'medium'),
      description: asString(json['description']),
      projectId: asString(json['projectId'] ?? project?['id']),
      projectName: asString(project?['name']),
      projectType: asString(project?['projectType']),
      assigneeId: asString(json['assigneeId'] ?? assignee?['id']),
      assigneeName: asString(assignee?['name']),
      assigneeAvatar: asString(assignee?['avatar']),
      createdById: asString(json['createdById'] ?? createdBy?['id']),
      createdByName: asString(createdBy?['name']),
      createdByAvatar: asString(createdBy?['avatar']),
      deadline: BizDate.parse(json['deadline']),
      startDate: BizDate.parse(json['startDate']),
      completedAt: BizDate.parse(json['completedAt']),
      createdAt: BizDate.parse(json['createdAt']),
      updatedAt: BizDate.parse(json['updatedAt']),
      loggedHours: asDoubleOr(json['loggedHours'], 0),
      estimatedHours: asDoubleOr(json['estimatedHours'], 0),
      progress: progress.clamp(0, 100),
      scope: asStringOr(json['scope'], 'business'),
      kind: asStringOr(json['kind'], 'task'),
      location: asString(json['location']),
      fromFounder: asBool(json['fromFounder']),
      repeatWeekly: asBool(json['repeatWeekly']),
      tags: asStringList(json['tags']),
      acceptanceCriteria: acceptance,
      assignees: people,
      devStage: asInt(json['devStage']),
    );
  }
}

class TaskComment {
  const TaskComment({
    required this.id,
    required this.message,
    required this.createdAt,
    this.authorId,
    this.authorName,
    this.authorAvatar,
    this.isEdited = false,
  });

  final String id;
  final String message;
  final DateTime? createdAt;
  final String? authorId;
  final String? authorName;
  final String? authorAvatar;
  final bool isEdited;

  factory TaskComment.fromJson(Map<String, dynamic> json) {
    final author = asMap(json['author']);
    return TaskComment(
      id: asStringOr(json['id'], ''),
      message: asStringOr(json['message'], ''),
      createdAt: BizDate.parse(json['createdAt']),
      authorId: asString(json['authorId'] ?? author?['id']),
      authorName: asString(author?['name']),
      authorAvatar: asString(author?['avatar']),
      isEdited: asBool(json['isEdited']),
    );
  }
}

class TaskResult {
  const TaskResult({
    required this.id,
    required this.type,
    required this.content,
    this.fileName,
    this.filePath,
    this.createdAt,
    this.authorName,
    this.authorAvatar,
  });

  final String id;
  final String type;
  final String content;
  final String? fileName;
  final String? filePath;
  final DateTime? createdAt;
  final String? authorName;
  final String? authorAvatar;

  factory TaskResult.fromJson(Map<String, dynamic> json) {
    final author = asMap(json['submittedBy']);
    return TaskResult(
      id: asStringOr(json['id'], ''),
      type: asStringOr(json['type'], 'comment'),
      content: asStringOr(json['content'], ''),
      fileName: asString(json['fileName']),
      filePath: asString(json['filePath']),
      createdAt: BizDate.parse(json['createdAt']),
      authorName: asString(author?['name']),
      authorAvatar: asString(author?['avatar']),
    );
  }
}

class TaskChecklistItem {
  const TaskChecklistItem({
    required this.id,
    required this.text,
    required this.isDone,
    this.doneAt,
  });

  final String id;
  final String text;
  final bool isDone;
  final DateTime? doneAt;

  factory TaskChecklistItem.fromJson(Map<String, dynamic> json) => TaskChecklistItem(
        id: asStringOr(json['id'], ''),
        text: asStringOr(json['text'], ''),
        isDone: asBool(json['isDone']),
        doneAt: BizDate.parse(json['doneAt']),
      );
}
