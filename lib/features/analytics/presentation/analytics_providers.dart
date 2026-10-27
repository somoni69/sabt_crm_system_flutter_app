import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/app_state.dart';
import '../data/analytics_repository.dart';
import '../domain/analytics_data.dart';

final analyticsDashboardProvider = FutureProvider.autoDispose<AnalyticsDashboardData>((ref) async {
  ref.watch(dataRevisionProvider);
  final repo = ref.watch(analyticsRepositoryProvider);
  return repo.getDashboard();
});
