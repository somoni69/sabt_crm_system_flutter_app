import '../../../core/dependencies.dart';
import '../../../core/utils/date_utils.dart';

class TasksRepository {
  TasksRepository(this.deps);

  final AppDependencies deps;

  Future<void> updateStatus(String taskId, String status) async {
    await deps.api.patchJson('/tasks/$taskId', body: {'status': status});
  }

  Future<void> updateTask(String taskId, Map<String, dynamic> body) async {
    await deps.api.patchJson('/tasks/$taskId', body: body);
  }

  Future<Map<String, dynamic>> createTask(Map<String, dynamic> body) async {
    final data = await deps.api.postJson('/tasks', body: body);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<void> markMyPartDone(String taskId, {String? note}) async {
    await deps.api.postJson('/tasks/$taskId/my-part-done', body: {
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  Future<void> approve(String taskId) async {
    await deps.api.postJson('/tasks/$taskId/approve');
  }

  Future<void> returnTask(String taskId, String reason) async {
    await deps.api.postJson('/tasks/$taskId/return', body: {'reason': reason});
  }

  Future<void> addComment(String taskId, String message) async {
    await deps.api.postJson('/tasks/$taskId/comments', body: {'message': message});
  }

  Future<void> addResult(
    String taskId, {
    required String type,
    required String content,
    String? fileName,
    String? filePath,
  }) async {
    await deps.api.postJson('/tasks/$taskId/results', body: {
      'type': type,
      'content': content,
      'fileName': ?fileName,
      'filePath': ?filePath,
    });
  }

  Future<void> addChecklistItem(String taskId, String text) async {
    await deps.api.postJson('/tasks/$taskId/checklist', body: {'text': text});
  }

  Future<void> toggleChecklistItem(String taskId, String itemId) async {
    await deps.api.patchJson('/tasks/$taskId/checklist/$itemId/toggle');
  }

  Future<Map<String, dynamic>> uploadTaskFile(
    String taskId, {
    required List<int> bytes,
    required String filename,
  }) async {
    final data = await deps.api.uploadBytes(
      '/files/upload',
      field: 'file',
      bytes: bytes,
      filename: filename,
      fields: {'taskId': taskId},
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<void> deleteResult(String taskId, String resultId) async {
    await deps.api.deleteJson('/tasks/$taskId/results/$resultId');
  }

  String deadlineIso(DateTime date) => BizDate.toApiIso(date);
}
