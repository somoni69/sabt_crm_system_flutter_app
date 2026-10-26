import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dependencies.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/access_models.dart';

class AccessRepository {
  AccessRepository(this.deps);

  final AppDependencies deps;

  Future<List<AccessUser>> getAccessUsers() async {
    final res = await deps.api.getJson('/users/access');
    final list = res is List ? res : (asMap(res)?['data'] as List? ?? const []);
    return list
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .map(AccessUser.fromJson)
        .toList();
  }

  Future<List<AccessCapability>> getAccessCatalog() async {
    try {
      final res = await deps.api.getJson('/users/access-catalog');
      final list = res is List ? res : (asMap(res)?['data'] as List? ?? const []);
      return list
          .map(asMap)
          .whereType<Map<String, dynamic>>()
          .map(AccessCapability.fromJson)
          .toList();
    } catch (_) {
      return const [
        AccessCapability(key: 'finance.view', label: 'Просмотр финансов', category: 'Финансы'),
        AccessCapability(key: 'finance.manage', label: 'Управление финансами', category: 'Финансы', danger: true),
        AccessCapability(key: 'risks.view', label: 'Просмотр рисков', category: 'Аналитика'),
        AccessCapability(key: 'smm.manage', label: 'Управление SMM-проектами', category: 'SMM'),
        AccessCapability(key: 'dev.manage', label: 'Управление Dev-проектами', category: 'Разработка'),
        AccessCapability(key: 'notes.use', label: 'Личные заметки', category: 'Инструменты'),
      ];
    }
  }

  Future<void> updatePermissions(String userId, List<String> extraPermissions) async {
    await deps.api.patchJson('/users/$userId/permissions', body: {
      'extraPermissions': extraPermissions,
    });
  }
}

final accessRepositoryProvider = Provider<AccessRepository>((ref) {
  return AccessRepository(ref.watch(dependenciesProvider));
});
