import '../../../core/utils/json_utils.dart';

class TransportRequestModel {
  const TransportRequestModel({
    required this.id,
    required this.employeeName,
    required this.projectName,
    required this.amount,
    required this.date,
    this.status = 'pending',
    this.note,
    this.receiptUrl,
  });

  final String id;
  final String employeeName;
  final String projectName;
  final double amount;
  final String date;
  final String status; // pending, paid, rejected
  final String? note;
  final String? receiptUrl;

  factory TransportRequestModel.fromJson(Map<String, dynamic> json) => TransportRequestModel(
        id: asStringOr(json['id'], ''),
        employeeName: asStringOr(json['employeeName'] ?? json['employee']?['name'], 'Сотрудник'),
        projectName: asStringOr(json['projectName'] ?? json['project']?['name'], 'Проект'),
        amount: asDoubleOr(json['amount'], 0),
        date: asStringOr(json['date'], ''),
        status: asStringOr(json['status'], 'pending'),
        note: asString(json['note']),
        receiptUrl: asString(json['receiptUrl']),
      );
}

class MyTransportData {
  const MyTransportData({
    this.requests = const [],
    this.totalPaidThisMonth = 0,
    this.totalPending = 0,
  });

  final List<TransportRequestModel> requests;
  final double totalPaidThisMonth;
  final double totalPending;

  factory MyTransportData.fromJson(Map<String, dynamic> json) {
    final rawRequests = asList(json['requests'] ?? json['items'] ?? const <dynamic>[]);
    return MyTransportData(
      requests: rawRequests
          .map(asMap)
          .whereType<Map<String, dynamic>>()
          .map(TransportRequestModel.fromJson)
          .toList(),
      totalPaidThisMonth: asDoubleOr(json['totalPaidThisMonth'] ?? json['paid'], 0),
      totalPending: asDoubleOr(json['totalPending'] ?? json['pending'], 0),
    );
  }
}
