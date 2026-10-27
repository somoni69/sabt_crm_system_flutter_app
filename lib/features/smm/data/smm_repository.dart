import '../../../core/dependencies.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/json_utils.dart';

class SmmRepository {
  SmmRepository(this.deps);

  final AppDependencies deps;

  Future<void> upsertStory({
    required String projectId,
    required DateTime date,
    required int storiesCount,
  }) async {
    await deps.api.postJson('/stories', body: {
      'projectId': projectId,
      'date': BizDate.toApiDate(date),
      'storiesCount': storiesCount.clamp(0, 30),
    });
  }

  /// `publishTime` is not part of the create DTO on the backend, so it is
  /// applied through the smart-calendar endpoint right after creation.
  Future<String?> createContentItem({
    required String projectId,
    required String contentType,
    required String topic,
    DateTime? publishDate,
    String? publishTime,
    String? assigneeId,
    String? scriptText,
    String? caption,
  }) async {
    final data = await deps.api.postJson('/content-plan', body: {
      'projectId': projectId,
      'contentType': contentType,
      'topic': topic,
      if (publishDate != null) 'publishDate': BizDate.toApiDate(publishDate),
      'assigneeId': ?assigneeId,
      if (scriptText != null && scriptText.isNotEmpty) 'scriptText': scriptText,
      if (caption != null && caption.isNotEmpty) 'caption': caption,
    });
    final id = data is Map ? '${data['id'] ?? ''}' : '';
    if (id.isEmpty) return null;
    if (publishTime != null && publishTime.isNotEmpty) {
      await updateSmartItem(id, time: publishTime);
    }
    return id;
  }

  Future<void> updateContentItem(String itemId, Map<String, dynamic> body) async {
    await deps.api.patchJson('/content-plan/$itemId', body: body);
  }

  Future<void> updateSmartItem(
    String itemId, {
    DateTime? date,
    String? time,
    String? status,
    int? durationMin,
  }) async {
    final body = <String, dynamic>{};
    if (date != null) body['publishDate'] = BizDate.toApiDate(date);
    if (time != null) body['publishTime'] = time.isEmpty ? null : time;
    if (status != null) body['status'] = status;
    if (durationMin != null) body['durationMin'] = durationMin;
    if (body.isEmpty) return;
    await deps.api.patchJson('/content-plan/smart-item/$itemId', body: body);
  }

  Future<void> moveContentItem({
    required String itemId,
    required DateTime? date,
  }) async {
    await updateSmartItem(itemId, date: date);
  }

  Future<void> updateShootSession(
    String shootId, {
    DateTime? date,
    String? time,
  }) async {
    final body = <String, dynamic>{};
    if (date != null) body['date'] = BizDate.toApiDate(date);
    if (time != null) body['time'] = time.isEmpty ? null : time;
    if (body.isEmpty) return;
    await deps.api.patchJson('/content-plan/shoot-session/$shootId', body: body);
  }

  Future<void> markPrepDone(String itemId, {required bool done}) async {
    await deps.api.patchJson('/content-plan/my-work/$itemId', body: {'done': done});
  }

  Future<void> smartGenerate({
    required String projectId,
    required int reels,
    required int posts,
  }) async {
    await deps.api.postJson('/content-plan/smart-generate', body: {
      'projectId': projectId,
      'reels': reels,
      'posts': posts,
    });
  }

  Future<List<Map<String, dynamic>>> getSmmControl(String ym) async {
    final res = await deps.api.getJson('/smm-control', query: {'ym': ym});
    final map = asMap(res);
    final projects = asList(map?['projects'] ?? (res is List ? res : []));
    return projects.map(asMap).whereType<Map<String, dynamic>>().toList();
  }
}
