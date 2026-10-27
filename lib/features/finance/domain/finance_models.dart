import '../../../core/utils/date_utils.dart';
import '../../../core/utils/json_utils.dart';

class FinanceAccount {
  const FinanceAccount({
    required this.id,
    required this.name,
    this.balance = 0,
    this.currency = 'TJS',
  });

  final String id;
  final String name;
  final double balance;
  final String currency;

  factory FinanceAccount.fromJson(Map<String, dynamic> json) => FinanceAccount(
        id: asStringOr(json['id'] ?? json['accountId'], ''),
        name: asStringOr(json['name'], 'Счёт'),
        balance: asDoubleOr(json['balance'], 0),
        currency: asStringOr(json['currency'], 'TJS'),
      );
}

class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.type,
    required this.amount,
    this.description,
    this.category,
    this.date,
    this.accountName,
  });

  final String id;
  final String type; // income, expense, transfer, saving
  final double amount;
  final String? description;
  final String? category;
  final DateTime? date;
  final String? accountName;

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';

  factory FinanceTransaction.fromJson(Map<String, dynamic> json) => FinanceTransaction(
        id: asStringOr(json['id'], ''),
        type: asStringOr(json['type'], 'expense'),
        amount: asDoubleOr(json['amount'], 0),
        description: asString(json['description'] ?? json['comment'] ?? json['title']),
        category: asString(json['category'] ?? json['group']),
        date: BizDate.parse(json['date'] ?? json['createdAt']),
        accountName: asString(json['accountName'] ?? json['account']?['name']),
      );
}

class FinanceOverviewData {
  const FinanceOverviewData({
    required this.ym,
    this.income = 0,
    this.expense = 0,
    this.profit = 0,
    this.receivables = 0,
    this.accounts = const [],
    this.recentTransactions = const [],
  });

  final String ym;
  final double income;
  final double expense;
  final double profit;
  final double receivables;
  final List<FinanceAccount> accounts;
  final List<FinanceTransaction> recentTransactions;

  double get totalBalance => accounts.fold<double>(0, (sum, a) => sum + a.balance);

  factory FinanceOverviewData.fromJson(Map<String, dynamic> json, String ym) {
    return FinanceOverviewData(
      ym: ym,
      income: asDoubleOr(json['income'], 0),
      expense: asDoubleOr(json['expense'], 0),
      profit: asDoubleOr(json['profit'] ?? (asDoubleOr(json['income'], 0) - asDoubleOr(json['expense'], 0)), 0),
      receivables: asDoubleOr(
        json['receivables'] ?? json['expectedIncome'] ?? asMap(json['stats'])?['expectedIncome'],
        0,
      ),
      accounts: asList(json['balances'] ?? json['accounts'])
          .map(asMap)
          .whereType<Map<String, dynamic>>()
          .map(FinanceAccount.fromJson)
          .toList(),
      recentTransactions: asList(json['recentTransactions'] ?? json['transactions'])
          .map(asMap)
          .whereType<Map<String, dynamic>>()
          .map(FinanceTransaction.fromJson)
          .toList(),
    );
  }
}

class FinanceDirectionCard {
  const FinanceDirectionCard({
    required this.direction,
    required this.label,
    this.received = 0,
    this.expected = 0,
    this.plan = 0,
    this.projectCount = 0,
  });

  final String direction;
  final String label;
  final double received;
  final double expected;
  final double plan;
  final int projectCount;

  static const labels = {
    'smm': 'SMM',
    'development': 'Разработка',
    'design': 'Дизайн',
    'maintenance': 'Обслуживание',
  };

  factory FinanceDirectionCard.fromJson(Map<String, dynamic> json) {
    final direction = asStringOr(json['direction'], '');
    return FinanceDirectionCard(
      direction: direction,
      label: labels[direction] ?? direction,
      received: asDoubleOr(json['received'], 0),
      expected: asDoubleOr(json['expected'], 0),
      plan: asDoubleOr(json['plan'], 0),
      projectCount: asIntOr(json['projectCount'], 0),
    );
  }
}

