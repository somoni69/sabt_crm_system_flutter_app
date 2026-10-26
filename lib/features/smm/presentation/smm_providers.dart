import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/snapshot.dart';
import '../../../core/dependencies.dart';
import '../../../core/state/app_state.dart';
import '../../../core/utils/date_range_key.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/json_utils.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/smm_repository.dart';
import '../domain/smm_models.dart';

final smmRepositoryProvider = Provider<SmmRepository>((ref) {
  return SmmRepository(ref.watch(dependenciesProvider));
});

final smmCalendarProvider =
    StreamProvider.autoDispose.family<Snapshot<SmmCalendar>, MonthKey>((ref, month) {
  ref.watch(dataRevisionProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value(
      Snapshot<SmmCalendar>(data: SmmCalendar(
        from: month.start,
        to: month.end,
        events: const [],
        projects: const [],
        backlog: const [],
      )),
    );
  }
  final deps = ref.watch(dependenciesProvider);
  return deps.cachedJson
      .watch(
        userId: user.id,
        key: 'smm.calendar.${month.key}',
        path: '/content-plan/smm-calendar',
        query: {'from': BizDate.key(month.start), 'to': BizDate.key(month.end)},
      )
      .map((payload) => Snapshot.fromPayload(
            payload,
            (raw) => SmmCalendar.fromJson(asMap(raw) ?? const {}),
          ));
});

final storyLogsProvider =
    StreamProvider.autoDispose.family<Snapshot<List<StoryLog>>, DateRangeKey>((ref, range) {
  ref.watch(dataRevisionProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value(const Snapshot<List<StoryLog>>(data: []));
  }
  final deps = ref.watch(dependenciesProvider);
  return deps.cachedJson
      .watch(
        userId: user.id,
        key: 'stories.my.${range.fromKey}.${range.toKey}',
        path: '/stories/my',
        query: {'from': range.fromKey, 'to': range.toKey},
      )
      .map((payload) => Snapshot.fromPayload(
            payload,
            (raw) => asList(raw)
                .map(asMap)
                .whereType<Map<String, dynamic>>()
                .map(StoryLog.fromJson)
                .toList(),
          ));
});

final todayStoryLogsProvider = Provider.autoDispose<List<StoryLog>>((ref) {
  final today = BizDate.today();
  final range = DateRangeKey(today, today);
  return ref.watch(storyLogsProvider(range)).value?.data ?? const [];
});

final todayStoryCountProvider = Provider.autoDispose.family<int, String>((ref, projectId) {
  final logs = ref.watch(todayStoryLogsProvider);
  var total = 0;
  for (final log in logs) {
    if (log.projectId == projectId) total += log.storiesCount;
  }
  return total;
});

final smmProjectsProvider = Provider.autoDispose<List<SmmProject>>((ref) {
  final month = MonthKey.current();
  final snapshot = ref.watch(smmCalendarProvider(month)).value;
  if (snapshot == null) return const [];
  final projects = snapshot.data.projects
      .where((project) => !project.isArchived)
      .toList()
    ..sort((a, b) {
      if (a.mine != b.mine) return a.mine ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  return projects;
});

final storyProjectsProvider = Provider.autoDispose<List<SmmProject>>((ref) {
  return ref.watch(smmProjectsProvider).where((project) => !project.storiesArchived).toList();
});

final smmEventCountsProvider = Provider.autoDispose
    .family<({Map<String, int> reels, Map<String, int> posts, Map<String, int> stories}), MonthKey>(
        (ref, month) {
  final calendar = ref.watch(smmCalendarProvider(month)).value?.data;
  final reels = <String, int>{};
  final posts = <String, int>{};
  final stories = <String, int>{};
  if (calendar == null) {
    return (reels: reels, posts: posts, stories: stories);
  }
  for (final event in calendar.events) {
    final key = BizDate.key(event.date);
    if (event.isStory) {
      stories[key] = (stories[key] ?? 0) + event.count.round();
    } else if (event.isReel) {
      reels[key] = (reels[key] ?? 0) + 1;
    } else if (event.isDesign) {
      posts[key] = (posts[key] ?? 0) + 1;
    }
  }
  return (reels: reels, posts: posts, stories: stories);
});

final planFactProvider =
    FutureProvider.autoDispose.family<List<PlanFactRow>, String>((ref, projectId) async {
  ref.watch(dataRevisionProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  final deps = ref.watch(dependenciesProvider);
  final raw = await deps.cachedJson.fetch(
    userId: user.id,
    key: 'smm.planfact.$projectId',
    path: '/content-plan/plan-fact/$projectId',
  );
  return asList(raw)
      .map(asMap)
      .whereType<Map<String, dynamic>>()
      .map(PlanFactRow.fromJson)
      .toList();
});
