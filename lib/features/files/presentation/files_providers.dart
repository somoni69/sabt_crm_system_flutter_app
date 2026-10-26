import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/app_state.dart';
import '../../projects/presentation/projects_providers.dart';
import '../data/files_repository.dart';
import '../domain/app_file.dart';

class SelectedFileProjectId extends Notifier<String?> {
  @override
  String? build() => null;

  void setProject(String? id) => state = id;
}

final selectedFileProjectIdProvider =
    NotifierProvider<SelectedFileProjectId, String?>(SelectedFileProjectId.new);

final projectFilesProvider = FutureProvider.autoDispose<List<AppFile>>((ref) async {
  ref.watch(dataRevisionProvider);
  final projectId = ref.watch(selectedFileProjectIdProvider);
  if (projectId == null || projectId.isEmpty) {
    final projects = ref.watch(visibleProjectsProvider);
    if (projects.isNotEmpty) {
      return ref.watch(filesRepositoryProvider).getFilesByProject(projects.first.id);
    }
    return const [];
  }
  return ref.watch(filesRepositoryProvider).getFilesByProject(projectId);
});