class IncomePayRow {
  const IncomePayRow({
    required this.projectId,
    required this.name,
    required this.amount,
    this.overdue = 0,
    this.plannedId,
    this.partNo,
    this.dueDate,
    this.late = false,
  });

  final String projectId;
  final String name;
  final double amount;
  final double overdue;
  final String? plannedId;
  final int? partNo;
  final String? dueDate;
  final bool late;

  bool get hasPlan => plannedId != null && plannedId!.isNotEmpty && !plannedId!.startsWith('virtual');
}

List<IncomePayRow> incomePayRows(Map<String, dynamic> json, String ym) {
  final kind = asStringOr(json['kind'], '');
  final rows = <IncomePayRow>[];
  if (kind == 'smm') {
    for (final raw in asList(json['rows'])) {
      final row = asMap(raw);
      if (row == null) continue;
      final project = asMap(row['project']) ?? const <String, dynamic>{};
      final next = asMap(row['nextDue']);
      final due = asMap(row['due']);
      final remaining = asDoubleOr(row['remaining'], 0);
      final amount = next != null ? asDoubleOr(next['amount'], remaining) : remaining;
      if (amount <= 0.004) continue;
      final state = asString(due?['state']);
      rows.add(IncomePayRow(
        projectId: asStringOr(project['id'], ''),
        name: asStringOr(project['name'], 'Клиент'),
        amount: amount,
        overdue: asDoubleOr(row['overdue'], 0),
        plannedId: asString(next?['plannedId']),
        dueDate: asString(due?['date'] ?? next?['dueDate']),
        late: state == 'late' || asDoubleOr(row['overdue'], 0) > 0,
      ));
    }
  } else if (kind == 'matrix') {
    rows.addAll(_matrixPayRows(asList(json['rows']), ym));
  } else if (kind == 'design') {
    for (final raw in asList(json['simple'])) {
      final row = asMap(raw);
      if (row == null) continue;
      final project = asMap(row['project']) ?? const <String, dynamic>{};
      final left = asDoubleOr(project['tariff'], 0) - asDoubleOr(row['paid'], 0);
      if (left <= 0.5) continue;
      rows.add(IncomePayRow(
        projectId: asStringOr(project['id'], ''),
        name: asStringOr(project['name'], 'Клиент'),
        amount: left,
      ));
    }
    final matrix = asMap(json['matrix']);
    if (matrix != null) rows.addAll(_matrixPayRows(asList(matrix['rows']), ym));
  }
  return rows.where((row) => row.projectId.isNotEmpty).toList();
}

List<IncomePayRow> _matrixPayRows(List<dynamic> source, String ym) {
  final rows = <IncomePayRow>[];
  for (final raw in source) {
    final row = asMap(raw);
    if (row == null) continue;
    final project = asMap(row['project']) ?? const <String, dynamic>{};
    Map<String, dynamic>? cell;
    for (final item in asList(row['cells'])) {
      final map = asMap(item);
      if (map != null && map['ym'] == ym) cell = map;
    }
    final expected = asDoubleOr(cell?['expected'], 0);
    if (expected <= 0.004) continue;
    String? plannedId;
    var late = false;
    final todayKey = BizDate.todayKey();
    for (final item in asList(cell?['plans'])) {
      final plan = asMap(item);
      if (plan == null || plan['status'] == 'received') continue;
      final id = asString(plan['id']);
      if (id != null && !id.startsWith('virtual')) plannedId = id;
      final due = asString(plan['dueDate']);
      if (due != null && due.compareTo(todayKey) < 0) late = true;
      break;
    }
    rows.add(IncomePayRow(
      projectId: asStringOr(project['id'], ''),
      name: asStringOr(project['name'], 'Клиент'),
      amount: expected,
      plannedId: plannedId,
      late: late,
    ));
  }
  return rows;
}

class FinanceExpenseSummary {
  const FinanceExpenseSummary({
    this.salaryToPay = 0,
    this.salaryCount = 0,
    this.subsToPay = 0,
    this.subsCount = 0,
    this.debtsMonthly = 0,
    this.debtCount = 0,
    this.otherSpent = 0,
  });

