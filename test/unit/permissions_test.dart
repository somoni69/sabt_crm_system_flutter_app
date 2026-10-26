import 'package:flutter_test/flutter_test.dart';
import 'package:sabt_crm/core/rbac/permissions.dart';
import 'package:sabt_crm/features/auth/domain/user.dart';

void main() {
  group('RBAC permissions', () {
    test('founder has full system access including finance and risks', () {
      const founder = UserModel(
        id: 'u-founder',
        name: 'Фарход Сафаров',
        email: 'farhod@webbrand.tj',
        role: 'founder',
      );

      expect(userCan(founder, Perm.dashboard), isTrue);
      expect(userCan(founder, Perm.tasksCreate), isTrue);
      expect(userCan(founder, Perm.financeManage), isTrue);
      expect(userCan(founder, Perm.employeesView), isTrue);
      expect(canManageAccess(founder), isTrue);
      expect(canSeeFinance(founder), isTrue);
    });

    test('designer has limited permissions and cannot view finance or manage tasks bulk', () {
      const designer = UserModel(
        id: 'u-designer',
        name: 'Рустам Назаров',
        email: 'rustam@webbrand.tj',
        role: 'designer',
      );

      expect(userCan(designer, Perm.dashboard), isTrue);
      expect(userCan(designer, Perm.tasksView), isTrue);
      expect(userCan(designer, Perm.financeManage), isFalse);
      expect(userCan(designer, Perm.tasksBulk), isFalse);
      expect(canSeeFinance(designer), isFalse);
      expect(canManageAccess(designer), isFalse);
    });

    test('implied permissions are automatically granted', () {
      const customUser = UserModel(
        id: 'u-custom',
        name: 'Менеджер',
        email: 'manager@webbrand.tj',
        role: 'employee',
        extraPermissions: [Perm.projectsCreate],
      );

      expect(userCan(customUser, Perm.projectsCreate), isTrue);
      // 'projects.create' implies 'projects.view'
      expect(userCan(customUser, Perm.projectsView), isTrue);
    });

    test('denied permissions override role grants', () {
      const restrictedAdmin = UserModel(
        id: 'u-admin-restricted',
        name: 'Помощник',
        email: 'assistant@webbrand.tj',
        role: 'admin',
        deniedPermissions: [Perm.tasksDelete, Perm.clientsDelete],
      );

      expect(userCan(restrictedAdmin, Perm.tasksView), isTrue);
      expect(userCan(restrictedAdmin, Perm.tasksDelete), isFalse);
      expect(userCan(restrictedAdmin, Perm.clientsDelete), isFalse);
    });

    test('subAdmin receives full admin permissions', () {
      const subAdmin = UserModel(
        id: 'u-subadmin',
        name: 'Субадмин',
        email: 'sub@webbrand.tj',
        role: 'employee',
        isSubAdmin: true,
      );

      expect(userCan(subAdmin, Perm.tasksApprove), isTrue);
      expect(userCan(subAdmin, Perm.projectsCreate), isTrue);
      expect(subAdmin.isTop, isTrue);
    });
  });
}
