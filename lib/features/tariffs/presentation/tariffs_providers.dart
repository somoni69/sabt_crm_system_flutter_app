import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/app_state.dart';
import '../data/tariffs_repository.dart';
import '../domain/tariff.dart';

final tariffsListProvider = FutureProvider.autoDispose<List<Tariff>>((ref) async {
  ref.watch(dataRevisionProvider);
  final repo = ref.watch(tariffsRepositoryProvider);
  return repo.getTariffs();
});
