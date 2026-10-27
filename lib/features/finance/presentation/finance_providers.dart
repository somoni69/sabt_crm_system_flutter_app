import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/state/app_state.dart';
import '../data/finance_repository.dart';
import '../domain/finance_models.dart';

class SelectedFinanceYm extends Notifier<String> {
  @override
  String build() => DateFormat('yyyy-MM').format(DateTime.now());

  void setYm(String ym) => state = ym;
}

final selectedFinanceYmProvider =
    NotifierProvider<SelectedFinanceYm, String>(SelectedFinanceYm.new);

final financeOverviewProvider = FutureProvider.autoDispose<FinanceOverviewData>((ref) async {
  ref.watch(dataRevisionProvider);
  final ym = ref.watch(selectedFinanceYmProvider);
  final repo = ref.watch(financeRepositoryProvider);
  return repo.getOverview(ym);
});
