import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/app_state.dart';
import '../data/transport_repository.dart';
import '../domain/transport_request.dart';

final myTransportProvider = FutureProvider.autoDispose<MyTransportData>((ref) async {
  ref.watch(dataRevisionProvider);
  return ref.watch(transportRepositoryProvider).getMyRequests();
});
