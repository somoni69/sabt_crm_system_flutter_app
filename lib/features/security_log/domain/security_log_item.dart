import '../../../core/utils/date_utils.dart';
import '../../../core/utils/json_utils.dart';

class SecurityLogItem {
  const SecurityLogItem({
    required this.id,
    required this.action,
    this.entity,
    this.userName,
    this.details,
    this.ipAddress,
    this.createdAt,
  });

  final String id;
  final String action;
  final String? entity;
  final String? userName;
  final String? details;
  final String? ipAddress;
  final DateTime? createdAt;

  factory SecurityLogItem.fromJson(Map<String, dynamic> json) {
    final user = asMap(json['user']);
    return SecurityLogItem(
      id: asStringOr(json['id'], ''),
      action: asStringOr(json['action'], 'ACTION'),
      entity: asString(json['entity']),
      userName: asString(user?['name'] ?? json['userName']),
      details: asString(json['details'] ?? json['comment']),
      ipAddress: asString(json['ipAddress']),
      createdAt: BizDate.parse(json['createdAt']),
    );
  }
}
