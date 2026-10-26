import '../../../core/utils/date_utils.dart';
import '../../../core/utils/json_utils.dart';

class SmmProject {
  const SmmProject({
    required this.id,
    required this.name,
    this.startDate,
    this.endDate,
    this.cycleStartDay,
    this.cycleAnchor,
    this.normReels,
    this.normPosts,
    this.storiesPerMonth,
    this.storiesPerDay,
    this.storiesArchived = false,
    this.isArchived = false,
    this.since,
    this.specialistIds = const [],
    this.mine = false,
    this.autoPlan,
  });

  final String id;
  final String name;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? cycleStartDay;
  final DateTime? cycleAnchor;
  final int? normReels;
  final int? normPosts;
  final int? storiesPerMonth;
  final int? storiesPerDay;
  final bool storiesArchived;
  final bool isArchived;
  final DateTime? since;
  final List<String> specialistIds;
  final bool mine;
  final Map<String, dynamic>? autoPlan;

  int get dailyStoriesTarget {
    final monthNorm = storiesPerMonth;
    if (monthNorm != null) {
      if (monthNorm <= 0) return 0;
      final days = BizDate.daysInMonth(BizDate.today());
      return (monthNorm / days).round().clamp(1, 30);
    }
    return storiesPerDay ?? 3;
  }

  factory SmmProject.fromJson(Map<String, dynamic> json) => SmmProject(
        id: asStringOr(json['id'], ''),
        name: asStringOr(json['name'], 'Проект'),
        startDate: BizDate.parse(json['startDate']),
        endDate: BizDate.parse(json['endDate']),
        cycleStartDay: asInt(json['cycleStartDay']),
        cycleAnchor: BizDate.parse(json['cycleAnchor']),
        normReels: asInt(json['normReels']),
        normPosts: asInt(json['normPosts']),
        storiesPerMonth: asInt(json['storiesPerMonth']),
        storiesPerDay: asInt(json['storiesPerDay']),
        storiesArchived: asBool(json['storiesArchived']),
        isArchived: asBool(json['isArchived']),
        since: BizDate.parse(json['since']),
        specialistIds: asStringList(json['specialistIds']),
        mine: asBool(json['mine']),
        autoPlan: asMap(json['autoPlan']),
      );
}

class SmmEvent {
  const SmmEvent({
    required this.id,
    required this.kind,
    required this.date,
    required this.projectId,
    required this.projectName,
    this.itemId,
    this.shootId,
    this.contentType,
    this.kindLabel,
    this.topic,
    this.scriptText,
    this.status,
    this.time,
    this.durationMin,
    this.assigneeId,
    this.taskId,
    this.prepStage,
    this.reelId,
    this.reelDate,
    this.parentKind,
    this.count = 0,
    this.location,
    this.note,
    this.changedAt,
    this.fileLink,
  });

  final String id;

  /// `publication` or `shoot`.
  final String kind;
  final DateTime date;
  final String projectId;
  final String projectName;
  final String? itemId;
  final String? shootId;
  final String? contentType;
  final String? kindLabel;

  /// Human label for legacy shoot sessions ("Съёмка", custom title).
  final String? topic;
  final String? scriptText;
  final String? status;
  final String? time;
  final int? durationMin;
  final String? assigneeId;
  final String? taskId;
  final String? prepStage;
  final String? reelId;
  final DateTime? reelDate;
  final String? parentKind;
  final int count;
  final String? location;
  final String? note;
  final DateTime? changedAt;
  final String? fileLink;

  bool get isStory => contentType == 'story';
  bool get isReel => contentType == 'reel';
  bool get isDesign => contentType == 'design';
  bool get isShootSession => kind == 'shoot' && prepStage == null && itemId == null;
  bool get isPrep => prepStage != null;
  bool get isDone => status == 'published' || status == 'done';

  String get contentTypeLabel {
    if (isStory) return 'Сторис';
    if (isReel) return 'Рилс';
    if (isDesign) return 'Макет';
    if (isShootSession) return 'Съёмка';
    return 'Контент';
  }

  String get prepLabel => switch (prepStage) {
        'shoot' => 'Съёмка',
        'edit' => 'Монтаж',
        'design' => 'Дизайн',
        _ => '',
      };

  String get displayTitle {
    final value = topic?.trim();
    if (value != null && value.isNotEmpty) return value;
    if (isShootSession) return 'Съёмка';
    return contentTypeLabel;
  }

  String get timeLabel {
    final value = time;
    if (value != null && value.isNotEmpty) return value;
    if (BizDate.isMidnight(date)) return '';
    return BizDate.time(date);
  }

  factory SmmEvent.fromJson(Map<String, dynamic> json) => SmmEvent(
        id: asStringOr(json['id'], ''),
        kind: asStringOr(json['kind'], 'publication'),
        date: BizDate.parse(json['date']) ?? BizDate.now(),
        projectId: asStringOr(json['projectId'], ''),
        projectName: asStringOr(json['projectName'], 'Проект'),
        itemId: asString(json['itemId']),
        shootId: asString(json['shootId']),
        contentType: asString(json['contentType']),
        kindLabel: asString(json['kind']),
        topic: asString(json['topic'] ?? json['title']),
        scriptText: asString(json['scriptText']),
        status: asString(json['status']),
        time: asString(json['time']),
        durationMin: asInt(json['durationMin']),
        assigneeId: asString(json['assigneeId']),
        taskId: asString(json['taskId']),
        prepStage: asString(json['prepStage']),
        reelId: asString(json['reelId']),
        reelDate: BizDate.parse(json['reelDate']),
        parentKind: asString(json['parentKind']),
        count: asIntOr(json['count'], 0),
        location: asString(json['location']),
        note: asString(json['note']),
        changedAt: BizDate.parse(json['changedAt']),
        fileLink: asString(json['fileLink']),
      );
}

