import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dependencies.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/app_file.dart';

class FilesRepository {
  FilesRepository(this.deps);

  final AppDependencies deps;

  Future<List<AppFile>> getFilesByProject(String projectId) async {
    final key = 'files.project.$projectId';
    final cached = deps.cache.read(key);
    final initialList = asList(cached?.data)
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .map(AppFile.fromJson)
        .toList();

    try {
      final res = await deps.api.getJson('/files/project/$projectId');
      final rawList = res is List ? res : (asMap(res)?['data'] as List? ?? const []);
      final files = rawList
          .map(asMap)
          .whereType<Map<String, dynamic>>()
          .map(AppFile.fromJson)
          .toList();

      await deps.cache.write(key, rawList);
      return files;
    } catch (_) {
      if (initialList.isNotEmpty) return initialList;
      rethrow;
    }
  }

  Future<AppFile> uploadFile({
    required String projectId,
    required List<int> bytes,
    required String filename,
  }) async {
    final res = await deps.api.uploadBytes(
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
    await deps.api.deleteJson('/files/$fileId');
  }
}

final filesRepositoryProvider = Provider<FilesRepository>((ref) {
  return FilesRepository(ref.watch(dependenciesProvider));
});
