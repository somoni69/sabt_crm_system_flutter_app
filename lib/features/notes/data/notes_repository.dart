import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dependencies.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/note.dart';

class NotesRepository {
  NotesRepository(this.deps);

  final AppDependencies deps;

  Future<List<Note>> getNotes() async {
    const key = 'my_notes.list';
    final cached = deps.cache.read(key);
    final initialList = asList(cached?.data)
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .map(Note.fromJson)
        .toList();

    try {
      final res = await deps.api.getJson('/my-notes');
      final rawList = res is List ? res : (asMap(res)?['data'] as List? ?? const []);
      final notes = rawList
          .map(asMap)
          .whereType<Map<String, dynamic>>()
          .map(Note.fromJson)
          .toList();

      await deps.cache.write(key, rawList);
      return notes;
    } catch (_) {
      if (initialList.isNotEmpty) return initialList;
      rethrow;
    }
  }

  Future<Note> createNote({required String text, String? date}) async {
    final res = await deps.api.postJson('/my-notes', body: {
      'text': text,
      if (date != null && date.isNotEmpty) 'date': date,
    });
    final map = asMap(res) ?? const <String, dynamic>{};
    return Note.fromJson(map);
  }

  Future<Note> updateNote({
    required String id,
    String? text,
    String? date,
    bool? done,
  }) async {
    final body = <String, dynamic>{};
    if (text != null) body['text'] = text;
    if (date != null) body['date'] = date;
    if (done != null) body['done'] = done;
    final res = await deps.api.patchJson('/my-notes/$id', body: body);
    final map = asMap(res) ?? const <String, dynamic>{};
    return Note.fromJson(map);
  }

  Future<void> deleteNote(String id) async {
    await deps.api.deleteJson('/my-notes/$id');
  }
}

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepository(ref.watch(dependenciesProvider));
});
