import '../../../core/utils/json_utils.dart';

class AccessUser {
  const AccessUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.secondaryRole,
    this.position,
    this.extraPermissions = const [],
    this.isActive = true,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String? secondaryRole;
  final String? position;
  final List<String> extraPermissions;
  final bool isActive;

  factory AccessUser.fromJson(Map<String, dynamic> json) => AccessUser(
        id: asStringOr(json['id'], ''),
        name: asStringOr(json['name'], 'Сотрудник'),
        email: asStringOr(json['email'], ''),
        role: asStringOr(json['role'], 'employee'),
        secondaryRole: asString(json['secondaryRole']),
        position: asString(json['position']),
        extraPermissions: asStringList(json['extraPermissions']),
        isActive: asBool(json['isActive'], fallback: true),
      );
}

class AccessCapability {
  const AccessCapability({
    required this.key,
    required this.label,
    required this.category,
    this.danger = false,
  });

  final String key;
  final String label;
  final String category;
  final bool danger;

  factory AccessCapability.fromJson(Map<String, dynamic> json) => AccessCapability(
        key: asStringOr(json['key'], ''),
        label: asStringOr(json['label'], ''),
        category: asStringOr(json['category'], 'Общие'),
        danger: asBool(json['danger']),
      );
}
