import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/snapshot.dart';
import '../../../core/dependencies.dart';
import '../../../core/state/app_state.dart';
import '../../../core/utils/json_utils.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/clients_repository.dart';
import '../domain/client_lead.dart';

final clientsRepositoryProvider = Provider<ClientsRepository>((ref) {
  return ClientsRepository(ref.watch(dependenciesProvider));
});

List<ClientLeadModel> parseClients(dynamic raw) {
  final list = raw is List
      ? raw
      : raw is Map && raw['data'] is List
          ? raw['data'] as List
          : const [];
  final clients = list
      .map(asMap)
      .whereType<Map<String, dynamic>>()
      .map(ClientLeadModel.fromJson)
      .where((client) => client.id.isNotEmpty)
      .toList();
  clients.sort((a, b) {
    if (a.callRequested != b.callRequested) return a.callRequested ? -1 : 1;
    final aNext = a.nextContactAt;
    final bNext = b.nextContactAt;
    if (aNext != null && bNext == null) return -1;
    if (aNext == null && bNext != null) return 1;
    if (aNext != null && bNext != null) {
      final diff = aNext.compareTo(bNext);
      if (diff != 0) return diff;
    }
    return (b.lastActivityAt ?? b.createdAt ?? DateTime(2000))
        .compareTo(a.lastActivityAt ?? a.createdAt ?? DateTime(2000));
  });
  return clients;
}

final clientsProvider =
    StreamProvider.autoDispose<Snapshot<List<ClientLeadModel>>>((ref) {
  ref.watch(dataRevisionProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream.value(const Snapshot<List<ClientLeadModel>>(data: []));
  }
  final deps = ref.watch(dependenciesProvider);
  return deps.cachedJson
      .watch(
        userId: user.id,
        key: 'clients.all',
        path: '/clients',
      )
      .map((payload) => Snapshot.fromPayload(payload, parseClients));
});

final clientProvider =
    StreamProvider.autoDispose.family<Snapshot<ClientLeadModel>, String>((ref, id) {
  ref.watch(dataRevisionProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.error(StateError('Не авторизован'));
  final deps = ref.watch(dependenciesProvider);
  return deps.cachedJson
      .watch(
        userId: user.id,
        key: 'client.$id',
        path: '/clients/$id',
      )
      .map((payload) => Snapshot.fromPayload(
            payload,
            (raw) => ClientLeadModel.fromJson(asMap(raw) ?? const {}),
          ));
});
