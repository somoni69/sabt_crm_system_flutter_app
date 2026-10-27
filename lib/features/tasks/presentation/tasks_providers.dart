import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/snapshot.dart';
import '../../../core/dependencies.dart';
import '../../../core/state/app_state.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/json_utils.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/tasks_repository.dart';
import '../domain/task.dart';
import '../domain/task_file.dart';

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return TasksRepository(ref.watch(dependenciesProvider));
});

enum TaskFeed { mine, management, assigned }

extension TaskFeedX on TaskFeed {
  String get path => switch (this) {
        TaskFeed.mine => '/tasks/my',
        TaskFeed.management => '/tasks/from-management',
        TaskFeed.assigned => '/tasks/assigned-by-me',
      };

  String get label => switch (this) {
        TaskFeed.mine => 'Мои',
        TaskFeed.management => 'От руководства',
        TaskFeed.assigned => 'Я выдал',
      };

  String get cacheKey => 'tasks.$name';
}

List<TaskModel> parseTasks(dynamic raw) {
  final list = raw is List
      ? raw
      : raw is Map && raw['data'] is List
          ? raw['data'] as List
          : const <dynamic>[];
  final tasks = list
      .map(asMap)
      .whereType<Map<String, dynamic>>()
      .map(TaskModel.fromJson)
      .where((task) => task.id.isNotEmpty)
      .toList();
  tasks.sort(_taskOrder);
  return tasks;
}

int _taskOrder(TaskModel a, TaskModel b) {
  int bucket(TaskModel task) {
    if (task.isCancelled) return 4;
    if (task.isDone) return 3;
    if (task.isOverdue) return 0;
    if (task.isDueToday) return 1;
    if (task.deadline != null) return 2;
    return 2;
  }

  final bucketDiff = bucket(a).compareTo(bucket(b));
  if (bucketDiff != 0) return bucketDiff;
  final da = a.deadline;
  final db = b.deadline;
  if (da == null && db == null) return b.createdAt?.compareTo(a.createdAt ?? DateTime(2000)) ?? 0;
  if (da == null) return 1;
  if (db == null) return -1;
  return da.compareTo(db);
}

final tasksProvider = StreamProvider.autoDispose.family<Snapshot<List<TaskModel>>, TaskFeed>(
  (ref, feed) {
    ref.watch(dataRevisionProvider);
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return Stream.value(const Snapshot<List<TaskModel>>(data: []));
    }
    final deps = ref.watch(dependenciesProvider);
    return deps.cachedJson
        .watch(
          userId: user.id,
          key: feed.cacheKey,
          path: feed.path,
        )
        .map((payload) => Snapshot.fromPayload(payload, parseTasks));
  },
);

final projectTasksProvider =
    StreamProvider.autoDispose.family<Snapshot<List<TaskModel>>, String>((ref, projectId) {
  ref.watch(dataRevisionProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value(const Snapshot<List<TaskModel>>(data: []));
  }
  final deps = ref.watch(dependenciesProvider);
  return deps.cachedJson
      .watch(
        userId: user.id,
        key: 'tasks.project.$projectId',
        path: '/tasks',
        query: {'projectId': projectId},
      )
      .map((payload) => Snapshot.fromPayload(payload, parseTasks));
});

final taskProvider =
    StreamProvider.autoDispose.family<Snapshot<TaskModel>, String>((ref, taskId) {
  ref.watch(dataRevisionProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.error(StateError('Не авторизован'));
  }
  final deps = ref.watch(dependenciesProvider);
  return deps.cachedJson
      .watch(
        userId: user.id,
        key: 'task.$taskId',
        path: '/tasks/$taskId',
      )
      .map((payload) => Snapshot.fromPayload(
            payload,
            (raw) => TaskModel.fromJson(asMap(raw) ?? const {}),
          ));
});

final taskCommentsProvider =
    StreamProvider.autoDispose.family<Snapshot<List<TaskComment>>, String>((ref, taskId) {
  ref.watch(dataRevisionProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const Snapshot<List<TaskComment>>(data: []));
  final deps = ref.watch(dependenciesProvider);
  return deps.cachedJson
      .watch(
        userId: user.id,
        key: 'task.$taskId.comments',
        path: '/tasks/$taskId/comments',
      )
      .map((payload) => Snapshot.fromPayload(
            payload,
            (raw) => asList(raw)
                .map(asMap)
                .whereType<Map<String, dynamic>>()
                .map(TaskComment.fromJson)
                .toList(),
          ));
});

final taskResultsProvider =
    StreamProvider.autoDispose.family<Snapshot<List<TaskResult>>, String>((ref, taskId) {
  ref.watch(dataRevisionProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const Snapshot<List<TaskResult>>(data: []));
  final deps = ref.watch(dependenciesProvider);
  return deps.cachedJson
      .watch(
        userId: user.id,
        key: 'task.$taskId.results',
        path: '/tasks/$taskId/results',
      )
      .map((payload) => Snapshot.fromPayload(
            payload,
            (raw) => asList(raw)
                .map(asMap)
                .whereType<Map<String, dynamic>>()
                .map(TaskResult.fromJson)
                .toList(),
          ));
});

final taskChecklistProvider =
    StreamProvider.autoDispose.family<Snapshot<List<TaskChecklistItem>>, String>((ref, taskId) {
  ref.watch(dataRevisionProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value(const Snapshot<List<TaskChecklistItem>>(data: []));
  }
  final deps = ref.watch(dependenciesProvider);
  return deps.cachedJson
      .watch(
        userId: user.id,
        key: 'task.$taskId.checklist',
        path: '/tasks/$taskId/checklist',
      )
      .map((payload) => Snapshot.fromPayload(
            payload,
            (raw) => asList(raw)
                .map(asMap)
                .whereType<Map<String, dynamic>>()
                .map(TaskChecklistItem.fromJson)
                .toList(),
          ));
});

final taskFilesProvider =
    StreamProvider.autoDispose.family<Snapshot<List<TaskFile>>, String>((ref, taskId) {
  ref.watch(dataRevisionProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const Snapshot<List<TaskFile>>(data: []));
  final deps = ref.watch(dependenciesProvider);
  return deps.cachedJson
      .watch(
        userId: user.id,
        key: 'task.$taskId.files',
        path: '/files/task/$taskId',
      )
      .map((payload) => Snapshot.fromPayload(
            payload,
            (raw) => asList(raw)
                .map(asMap)
                .whereType<Map<String, dynamic>>()
                .map(TaskFile.fromJson)
                .toList(),
          ));
});

final taskStatsProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  ref.watch(dataRevisionProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) return const {};
  final deps = ref.watch(dependenciesProvider);
  final raw = await deps.cachedJson.fetch(
    userId: user.id,
    key: 'tasks.stats',
    path: '/tasks/stats',
  );
  final result = <String, int>{};
  if (raw is List) {
    for (final item in raw) {
      final map = asMap(item);
      if (map == null) continue;
      result[asStringOr(map['status'], 'new')] = asIntOr(map['count'], 0);
    }
  }
  return result;
});

final myDayTasksProvider = Provider.autoDispose<List<TaskModel>>((ref) {
  final snapshot = ref.watch(tasksProvider(TaskFeed.mine)).value;
  if (snapshot == null) return const [];
  final today = BizDate.today();
  return snapshot.data.where((task) {
    if (task.isClosed) return false;
    return task.isOverdue || (task.deadline != null && !task.deadline!.isAfter(BizDate.endOfDay(today)));
  }).toList();
});
