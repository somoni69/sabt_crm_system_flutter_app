import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dependencies.dart';
import '../../../core/state/app_state.dart';
import '../../projects/domain/project.dart';
import '../../projects/presentation/projects_providers.dart';

class ArchiveFilterType extends Notifier<String> {
  @override
  String build() => '';

  void setType(String type) => state = type;
}

final archiveFilterTypeProvider =
    NotifierProvider<ArchiveFilterType, String>(ArchiveFilterType.new);

final archivedProjectsProvider = FutureProvider.autoDispose<List<ProjectModel>>((ref) async {
  ref.watch(dataRevisionProvider);
  final deps = ref.watch(dependenciesProvider);
  final res = await deps.api.getJson('/projects', query: {'archived': 'true'});
  return parseProjects(res);
});
