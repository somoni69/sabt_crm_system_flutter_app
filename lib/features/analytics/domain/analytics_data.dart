import '../../../core/utils/json_utils.dart';

class AnalyticsOverview {
  const AnalyticsOverview({
    this.totalProjects = 0,
    this.activeProjects = 0,
    this.totalTasks = 0,
    this.doneTasks = 0,
    this.completionRate = 0,
    this.totalEmployees = 0,
    this.overdueTasks = 0,
    this.hoursThisMonth = 0,
  });

  final int totalProjects;
  final int activeProjects;
  final int totalTasks;
  final int doneTasks;
  final int completionRate;
  final int totalEmployees;
  final int overdueTasks;
  final double hoursThisMonth;

  factory AnalyticsOverview.fromJson(Map<String, dynamic> json) => AnalyticsOverview(
        totalProjects: asIntOr(json['totalProjects'], 0),
        activeProjects: asIntOr(json['activeProjects'], 0),
        totalTasks: asIntOr(json['totalTasks'], 0),
        doneTasks: asIntOr(json['doneTasks'], 0),
        completionRate: asIntOr(json['completionRate'], 0),
        totalEmployees: asIntOr(json['totalEmployees'] ?? json['totalUsers'], 0),
        overdueTasks: asIntOr(json['overdueTasks'], 0),
        hoursThisMonth: asDoubleOr(json['hoursThisMonth'], 0),
      );
}

class StatusCount {
  const StatusCount({required this.status, required this.count});

  final String status;
  final int count;

  factory StatusCount.fromJson(Map<String, dynamic> json) => StatusCount(
        status: asStringOr(json['status'], ''),
        count: asIntOr(json['count'], 0),
      );
}

class PriorityCount {
  const PriorityCount({required this.priority, required this.count});

  final String priority;
  final int count;

  factory PriorityCount.fromJson(Map<String, dynamic> json) => PriorityCount(
        priority: asStringOr(json['priority'], ''),
        count: asIntOr(json['count'], 0),
      );
}

class EmployeeStat {
  const EmployeeStat({
    required this.id,
    required this.name,
    this.avatar,
    this.completedTasks = 0,
    this.loggedHours = 0,
  });

  final String id;
  final String name;
  final String? avatar;
  final int completedTasks;
  final double loggedHours;

  factory EmployeeStat.fromJson(Map<String, dynamic> json) => EmployeeStat(
        id: asStringOr(json['id'] ?? json['employeeId'] ?? json['userId'], ''),
        name: asStringOr(json['name'] ?? json['userName'], 'Сотрудник'),
        avatar: asString(json['avatar']),
        completedTasks: asIntOr(json['completedTasks'] ?? json['doneTasks'] ?? json['tasksCount'], 0),
        loggedHours: asDoubleOr(json['loggedHours'] ?? json['hours'], 0),
      );
}

class AnalyticsDashboardData {
  const AnalyticsDashboardData({
    required this.overview,
    this.projectsByStatus = const [],
    this.tasksByStatus = const [],
    this.tasksByPriority = const [],
    this.employeeActivity = const [],
  });

  final AnalyticsOverview overview;
  final List<StatusCount> projectsByStatus;
  final List<StatusCount> tasksByStatus;
  final List<PriorityCount> tasksByPriority;
  final List<EmployeeStat> employeeActivity;

  factory AnalyticsDashboardData.fromJson(Map<String, dynamic> json) {
    final overviewMap = asMap(json['overview']) ?? const <String, dynamic>{};
    return AnalyticsDashboardData(
      overview: AnalyticsOverview.fromJson(overviewMap),
      projectsByStatus: asList(json['projByStatus'] ?? json['projectsByStatus'])
          .map(asMap)
          .whereType<Map<String, dynamic>>()
          .map(StatusCount.fromJson)
          .toList(),
      tasksByStatus: asList(json['taskByStatus'] ?? json['tasksByStatus'])
          .map(asMap)
          .whereType<Map<String, dynamic>>()
          .map(StatusCount.fromJson)
          .toList(),
      tasksByPriority: asList(json['taskByPriority'] ?? json['tasksByPriority'])
          .map(asMap)
          .whereType<Map<String, dynamic>>()
          .map(PriorityCount.fromJson)
          .toList(),
      employeeActivity: asList(json['empActivity'] ?? json['employeeActivity'] ?? json['empEff'])
          .map(asMap)
          .whereType<Map<String, dynamic>>()
          .map(EmployeeStat.fromJson)
          .toList(),
    );
  }
}
