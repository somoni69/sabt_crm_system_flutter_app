import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/app_state.dart';
import '../data/risks_repository.dart';
import '../domain/risk_models.dart';

final projectRisksProvider = FutureProvider.autoDispose<List<ProjectRisk>>((ref) async {
  ref.watch(dataRevisionProvider);
  return ref.watch(risksRepositoryProvider).getProjectRisks();
});

final employeeWorkloadProvider = FutureProvider.autoDispose<List<EmployeeWorkload>>((ref) async {
  ref.watch(dataRevisionProvider);
  return ref.watch(risksRepositoryProvider).getEmployeeWorkload();
});
