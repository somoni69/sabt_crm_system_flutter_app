import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/snapshot.dart';
import '../../../core/dependencies.dart';
import '../../../core/state/app_state.dart';
import '../../../core/utils/json_utils.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/project.dart';

List<ProjectModel> parseProjects(dynamic raw) {
  final list = raw is List
      ? raw
      : raw is Map && raw['data'] is List
          ? raw['data'] as List
          : const <dynamic>[];
  final projects = list
      .map(asMap)
      .whereType<Map<String, dynamic>>()
      .map(ProjectModel.fromJson)
      .where((project) => project.id.isNotEmpty)
      .toList();
  projects.sort((a, b) {
    final archived = a.isArchived == b.isArchived ? 0 : (a.isArchived ? 1 : -1);
    if (archived != 0) return archived;
    final statusA = a.status == 'in_progress' ? 0 : (a.status == 'planning' ? 1 : 2);
    final statusB = b.status == 'in_progress' ? 0 : (b.status == 'planning' ? 1 : 2);
    if (statusA != statusB) return statusA.compareTo(statusB);
    return (b.lastActivityAt ?? b.createdAt ?? DateTime(2000))
        .compareTo(a.lastActivityAt ?? a.createdAt ?? DateTime(2000));
  });
  return projects;
}

final projectsProvider =
    StreamProvider.autoDispose<Snapshot<List<ProjectModel>>>((ref) {
  ref.watch(dataRevisionProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value(const Snapshot<List<ProjectModel>>(data: []));
  }
  final deps = ref.watch(dependenciesProvider);
  return deps.cachedJson
      .watch(
        userId: user.id,
        key: 'projects.all',
        path: '/projects',
      )
      .map((payload) => Snapshot.fromPayload(payload, parseProjects));
});

final projectProvider =
    StreamProvider.autoDispose.family<Snapshot<ProjectModel>, String>((ref, projectId) {
  ref.watch(dataRevisionProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.error(StateError('Не авторизован'));
  }
  final deps = ref.watch(dependenciesProvider);
  return deps.cachedJson
      .watch(
        userId: user.id,
        key: 'project.$projectId',
        path: '/projects/$projectId',
      )
      .map((payload) => Snapshot.fromPayload(
            payload,
            (raw) => ProjectModel.fromJson(asMap(raw) ?? const {}),
          ));
});

final projectStatsProvider = FutureProvider.autoDispose<ProjectStats>((ref) async {
  ref.watch(dataRevisionProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) return ProjectStats.fromJson(const <dynamic>[]);
  final deps = ref.watch(dependenciesProvider);
  final raw = await deps.cachedJson.fetch(
    userId: user.id,
    key: 'projects.stats',
    path: '/projects/stats',
  );
  return ProjectStats.fromJson(raw);
});

final visibleProjectsProvider = Provider.autoDispose<List<ProjectModel>>((ref) {
  return ref.watch(projectsProvider).value?.data ?? const [];
});
