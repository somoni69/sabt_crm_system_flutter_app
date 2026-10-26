import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dependencies.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/security_log_item.dart';

class SecurityLogRepository {
  SecurityLogRepository(this.deps);

  final AppDependencies deps;

  Future<List<SecurityLogItem>> getLogs({int limit = 50}) async {
    final res = await deps.api.getJson('/activity-log', query: {'limit': limit.toString()});
    final list = res is List ? res : (asMap(res)?['data'] as List? ?? asList(asMap(res)?['items']));
    return list
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .map(SecurityLogItem.fromJson)
        .toList();
  }
}

final securityLogRepositoryProvider = Provider<SecurityLogRepository>((ref) {
  return SecurityLogRepository(ref.watch(dependenciesProvider));
});
