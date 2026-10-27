import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/app_state.dart';
import '../data/security_log_repository.dart';
import '../domain/security_log_item.dart';

final securityLogsProvider = FutureProvider.autoDispose<List<SecurityLogItem>>((ref) async {
  ref.watch(dataRevisionProvider);
  return ref.watch(securityLogRepositoryProvider).getLogs();
});
