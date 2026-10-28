import '../../../core/utils/json_utils.dart';

class AccessUser {
  const AccessUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.secondaryRole,
    this.position,
    this.avatar,
    this.extraPermissions = const [],
    this.deniedPermissions = const [],
    this.isSubAdmin = false,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String? secondaryRole;
  final String? position;
  final String? avatar;
  final List<String> extraPermissions;
  final List<String> deniedPermissions;
  final bool isSubAdmin;
  final bool isActive;

  int get totalOverrides => extraPermissions.length + deniedPermissions.length;

  factory AccessUser.fromJson(Map<String, dynamic> json) => AccessUser(
        id: asStringOr(json['id'], ''),
        name: asStringOr(json['name'], 'Сотрудник'),
        email: asStringOr(json['email'], ''),
        role: asStringOr(json['role'], 'employee'),
        secondaryRole: asString(json['secondaryRole']),
        position: asString(json['position']),
        avatar: asString(json['avatar']),
        extraPermissions: asStringList(json['extraPermissions']),
        deniedPermissions: asStringList(json['deniedPermissions']),
        isSubAdmin: asBool(json['isSubAdmin']),
        isActive: asBool(json['isActive'], fallback: true),
      );
}

class AccessCapability {
  const AccessCapability({
    required this.key,
    required this.label,
    required this.category,
    this.description = '',
    this.danger = false,
    this.roles = const [],
  });

  final String key;
  final String label;
  final String category;
  final String description;
  final bool danger;
  final List<String> roles;

  factory AccessCapability.fromJson(Map<String, dynamic> json) => AccessCapability(
        key: asStringOr(json['key'], ''),
        label: asStringOr(json['label'], ''),
        category: asStringOr(json['category'], 'Общие'),
        description: asStringOr(json['description'], ''),
        danger: asBool(json['danger']),
        roles: asStringList(json['roles']),
      );
}
