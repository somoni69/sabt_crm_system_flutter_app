import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dependencies.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/risk_models.dart';

class RisksRepository {
  RisksRepository(this.deps);

  final AppDependencies deps;

  Future<List<ProjectRisk>> getProjectRisks() async {
    final res = await deps.api.getJson('/risk-analytics/risks/projects');
    final list = res is List ? res : (asMap(res)?['data'] as List? ?? const []);
    return list
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .map(ProjectRisk.fromJson)
        .toList();
  }

  Future<List<EmployeeWorkload>> getEmployeeWorkload() async {
    final res = await deps.api.getJson('/risk-analytics/workload/employees');
    final list = res is List ? res : (asMap(res)?['data'] as List? ?? const []);
    return list
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .map(EmployeeWorkload.fromJson)
        .toList();
  }
}

final risksRepositoryProvider = Provider<RisksRepository>((ref) {
  return RisksRepository(ref.watch(dependenciesProvider));
});
