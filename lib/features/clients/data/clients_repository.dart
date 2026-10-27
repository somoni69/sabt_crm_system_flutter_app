import '../../../core/dependencies.dart';

class ClientsRepository {
  ClientsRepository(this.deps);

  final AppDependencies deps;

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final data = await deps.api.postJson('/clients', body: body);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<void> update(String id, Map<String, dynamic> body) async {
    await deps.api.patchJson('/clients/$id', body: body);
  }

  Future<void> remove(String id) async {
    await deps.api.deleteJson('/clients/$id');
  }

  Future<void> setCallRequest(String id, bool flag) async {
    await deps.api.postJson('/clients/call-request', body: {
      'ids': [id],
      'flag': flag,
    });
  }
}