class SmmBacklogItem {
  const SmmBacklogItem({
    required this.id,
    required this.kind,
    required this.projectId,
    required this.projectName,
    this.itemId,
    this.shootId,
    this.contentType,
    this.topic,
    this.scriptText,
    this.prepStage,
    this.reelId,
    this.reelDate,
    this.location,
    this.changedAt,
    this.fileLink,
  });

  final String id;
  final String kind;
  final String projectId;
  final String projectName;
  final String? itemId;
  final String? shootId;
  final String? contentType;
  final String? topic;
  final String? scriptText;
  final String? prepStage;
  final String? reelId;
  final DateTime? reelDate;
  final String? location;
  final DateTime? changedAt;
  final String? fileLink;

  bool get isShoot => kind == 'shoot';

  String get contentTypeLabel {
    if (isShoot) return 'Съёмка';
    return contentType == 'reel' ? 'Рилс' : 'Макет';
  }

  String get displayTitle {
    final value = topic?.trim();
    return value == null || value.isEmpty ? contentTypeLabel : value;
  }

  factory SmmBacklogItem.fromJson(Map<String, dynamic> json) => SmmBacklogItem(
        id: asStringOr(json['id'], ''),
        kind: asStringOr(json['kind'], 'publication'),
        projectId: asStringOr(json['projectId'], ''),
        projectName: asStringOr(json['projectName'], 'Проект'),
        itemId: asString(json['itemId']),
        shootId: asString(json['shootId']),
        contentType: asString(json['contentType']),
        topic: asString(json['topic'] ?? json['title']),
        scriptText: asString(json['scriptText']),
        prepStage: asString(json['prepStage']),
        reelId: asString(json['reelId']),
        reelDate: BizDate.parse(json['reelDate']),
        location: asString(json['location']),
        changedAt: BizDate.parse(json['changedAt']),
        fileLink: asString(json['fileLink']),
      );
}

class SmmCalendar {
  const SmmCalendar({
    required this.from,
    required this.to,
    required this.events,
    required this.projects,
    required this.backlog,
    this.colorIds = const [],
  });

  final DateTime from;
  final DateTime to;
  final List<SmmEvent> events;
  final List<SmmProject> projects;
  final List<SmmBacklogItem> backlog;
  final List<String> colorIds;

  List<SmmEvent> eventsOn(DateTime day) =>
      events.where((event) => BizDate.isSameDay(event.date, day)).toList()
        ..sort((a, b) {
          if (a.time == null && b.time != null) return -1;
          if (a.time != null && b.time == null) return 1;
          return (a.time ?? '').compareTo(b.time ?? '');
        });

  SmmProject? projectOf(String projectId) {
    for (final project in projects) {
      if (project.id == projectId) return project;
    }
    return null;
  }

  factory SmmCalendar.fromJson(Map<String, dynamic> json) => SmmCalendar(
        from: BizDate.parse(json['from']) ?? BizDate.monthStart(BizDate.today()),
        to: BizDate.parse(json['to']) ?? BizDate.monthEnd(BizDate.today()),
        events: asList(json['events'])
            .map(asMap)
            .whereType<Map<String, dynamic>>()
            .map(SmmEvent.fromJson)
            .toList(),
        projects: asList(json['projects'])
            .map(asMap)
            .whereType<Map<String, dynamic>>()
            .map(SmmProject.fromJson)
            .toList(),
        backlog: asList(json['backlog'])
            .map(asMap)
            .whereType<Map<String, dynamic>>()
            .map(SmmBacklogItem.fromJson)
            .toList(),
        colorIds: asStringList(json['colorIds']),
      );
}

class StoryLog {
  const StoryLog({
    required this.id,
    required this.projectId,
    required this.date,
    required this.storiesCount,
    this.projectName,
    this.employeeId,
    this.employeeName,
    this.employeeAvatar,
  });

  final String id;
  final String projectId;
  final DateTime date;
  final int storiesCount;
  final String? projectName;
  final String? employeeId;
  final String? employeeName;
  final String? employeeAvatar;

  factory StoryLog.fromJson(Map<String, dynamic> json) {
    final project = asMap(json['project']);
    final employee = asMap(json['employee']);
    return StoryLog(
      id: asStringOr(json['id'], ''),
      projectId: asStringOr(json['projectId'] ?? project?['id'], ''),
      date: BizDate.parse(json['date']) ?? BizDate.today(),
      storiesCount: asIntOr(json['storiesCount'], 0),
      projectName: asString(project?['name']),
      employeeId: asString(json['employeeId'] ?? employee?['id']),
      employeeName: asString(employee?['name']),
      employeeAvatar: asString(employee?['avatar']),
    );
  }
}

class PlanFactRow {
  const PlanFactRow({
    required this.contentType,
    required this.planned,
    required this.published,
    required this.cancelled,
    required this.remaining,
  });

  final String contentType;
  final int planned;
  final int published;
  final int cancelled;
  final int remaining;

  String get label => switch (contentType) {
        'reel' => 'Рилсы',
        'post' => 'Посты',
        'story' => 'Сторис',
        'design' => 'Макеты',
        'video' => 'Видео',
        'carousel' => 'Карусели',
        _ => contentType,
      };

  factory PlanFactRow.fromJson(Map<String, dynamic> json) => PlanFactRow(
        contentType: asStringOr(json['contentType'], 'other'),
        planned: asIntOr(json['planned'], 0),
        published: asIntOr(json['published'], 0),
        cancelled: asIntOr(json['cancelled'], 0),
        remaining: asIntOr(json['remaining'], 0),
      );
}
