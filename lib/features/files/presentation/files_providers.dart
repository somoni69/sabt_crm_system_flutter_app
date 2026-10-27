import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/app_state.dart';
import '../data/files_repository.dart';
import '../domain/app_file.dart';

class SelectedFileProjectId extends Notifier<String?> {
  @override
  String? build() => null;

  void setProject(String? id) => state = id;
}

final selectedFileProjectIdProvider =
    NotifierProvider<SelectedFileProjectId, String?>(SelectedFileProjectId.new);

/// Files of one project, keyed by project id.
///
/// A cache-first stream, not a one-shot future: the Hive snapshot
/// renders instantly and the network refresh lands on top of it, so
/// returning to this page never shows a spinner. Family-keyed so
/// switching projects never flashes the previous project's files while
/// the next list loads — each project keeps its own state. Deliberately
/// not `autoDispose`: leaving and re-entering the page must not throw
/// the list away and start the network round-trip over.
final projectFilesProvider = StreamProvider.family<List<AppFile>, String>((
  ref,
  projectId,
) {
  ref.watch(dataRevisionProvider);
  return ref.watch(filesRepositoryProvider).watchFilesByProject(projectId);
});
