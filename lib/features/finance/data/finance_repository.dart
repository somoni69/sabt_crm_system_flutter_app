import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dependencies.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/finance_models.dart';

class FinanceRepository {
  FinanceRepository(this.deps);

  final AppDependencies deps;

  Future<FinanceOverviewData> getOverview(String ym) async {
    final key = 'finance.overview.$ym';
    final cached = deps.cache.read(key);
    final Map<String, dynamic>? initial = asMap(cached?.data);

    try {
      final res = await deps.api.getJson('/finance/overview', query: {'ym': ym});
      final map = asMap(res) ?? const <String, dynamic>{};
      await deps.cache.write(key, map);
      return FinanceOverviewData.fromJson(map, ym);
    } catch (_) {
      if (initial != null) {
        return FinanceOverviewData.fromJson(initial, ym);
      }
      rethrow;
    }
  }

  Future<void> createOperation(Map<String, dynamic> body) async {
    await deps.api.postJson('/finance/operations', body: body);
  }
}

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(ref.watch(dependenciesProvider));
});
