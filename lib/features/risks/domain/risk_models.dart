import '../../../core/utils/json_utils.dart';

class RiskFactor {
  const RiskFactor({
    required this.key,
    required this.label,
    required this.triggered,
    this.detail,
  });

  final String key;
  final String label;
  final bool triggered;
  final String? detail;

  factory RiskFactor.fromJson(Map<String, dynamic> json) => RiskFactor(
        key: asStringOr(json['key'], ''),
        label: asStringOr(json['label'], ''),
        triggered: asBool(json['triggered']),
        detail: asString(json['detail']),
      );
}

class ProjectRisk {
  const ProjectRisk({
    required this.projectId,
    required this.projectName,
    this.managerName,
    this.level = 'green',
    this.score = 0,
    this.factors = const [],
  });

  final String projectId;
  final String projectName;
  final String? managerName;
  final String level; // green, yellow, red
  final int score;
  final List<RiskFactor> factors;

  factory ProjectRisk.fromJson(Map<String, dynamic> json) => ProjectRisk(
        projectId: asStringOr(json['projectId'], ''),
        projectName: asStringOr(json['projectName'], 'Проект'),
        managerName: asString(json['managerName']),
        level: asStringOr(json['level'], 'green'),
        score: asIntOr(json['score'], 0),
        factors: asList(json['factors'])
            .map(asMap)
            .whereType<Map<String, dynamic>>()
            .map(RiskFactor.fromJson)
            .toList(),
      );
}

class EmployeeWorkload {
  const EmployeeWorkload({
    required this.userId,
    required this.userName,
    required this.role,
    this.projectCount = 0,
    this.tasksInProgress = 0,
    this.tasksInQueue = 0,
    this.overload = 'green',
  });

  final String userId;
  final String userName;
  final String role;
  final int projectCount;
  final int tasksInProgress;
  final int tasksInQueue;
  final String overload; // green, yellow, red

  factory EmployeeWorkload.fromJson(Map<String, dynamic> json) => EmployeeWorkload(
        userId: asStringOr(json['userId'], ''),
        userName: asStringOr(json['userName'], 'Сотрудник'),
        role: asStringOr(json['role'], ''),
        projectCount: asIntOr(json['projectCount'], 0),
        tasksInProgress: asIntOr(json['tasksInProgress'], 0),
        tasksInQueue: asIntOr(json['tasksInQueue'], 0),
        overload: asStringOr(json['overload'], 'green'),
      );
}
