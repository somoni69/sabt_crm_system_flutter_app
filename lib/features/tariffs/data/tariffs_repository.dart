import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dependencies.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/tariff.dart';

class TariffsRepository {
  TariffsRepository(this.deps);

  final AppDependencies deps;

  Future<List<Tariff>> getTariffs() async {
    const key = 'tariffs.list';
    final cached = deps.cache.read(key);
    final initialList = asList(cached?.data)
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .map(Tariff.fromJson)
        .toList();

    try {
      final res = await deps.api.getJson('/smm-tariffs');
      final rawList = res is List ? res : (asMap(res)?['data'] as List? ?? const []);
      final tariffs = rawList
          .map(asMap)
          .whereType<Map<String, dynamic>>()
          .map(Tariff.fromJson)
          .toList();

      await deps.cache.write(key, rawList);
      return tariffs;
    } catch (_) {
      if (initialList.isNotEmpty) return initialList;
      rethrow;
    }
  }

  Future<void> toggleActive(String tariffId) async {
    await deps.api.patchJson('/smm-tariffs/$tariffId/toggle-active');
  }

  Future<void> createTariff(Map<String, dynamic> body) async {
    await deps.api.postJson('/smm-tariffs', body: body);
  }
}

final tariffsRepositoryProvider = Provider<TariffsRepository>((ref) {
  return TariffsRepository(ref.watch(dependenciesProvider));
});
