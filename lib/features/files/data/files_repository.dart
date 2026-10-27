import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/response_cache.dart';
import '../../../core/dependencies.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/app_file.dart';

/// Files data source.
///
/// Reads are cache-first streams ([watchFilesByProject]): the Hive
/// snapshot is emitted instantly, then the network response replaces
/// it. A failed refresh never blanks an already-visible list — the
/// stream simply completes on the cached value. This matches how every
/// other list in the app behaves; the previous implementation awaited
/// the network before showing anything, so the page opened with a
/// full-screen spinner on every visit.
class FilesRepository {
  FilesRepository(AppDependencies deps) : api = deps.api, cache = deps.cache;

  /// Direct construction for tests and previews.
  FilesRepository.direct({required this.api, required this.cache});

  final ApiClient api;
  final ResponseCache cache;

  static String _cacheKey(String projectId) => 'files.project.$projectId';

  static List<AppFile> _parseFiles(dynamic res) {
    final list = res is List
        ? res
        : res is Map<String, dynamic>
        ? (res['files'] ?? res['data'] ?? res['items'])
        : null;
    return asList(list)
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .map(AppFile.fromJson)
        .toList();
  }

  /// Instant cached snapshot (when present), then the fresh network
  /// list. Errors after a snapshot has been emitted are swallowed: the
  /// user keeps the list they already see.
  Stream<List<AppFile>> watchFilesByProject(String projectId) async* {
    final cacheKey = _cacheKey(projectId);
    final cached = cache.read(cacheKey);
    if (cached != null) {
      yield _parseFiles(cached.data);
    }
    try {
      final res = await api.getJson('/files/project/$projectId');
      await cache.write(cacheKey, res);
      yield _parseFiles(res);
    } catch (_) {
      if (cached == null) rethrow;
    }
  }

  /// One-shot network fetch that also refreshes the cache. Used by
  /// pull-to-refresh, where the user explicitly asked for fresh data.
  Future<List<AppFile>> getFilesByProject(String projectId) async {
    final cacheKey = _cacheKey(projectId);
    try {
      final res = await api.getJson('/files/project/$projectId');
      await cache.write(cacheKey, res);
      return _parseFiles(res);
    } catch (_) {
      final cached = cache.read(cacheKey);
      if (cached != null) return _parseFiles(cached.data);
      rethrow;
    }
  }

  Future<AppFile> uploadFile({
    required String projectId,
    required List<int> bytes,
    required String filename,
  }) async {
    final res = await api.uploadBytes(
      '/files/upload',
      field: 'file',
      bytes: bytes,
      filename: filename,
      fields: {'projectId': projectId},
    );
    final map = asMap(res) ?? const <String, dynamic>{};
    return AppFile.fromJson(map);
  }

  Future<void> deleteFile(String fileId) async {
    await api.deleteJson('/files/$fileId');
  }
}

final filesRepositoryProvider = Provider<FilesRepository>((ref) {
  return FilesRepository(ref.watch(dependenciesProvider));
});
