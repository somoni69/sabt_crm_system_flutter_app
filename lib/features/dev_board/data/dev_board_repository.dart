import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dependencies.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/dev_task.dart';

class DevBoardRepository {
  DevBoardRepository(this.deps);

  final AppDependencies deps;

  Future<List<DevTask>> getTasks({String? projectId}) async {
    final key = 'dev_board.tasks.${projectId ?? 'all'}';
    final cached = deps.cache.read(key);
    final initialList = asList(cached?.data)
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .map(DevTask.fromJson)
        .toList();

    try {
      final query = <String, dynamic>{
        if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
      };
      final res = await deps.api.getJson('/dev-tracker', query: query);
      final rawList = res is List ? res : (asMap(res)?['data'] as List? ?? const []);
      final tasks = rawList
          .map(asMap)
          .whereType<Map<String, dynamic>>()
          .map(DevTask.fromJson)
          .toList();

      await deps.cache.write(key, rawList);
      return tasks;
    } catch (_) {
      if (initialList.isNotEmpty) return initialList;
      rethrow;
    }
  }

  Future<void> updateStatus(String taskId, String newStatus) async {
    try {
      await deps.api.patchJson('/dev-tracker/$taskId/move', body: {'status': newStatus});
    } catch (_) {
      await deps.api.patchJson('/dev-tracker/$taskId', body: {'status': newStatus});
    }
  }

  Future<void> createTask(Map<String, dynamic> body) async {
    await deps.api.postJson('/dev-tracker', body: body);
  }
}

final devBoardRepositoryProvider = Provider<DevBoardRepository>((ref) {
  return DevBoardRepository(ref.watch(dependenciesProvider));
});