  final double salaryToPay;
  final int salaryCount;
  final double subsToPay;
  final int subsCount;
  final double debtsMonthly;
  final int debtCount;
  final double otherSpent;

  factory FinanceExpenseSummary.fromJson(Map<String, dynamic> json) {
    final salary = asMap(json['salary']) ?? const {};
    final subs = asMap(json['subscriptions']) ?? const {};
    final debts = asMap(json['debts']) ?? const {};
    final other = asMap(json['other']) ?? const {};
    return FinanceExpenseSummary(
      salaryToPay: asDoubleOr(salary['toPay'], 0),
      salaryCount: asIntOr(salary['count'], 0),
      subsToPay: asDoubleOr(subs['toPay'], 0),
      subsCount: asIntOr(subs['count'], 0),
      debtsMonthly: asDoubleOr(debts['monthly'], 0),
      debtCount: asIntOr(debts['count'], 0),
      otherSpent: asDoubleOr(other['spent'], 0),
    );
  }
}

class SalaryPayRow {
  const SalaryPayRow({
    required this.id,
    required this.name,
    this.role,
    this.salary = 0,
    this.advance = 0,
    this.bonus = 0,
    this.toPay = 0,
    this.frozen = false,
  });

  final String id;
  final String name;
  final String? role;
  final double salary;
  final double advance;
  final double bonus;
  final double toPay;
  final bool frozen;

  factory SalaryPayRow.fromJson(Map<String, dynamic> json) => SalaryPayRow(
        id: asStringOr(json['id'], ''),
        name: asStringOr(json['name'], 'Сотрудник'),
        role: asString(json['role']),
        salary: asDoubleOr(json['salary'], 0),
        advance: asDoubleOr(json['advance'], 0),
        bonus: asDoubleOr(json['bonus'], 0),
        toPay: asDoubleOr(json['toPay'], 0),
        frozen: asBool(json['frozen']),
      );
}

class SubscriptionPayRow {
  const SubscriptionPayRow({
    required this.id,
    required this.name,
    this.kind,
    this.amount = 0,
    this.paidMonth = 0,
    this.paidMark,
    this.active = true,
  });

  final String id;
  final String name;
  final String? kind;
  final double amount;
  final double paidMonth;
  final String? paidMark;
  final bool active;

  double get remaining =>
      paidMark != null ? 0 : (amount - paidMonth).clamp(0, amount).toDouble();

  factory SubscriptionPayRow.fromJson(Map<String, dynamic> json) => SubscriptionPayRow(
        id: asStringOr(json['id'], ''),
        name: asStringOr(json['name'], 'Подписка'),
        kind: asString(json['kind']),
        amount: asDoubleOr(json['amount'], 0),
        paidMonth: asDoubleOr(json['paidMonth'], 0),
        paidMark: asString(json['paidMark']),
        active: asBool(json['active'], fallback: true),
      );
}

class DebtPayRow {
  const DebtPayRow({
    required this.id,
    required this.name,
    this.remaining = 0,
    this.dueMonth = 0,
    this.plannedId,
  });

  final String id;
  final String name;
  final double remaining;
  final double dueMonth;
  final String? plannedId;

  factory DebtPayRow.fromJson(Map<String, dynamic> json, String ym) {
    final debt = asMap(json['debt']) ?? json;
    String? plannedId;
    var due = 0.0;
    for (final raw in asList(json['cells'])) {
      final cell = asMap(raw);
      if (cell == null || cell['ym'] != ym) continue;
      for (final planRaw in asList(cell['plans'])) {
        final plan = asMap(planRaw);
        if (plan == null || plan['status'] == 'received') continue;
        due += asDoubleOr(plan['amount'], 0);
        plannedId ??= asString(plan['id']);
      }
    }
    return DebtPayRow(
      id: asStringOr(debt['id'], ''),
      name: asStringOr(debt['name'], 'Долг'),
      remaining: asDoubleOr(json['remaining'], 0),
      dueMonth: due,
      plannedId: plannedId,
    );
  }
}
