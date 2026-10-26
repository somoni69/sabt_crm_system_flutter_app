import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dependencies.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/state/app_state.dart';
import '../../../core/utils/date_range_key.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/json_utils.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../smm/domain/smm_models.dart';
import '../../smm/presentation/smm_providers.dart';

class CompanyPulse {
  const CompanyPulse({
    this.totalProjects = 0,
    this.activeProjects = 0,
    this.totalTasks = 0,
    this.doneTasks = 0,
    this.completionRate = 0,
    this.totalUsers = 0,
    this.overdueTasks = 0,
    this.hoursThisMonth = 0,
    this.tasksByStatus = const {},
    this.projectsByStatus = const {},
  });

  final int totalProjects;
  final int activeProjects;
  final int totalTasks;
  final int doneTasks;
  final int completionRate;
  final int totalUsers;
  final int overdueTasks;
  final double hoursThisMonth;
  final Map<String, int> tasksByStatus;
  final Map<String, int> projectsByStatus;

  factory CompanyPulse.fromJson(dynamic raw) {
    final map = asMap(raw) ?? const {};
    final overview = asMap(map['overview']) ?? map;
    final tasks = <String, int>{};
    for (final item in asList(map['taskByStatus'])) {
      final row = asMap(item);
      if (row == null) continue;
      tasks[asStringOr(row['status'], 'new')] = asIntOr(row['count'], 0);
    }
    final projects = <String, int>{};
    for (final item in asList(map['projByStatus'])) {
      final row = asMap(item);
      if (row == null) continue;
      projects[asStringOr(row['status'], 'planning')] = asIntOr(row['count'], 0);
    }
    return CompanyPulse(
      totalProjects: asIntOr(overview['totalProjects'], 0),
      activeProjects: asIntOr(overview['activeProjects'], 0),
      totalTasks: asIntOr(overview['totalTasks'], 0),
      doneTasks: asIntOr(overview['doneTasks'], 0),
      completionRate: asIntOr(overview['completionRate'], 0),
      totalUsers: asIntOr(overview['totalUsers'], 0),
      overdueTasks: asIntOr(overview['overdueTasks'], 0),
      hoursThisMonth: asDoubleOr(overview['hoursThisMonth'], 0),
      tasksByStatus: tasks,
      projectsByStatus: projects,
    );
  }
}

final companyPulseProvider = FutureProvider.autoDispose<CompanyPulse?>((ref) async {
  ref.watch(dataRevisionProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null || !userCan(user, Perm.analyticsView)) return null;
  final deps = ref.watch(dependenciesProvider);
  try {
    final raw = await deps.cachedJson.fetch(
      userId: user.id,
      key: 'analytics.dashboard',
      path: '/analytics/dashboard',
    );
    return CompanyPulse.fromJson(raw);
  } catch (_) {
    return null;
  }
});

final todaySmmEventsProvider = Provider.autoDispose<List<SmmEvent>>((ref) {
  final month = MonthKey.current();
  final calendar = ref.watch(smmCalendarProvider(month)).value?.data;
  if (calendar == null) return const [];
  return calendar.eventsOn(BizDate.today());
});

final todayProductionItemsProvider = Provider.autoDispose<List<SmmEvent>>((ref) {
  return ref
      .watch(todaySmmEventsProvider)
      .where((event) => !event.isStory)
      .toList();
});

final dashboardStoryProjectsProvider = Provider.autoDispose<List<SmmProject>>((ref) {
  final projects = ref.watch(storyProjectsProvider);
  final withNorm = projects.where((project) => project.dailyStoriesTarget > 0).toList();
  return withNorm.take(4).toList();
});

final dashboardStoryRangeProvider = Provider.autoDispose<DateRangeKey>((ref) {
  final today = BizDate.today();
  return DateRangeKey(today, today);
});
