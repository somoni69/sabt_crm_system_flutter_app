import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.secondaryRole,
    this.avatar,
    this.isActive = true,
    this.isSubAdmin = false,
    this.isStoryMaker = false,
    this.extraPermissions = const [],
    this.deniedPermissions = const [],
    this.position,
    this.department,
    this.twoFactorEnabled = false,
    this.themeColor,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String? secondaryRole;
  final String? avatar;
  final bool isActive;
  final bool isSubAdmin;
  final bool isStoryMaker;
  final List<String> extraPermissions;
  final List<String> deniedPermissions;
  final String? position;
  final String? department;
  final bool twoFactorEnabled;
  final String? themeColor;

  String get firstName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Коллега';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  String get roleLabel => roleLabels[role] ?? 'Сотрудник';

  String get displayPosition {
    final value = position?.trim();
    if (value != null && value.isNotEmpty) return value;
    return roleLabel;
  }

  String get combinedRoleLabel {
    final second = secondaryRole;
    if (second == null || second.isEmpty || second == role) return roleLabel;
    return '$roleLabel / ${roleLabels[second] ?? second}';
  }

  bool get isTop => role == 'founder' || role == 'admin' || isSubAdmin;
  bool get isAdmin => role == 'admin' || role == 'founder';
  bool get isFounder => role == 'founder';
  bool get isSmmTeam => ['founder', 'admin', 'smm_director', 'smm_specialist'].contains(role);
  bool get isSalesManager => role == 'sales_manager_smm' || role == 'sales_manager_dev';
  bool get isDevTeam => ['dev_director', 'pm_dev', 'developer'].contains(role);
  bool get isStoriesChecker => role == 'stories_checker';

  Color get identityColor {
    final hash = name.codeUnits.fold<int>(0, (a, b) => a + b);
    // Categorical avatar hues: deliberately theme-independent constants,
    // not surface tokens — an identity colour must stay the same colour
    // in both themes.
    const palette = [
      AppColors.accent,
      AppColors.ice,
      Color(0xFF7FD1B9),
      Color(0xFFF2A65A),
      Color(0xFFE58AA8),
      Color(0xFF9CA8F0),
    ];
    return palette[hash % palette.length];
  }

  String? get accentOverride {
    final raw = themeColor;
    if (raw == null || raw.trim().isEmpty) return null;
    final parts = raw.split('-').where((p) => p.trim().isNotEmpty).toList();
    if (parts.length >= 10) {
      // light text/bg/primary/secondary/accent + dark text/bg/primary/secondary/accent
      return '#${parts[7]}';
    }
    if (parts.length >= 5) return '#${parts[2]}';
    return null;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    List<String> stringList(dynamic value) {
      if (value is List) {
        return value.map((item) => '$item').where((item) => item.isNotEmpty).toList();
      }
      return const [];
    }

    return UserModel(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      email: '${json['email'] ?? ''}',
      role: '${json['role'] ?? 'employee'}',
      secondaryRole: json['secondaryRole'] as String?,
      avatar: json['avatar'] as String?,
      isActive: json['isActive'] != false,
      isSubAdmin: json['isSubAdmin'] == true,
      isStoryMaker: json['isStoryMaker'] == true,
      extraPermissions: stringList(json['extraPermissions']),
      deniedPermissions: stringList(json['deniedPermissions']),
      position: json['position'] as String?,
      department: json['department'] as String?,
      twoFactorEnabled: json['twoFactorEnabled'] == true,
      themeColor: json['themeColor'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'secondaryRole': secondaryRole,
        'avatar': avatar,
        'isActive': isActive,
        'isSubAdmin': isSubAdmin,
        'isStoryMaker': isStoryMaker,
        'extraPermissions': extraPermissions,
        'deniedPermissions': deniedPermissions,
        'position': position,
        'department': department,
        'twoFactorEnabled': twoFactorEnabled,
        'themeColor': themeColor,
      };

  UserModel copyWith({
    String? name,
    String? avatar,
    String? position,
    String? department,
    bool? twoFactorEnabled,
  }) =>
      UserModel(
        id: id,
        name: name ?? this.name,
        email: email,
        role: role,
        secondaryRole: secondaryRole,
        avatar: avatar ?? this.avatar,
        isActive: isActive,
        isSubAdmin: isSubAdmin,
        isStoryMaker: isStoryMaker,
        extraPermissions: extraPermissions,
        deniedPermissions: deniedPermissions,
        position: position ?? this.position,
        department: department ?? this.department,
        twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
        themeColor: themeColor,
      );

  static const Map<String, String> roleLabels = {
    'admin': 'Администратор',
    'founder': 'Основатель',
    'smm_director': 'Руководитель SMM',
    'smm_specialist': 'SMM специалист',
    'designer': 'Дизайнер',
    'sales_manager_smm': 'Менеджер продаж (СММ)',
    'sales_manager_dev': 'Менеджер продаж (Разработка)',
    'dev_director': 'Руководитель разработки',
    'pm_dev': 'Проект-менеджер (Разработка)',
    'developer': 'Разработчик',
    'videographer': 'Видеограф',
    'video_editor': 'Монтажёр',
    'producer': 'Продюсер',
    'targetologist': 'Таргетолог',
    'stories_checker': 'Проверяющий сторис',
    'employee': 'Сотрудник',
  };
}
