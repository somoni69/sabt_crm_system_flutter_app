import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/dependencies.dart';
import '../../../core/state/app_state.dart';
import '../data/smm_repository.dart';

class SelectedSmmControlYm extends Notifier<String> {
  @override
  String build() => DateFormat('yyyy-MM').format(DateTime.now());

  void setYm(String ym) => state = ym;
}

final selectedSmmControlYmProvider =
    NotifierProvider<SelectedSmmControlYm, String>(SelectedSmmControlYm.new);

final smmControlProjectsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(dataRevisionProvider);
  final ym = ref.watch(selectedSmmControlYmProvider);
  final repo = SmmRepository(ref.watch(dependenciesProvider));
  return repo.getSmmControl(ym);
});
