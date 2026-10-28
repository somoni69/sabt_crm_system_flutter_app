import '../../../core/utils/date_utils.dart';
import '../../../core/utils/json_utils.dart';

class EmployeeModel {
  const EmployeeModel({
    required this.id,
    required this.fullName,
    required this.position,
    this.department = 'Общий',
    this.email = '',
    this.phone,
    this.telegram,
    this.instagram,
    this.status = 'active',
    this.avatar,
    this.isSubAdmin = false,
    this.isStoryMaker = false,
    this.userId,
    this.role = 'employee',
    this.secondaryRole,
    this.bio,
    this.hireDate,
    this.tasksCompleted = 0,
    this.tasksOverdue = 0,
    this.tasksReturned = 0,
    this.activityScore = 0,
    this.lastActiveAt,
  });

  final String id;
  final String fullName;
  final String position;
  final String department;
  final String email;
  final String? phone;
  final String? telegram;
  final String? instagram;
  final String status;
  final String? avatar;
  final bool isSubAdmin;
  final bool isStoryMaker;
  final String? userId;
  final String role;
  final String? secondaryRole;
  final String? bio;
  final DateTime? hireDate;
  final int tasksCompleted;
  final int tasksOverdue;
  final int tasksReturned;
  final int activityScore;
  final DateTime? lastActiveAt;

  bool get isActive => status == 'active';

  String get firstName {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'Сотрудник';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    final user = asMap(json['user']);
    return EmployeeModel(
      id: asStringOr(json['id'], ''),
      fullName: asStringOr(
        json['fullName'] ?? json['name'] ?? user?['name'],
        'Сотрудник',
      ),
      position: asStringOr(json['position'], 'Сотрудник'),
      department: asStringOr(json['department'], 'Общий'),
      email: asStringOr(json['email'] ?? user?['email'], ''),
      phone: asString(json['phone']),
      telegram: asString(json['telegram']),
      instagram: asString(json['instagram']),
      status: asStringOr(json['status'], 'active'),
      avatar: asString(json['avatar'] ?? user?['avatar']),
      isSubAdmin: asBool(json['isSubAdmin']),
      isStoryMaker: asBool(json['isStoryMaker']),
      userId: asString(json['userId'] ?? user?['id']),
      role: asStringOr(user?['role'] ?? json['role'], 'employee'),
      secondaryRole: asString(user?['secondaryRole'] ?? json['secondaryRole']),
      bio: asString(json['bio']),
      hireDate: BizDate.parse(json['hireDate']),
      tasksCompleted: asIntOr(json['tasksCompleted'], 0),
      tasksOverdue: asIntOr(json['tasksOverdue'], 0),
      tasksReturned: asIntOr(json['tasksReturned'], 0),
      activityScore: asIntOr(json['activityScore'], 0),
      lastActiveAt: BizDate.parse(json['lastActiveAt']),
    );
  }
}
