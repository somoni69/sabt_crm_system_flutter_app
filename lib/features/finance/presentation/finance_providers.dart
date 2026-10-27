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

final financeIncomeProvider =
    FutureProvider.autoDispose<List<FinanceDirectionCard>>((ref) async {
  ref.watch(dataRevisionProvider);
  final ym = ref.watch(selectedFinanceYmProvider);
  return ref.watch(financeRepositoryProvider).incomeDirections(ym);
});

final financeIncomeRowsProvider =
    FutureProvider.autoDispose.family<List<IncomePayRow>, String>((ref, direction) async {
  ref.watch(dataRevisionProvider);
  final ym = ref.watch(selectedFinanceYmProvider);
  return ref.watch(financeRepositoryProvider).incomeRows(direction, ym);
});

final financeExpenseProvider = FutureProvider.autoDispose<FinanceExpenseSummary>((ref) async {
  ref.watch(dataRevisionProvider);
  final ym = ref.watch(selectedFinanceYmProvider);
  return ref.watch(financeRepositoryProvider).expenseSummary(ym);
});

final financeSalaryProvider = FutureProvider.autoDispose<List<SalaryPayRow>>((ref) async {
  ref.watch(dataRevisionProvider);
  final ym = ref.watch(selectedFinanceYmProvider);
  return ref.watch(financeRepositoryProvider).salaryRows(ym);
});

final financeSubscriptionsProvider =
    FutureProvider.autoDispose<List<SubscriptionPayRow>>((ref) async {
  ref.watch(dataRevisionProvider);
  final ym = ref.watch(selectedFinanceYmProvider);
  return ref.watch(financeRepositoryProvider).subscriptionRows(ym);
});

final financeDebtsProvider = FutureProvider.autoDispose<List<DebtPayRow>>((ref) async {
  ref.watch(dataRevisionProvider);
  final ym = ref.watch(selectedFinanceYmProvider);
  return ref.watch(financeRepositoryProvider).debtRows(ym);
});

final financeJournalProvider = FutureProvider.autoDispose<List<FinanceTransaction>>((ref) async {
  ref.watch(dataRevisionProvider);
  final ym = ref.watch(selectedFinanceYmProvider);
  final parts = ym.split('-');
  final year = int.tryParse(parts.first) ?? DateTime.now().year;
  final month = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
  final from = '$ym-01';
  final last = DateTime(year, month + 1, 0).day;
  final to = '$ym-${last.toString().padLeft(2, '0')}';
  return ref.watch(financeRepositoryProvider).transactions(from: from, to: to);
});
