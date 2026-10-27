import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/app_state.dart';
import '../data/access_repository.dart';
import '../domain/access_models.dart';

final accessUsersProvider = FutureProvider.autoDispose<List<AccessUser>>((ref) async {
  ref.watch(dataRevisionProvider);
  return ref.watch(accessRepositoryProvider).getAccessUsers();
});

final accessCatalogProvider = FutureProvider.autoDispose<List<AccessCapability>>((ref) async {
  return ref.watch(accessRepositoryProvider).getAccessCatalog();
});
