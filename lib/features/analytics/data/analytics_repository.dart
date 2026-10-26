import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dependencies.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/analytics_data.dart';

class AnalyticsRepository {
  AnalyticsRepository(this.deps);

  final AppDependencies deps;

  Future<AnalyticsDashboardData> getDashboard() async {
    const key = 'analytics.dashboard';
    final cached = deps.cache.read(key);
    final Map<String, dynamic>? initial = asMap(cached?.data);

    try {
      final res = await deps.api.getJson('/analytics/dashboard');
      final map = asMap(res) ?? const <String, dynamic>{};
      await deps.cache.write(key, map);
      return AnalyticsDashboardData.fromJson(map);
    } catch (_) {
      if (initial != null) {
        return AnalyticsDashboardData.fromJson(initial);
      }
      rethrow;
    }
  }
}

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(ref.watch(dependenciesProvider));
});
