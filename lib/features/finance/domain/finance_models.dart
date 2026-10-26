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
        id: asStringOr(json['id'], ''),
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
      receivables: asDoubleOr(json['receivables'] ?? json['expectedIncome'], 0),
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
