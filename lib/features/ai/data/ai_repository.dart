import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dependencies.dart';
import '../../../core/utils/json_utils.dart';

class AiRepository {
  AiRepository(this.deps);

  final AppDependencies deps;

  Future<String> askAi({required String message, String? model}) async {
    final body = <String, dynamic>{'message': message};
    if (model != null) body['model'] = model;
    final res = await deps.api.postJson('/ai/chat', body: body);
    final map = asMap(res) ?? const <String, dynamic>{};
    return asStringOr(map['reply'], 'Ответ не получен');
  }

  Future<List<String>> getModels() async {
    try {
      final res = await deps.api.getJson('/ai/models');
      final list = asList(res).map((e) => e.toString()).toList();
      return list.isEmpty ? const ['gemini-2.0-flash'] : list;
    } catch (_) {
      return const ['gemini-2.0-flash'];
    }
  }
}

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository(ref.watch(dependenciesProvider));
});
