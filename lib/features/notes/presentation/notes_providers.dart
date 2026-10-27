import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/app_state.dart';
import '../data/notes_repository.dart';
import '../domain/note.dart';

class SelectedNoteDate extends Notifier<String?> {
  @override
  String? build() => null;

  void setDate(String? d) => state = d;
}

final selectedNoteDateProvider =
    NotifierProvider<SelectedNoteDate, String?>(SelectedNoteDate.new);

final myNotesProvider = FutureProvider.autoDispose<List<Note>>((ref) async {
  ref.watch(dataRevisionProvider);
  final repo = ref.watch(notesRepositoryProvider);
  return repo.getNotes();
});
