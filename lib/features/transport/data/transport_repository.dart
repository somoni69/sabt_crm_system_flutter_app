import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dependencies.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/transport_request.dart';

class TransportRepository {
  TransportRepository(this.deps);

  final AppDependencies deps;

  Future<MyTransportData> getMyRequests() async {
    final res = await deps.api.getJson('/transport-requests/my');
    final map = res is Map<String, dynamic> ? res : asMap(res) ?? const <String, dynamic>{};
    return MyTransportData.fromJson(map);
  }

  Future<void> createRequest({
    required String projectId,
    required double amount,
    required String date,
    String? note,
  }) async {
    final body = <String, dynamic>{
      'projectId': projectId,
      'amount': amount,
      'date': date,
    };
    if (note != null) body['note'] = note;
    await deps.api.postJson('/transport-requests', body: body);
  }

  Future<void> cancelRequest(String id) async {
    await deps.api.deleteJson('/transport-requests/$id');
  }
}

final transportRepositoryProvider = Provider<TransportRepository>((ref) {
  return TransportRepository(ref.watch(dependenciesProvider));
});
