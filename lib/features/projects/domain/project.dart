import '../../../core/utils/date_utils.dart';
import '../../../core/utils/json_utils.dart';

class ProjectPerson {
  const ProjectPerson({
    required this.id,
    required this.name,
    this.avatar,
    this.position,
  });

  final String id;
  final String name;
  final String? avatar;
  final String? position;

  factory ProjectPerson.fromJson(Map<String, dynamic> json) => ProjectPerson(
        id: asStringOr(json['id'], ''),
        name: asStringOr(json['name'], 'Сотрудник'),
        avatar: asString(json['avatar']),
        position: asString(json['position']),
      );
}

class ProjectModel {
  const ProjectModel({
    required this.id,
    required this.name,
    required this.status,
    this.description,
    this.projectType = 'SMM',
    this.progress = 0,
    this.startDate,
    this.endDate,
    this.manager,
    this.salesManager,
    this.members = const [],
    this.membersCount = 0,
    this.taskCount = 0,
    this.doneTaskCount = 0,
    this.isArchived = false,
    this.hasActiveAd = false,
    this.lastActivityAt,
    this.createdAt,
    this.tariffNameSnapshot,
    this.monthlyFee,
    this.budget,
    this.paidAmount,
    this.paymentStatus,
    this.nextPaymentDate,
    this.lastPaymentAt,
    this.billingType,
    this.smmData,
  });

  final String id;
  final String name;
  final String status;
  final String? description;
  final String projectType;
  final int progress;
  final DateTime? startDate;
  final DateTime? endDate;
  final ProjectPerson? manager;
  final ProjectPerson? salesManager;
  final List<ProjectPerson> members;
  final int membersCount;
  final int taskCount;
  final int doneTaskCount;
  final bool isArchived;
  final bool hasActiveAd;
  final DateTime? lastActivityAt;
  final DateTime? createdAt;
  final String? tariffNameSnapshot;
  final double? monthlyFee;
  final double? budget;
  final double? paidAmount;
  final String? paymentStatus;
  final DateTime? nextPaymentDate;
  final DateTime? lastPaymentAt;
  final String? billingType;
  final Map<String, dynamic>? smmData;

  bool get isSmm => projectType == 'SMM';
  bool get isDev => const ['Web сайт', 'Лендинг', 'Телеграм бот', 'CRM система', 'Интернет магазин', 'Разработка']
      .contains(projectType);

  String get typeLabel => switch (projectType) {
        'SMM' => 'SMM',
        'Лендинг' => 'Лендинг',
        'Телеграм бот' => 'Telegram-бот',
        'CRM система' => 'CRM',
        'Интернет магазин' => 'Магазин',
        'Web сайт' => 'Web-сайт',
        'Дизайн' => 'Дизайн',
        _ => projectType,
      };

  String get statusFieldLabel => switch (status) {
        'planning' => 'Планируется',
        'in_progress' => 'В работе',
        'completed' => 'Завершён',
        'on_hold' => 'На паузе',
        'archived' => 'Архив',
        _ => status,
      };

  int? get normReels {
    final value = smmData?['normReels'];
    return value is num ? value.round() : int.tryParse('$value');
  }

  int? get normPosts {
    final value = smmData?['normPosts'];
    return value is num ? value.round() : int.tryParse('$value');
  }

  int? get storiesPerMonth {
    final value = smmData?['storiesPerMonth'];
    return value is num ? value.round() : int.tryParse('$value');
  }

  bool get storiesArchived => asBool(smmData?['storiesArchived'] ?? false);

  List<String> get specialistIds => asStringList(smmData?['smmSpecialistIds']);

  double get taskCompletion =>
      taskCount == 0 ? 0 : (doneTaskCount / taskCount).clamp(0, 1).toDouble();

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    final manager = asMap(json['manager']);
    final salesManager = asMap(json['salesManager']);
    final members = asList(json['members'])
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .map(ProjectPerson.fromJson)
        .toList();
    final smm = asMap(json['smmData']);

    return ProjectModel(
      id: asStringOr(json['id'], ''),
      name: asStringOr(json['name'], 'Проект'),
      status: asStringOr(json['status'], 'planning'),
      description: asString(json['description']),
      projectType: asStringOr(json['projectType'], 'SMM'),
      progress: asIntOr(json['progress'], 0).clamp(0, 100),
      startDate: BizDate.parse(json['startDate']),
      endDate: BizDate.parse(json['endDate']),
      manager: manager == null ? null : ProjectPerson.fromJson(manager),
      salesManager: salesManager == null ? null : ProjectPerson.fromJson(salesManager),
      members: members,
      membersCount: asIntOr(json['membersCount'], members.length),
      taskCount: asIntOr(json['taskCount'], 0),
      doneTaskCount: asIntOr(json['doneTaskCount'], 0),
      isArchived: asBool(json['isArchived']),
      hasActiveAd: asBool(json['hasActiveAd']),
      lastActivityAt: BizDate.parse(json['lastActivityAt']),
      createdAt: BizDate.parse(json['createdAt']),
      tariffNameSnapshot: asString(json['tariffNameSnapshot']),
      monthlyFee: asDouble(json['monthlyFee']),
      budget: asDouble(json['budget']),
      paidAmount: asDouble(json['paidAmount']),
      paymentStatus: asString(json['paymentStatus']),
      nextPaymentDate: BizDate.parse(json['nextPaymentDate']),
      lastPaymentAt: BizDate.parse(json['lastPaymentAt']),
      billingType: asString(json['billingType']),
      smmData: smm,
    );
  }
}

class ProjectStats {
  const ProjectStats({required this.byStatus, required this.total, required this.active});

  final Map<String, int> byStatus;
  final int total;
  final int active;

  factory ProjectStats.fromJson(dynamic data) {
    final byStatus = <String, int>{};
    if (data is List) {
      for (final item in data) {
        final map = asMap(item);
        if (map == null) continue;
        byStatus[asStringOr(map['status'], 'unknown')] = asIntOr(map['count'], 0);
      }
    }
    final active = (byStatus['in_progress'] ?? 0) + (byStatus['planning'] ?? 0);
    return ProjectStats(
      byStatus: byStatus,
      total: byStatus.values.fold(0, (a, b) => a + b),
      active: active,
    );
  }
}
