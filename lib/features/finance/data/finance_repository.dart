import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dependencies.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/finance_models.dart';

class FinanceRepository {
  FinanceRepository(this.deps);

  final AppDependencies deps;

  Map<String, dynamic> _clean(Map<String, dynamic> body) {
    final out = <String, dynamic>{};
    body.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      out[key] = value;
    });
    return out;
  }

  Future<FinanceOverviewData> getOverview(String ym) async {
    final key = 'finance.overview.$ym';
    final cached = deps.cache.read(key);
    final Map<String, dynamic>? initial = asMap(cached?.data);

    try {
      final res = await deps.api.getJson('/finance/overview', query: {'ym': ym});
      final map = asMap(res) ?? const <String, dynamic>{};
      await deps.cache.write(key, map);
      return FinanceOverviewData.fromJson(map, ym);
    } catch (_) {
      if (initial != null) {
        return FinanceOverviewData.fromJson(initial, ym);
      }
      rethrow;
    }
  }

  Future<void> createOperation(Map<String, dynamic> body) async {
    await deps.api.postJson('/finance/operations', body: _clean(body));
  }

  Future<List<FinanceAccount>> accounts() async {
    final res = await deps.api.getJson('/finance/accounts');
    return asList(res)
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .map(FinanceAccount.fromJson)
        .where((account) => account.id.isNotEmpty)
        .toList();
  }

  Future<String?> categoryId(String key) async {
    final res = await deps.api.getJson('/finance/categories');
    for (final raw in asList(res)) {
      final map = asMap(raw);
      if (map != null && map['key'] == key) return asString(map['id']);
    }
    return null;
  }

  Future<List<FinanceDirectionCard>> incomeDirections(String ym) async {
    final res = await deps.api.getJson('/finance/income/directions', query: {'ym': ym});
    return asList(res)
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .map(FinanceDirectionCard.fromJson)
        .toList();
  }

  Future<List<IncomePayRow>> incomeRows(String direction, String ym) async {
    final res = await deps.api.getJson(
      '/finance/income/directions/$direction',
      query: {'ym': ym},
    );
    return incomePayRows(asMap(res) ?? const {}, ym);
  }

  Future<FinanceExpenseSummary> expenseSummary(String ym) async {
    final res = await deps.api.getJson('/finance/expense/summary', query: {'ym': ym});
    return FinanceExpenseSummary.fromJson(asMap(res) ?? const {});
  }

  Future<List<SalaryPayRow>> salaryRows(String ym) async {
    final res = await deps.api.getJson('/finance/expense/detail/salary', query: {'ym': ym});
    return asList(asMap(res)?['rows'])
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .map(SalaryPayRow.fromJson)
        .where((row) => row.id.isNotEmpty)
        .toList();
  }

  Future<List<SubscriptionPayRow>> subscriptionRows(String ym) async {
    final res = await deps.api.getJson('/finance/expense/detail/subscriptions', query: {'ym': ym});
    final kind = asString(asMap(res)?['kind']);
    final rows = kind == 'subscriptions' || asMap(res)?['rows'] != null
        ? asList(asMap(res)?['rows'])
        : asList(res);
    return rows
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .map(SubscriptionPayRow.fromJson)
        .where((row) => row.id.isNotEmpty)
        .toList();
  }

  Future<List<DebtPayRow>> debtRows(String ym) async {
    final res = await deps.api.getJson('/finance/expense/detail/debts', query: {'ym': ym});
    return asList(asMap(res)?['rows'])
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .map((row) => DebtPayRow.fromJson(row, ym))
        .where((row) => row.id.isNotEmpty)
        .toList();
  }

  Future<List<FinanceTransaction>> transactions({
    required String from,
    required String to,
  }) async {
    final res = await deps.api.getJson('/finance/transactions', query: {
      'from': from,
      'to': to,
      'page': 1,
      'pageSize': 80,
    });
    final items = asMap(res)?['items'] ?? res;
    return asList(items)
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .map(FinanceTransaction.fromJson)
        .toList();
  }

  Future<void> deleteTransaction(String id) async {
    await deps.api.deleteJson('/finance/transactions/$id');
  }

  Future<void> receivePlanned({
    required String plannedId,
    required String accountId,
    required String date,
    required double amount,
  }) async {
    await deps.api.postJson('/finance/planned-payments/$plannedId/receive', body: {
      'accountId': accountId,
      'date': date,
      'amount': amount,
    });
  }

  Future<void> payNow({
    String? projectId,
    String? debtId,
    required String ym,
    required double amount,
    required String accountId,
    required String date,
    String? comment,
  }) async {
    await deps.api.postJson('/finance/planned-payments/pay-now', body: _clean({
      'projectId': projectId,
      'debtId': debtId,
      'ym': ym,
      'amount': amount,
      'accountId': accountId,
      'date': date,
      'comment': comment,
    }));
  }

  Future<void> markSubscriptionPaid(String id, String ym) async {
    await deps.api.postJson('/finance/subscriptions/$id/mark-paid', body: {'ym': ym});
  }

  Future<void> paySalary({
    required String employeeId,
    required String ym,
    required double amount,
    required String accountId,
    required String date,
    required String marker,
    String? note,
  }) async {
    final category = await categoryId('salary');
    final comment = (note == null || note.trim().isEmpty) ? marker : '$marker — ${note.trim()}';
    await createOperation({
      'type': 'expense',
      'amount': amount,
      'date': date,
      'accountId': accountId,
      'salaryYm': ym,
      'employeeId': employeeId,
      'categoryId': category,
      'comment': comment,
    });
  }

  Future<void> paySubscription({
    required SubscriptionPayRow row,
    required double amount,
    required String accountId,
    required String date,
    String? note,
  }) async {
    final category = await categoryId(row.kind == 'rent' ? 'rent' : 'subscription');
    final comment = (note == null || note.trim().isEmpty) ? row.name : '${row.name} — ${note.trim()}';
    await createOperation({
      'type': 'expense',
      'amount': amount,
      'date': date,
      'accountId': accountId,
      'subscriptionId': row.id,
      'categoryId': category,
      'comment': comment,
    });
  }
}

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(ref.watch(dependenciesProvider));
});
