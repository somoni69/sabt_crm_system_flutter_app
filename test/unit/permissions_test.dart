import 'package:flutter_test/flutter_test.dart';
import 'package:webrand_app/core/rbac/permissions.dart';
import 'package:webrand_app/features/auth/domain/user.dart';

UserModel _user(
  String role, {
  String? secondaryRole,
  List<String> extra = const [],
  List<String> denied = const [],
  bool isSubAdmin = false,
}) =>
    UserModel(
      id: 'u-$role',
      name: 'Тест $role',
      email: '$role@webbrand.tj',
      role: role,
      secondaryRole: secondaryRole,
      extraPermissions: extra,
      deniedPermissions: denied,
      isSubAdmin: isSubAdmin,
    );

void main() {
  group('RBAC permissions & 15 roles matrix', () {
    test('founder has full system access including finance, sales-plan, kpi, and access management', () {
      final founder = _user('founder');

      expect(userCan(founder, Perm.dashboard), isTrue);
      expect(userCan(founder, Perm.tasksCreate), isTrue);
      expect(userCan(founder, Perm.financeManage), isTrue);
      expect(userCan(founder, Perm.employeesView), isTrue);
      expect(canManageAccess(founder), isTrue);
      expect(canSeeFinance(founder), isTrue);
      expect(canAccessRoute(founder, '/finance'), isTrue);
      expect(canAccessRoute(founder, '/employees/sales-plan'), isTrue);
      expect(canAccessRoute(founder, '/employees/kpi'), isTrue);
      expect(canAccessRoute(founder, '/employee-access'), isTrue);
    });

    test('admin has access management and KPI but not founder-only finance or sales-plan', () {
      final admin = _user('admin');

      expect(canManageAccess(admin), isTrue);
      expect(canAccessRoute(admin, '/employee-access'), isTrue);
      expect(canAccessRoute(admin, '/employees/kpi'), isTrue);
      expect(canAccessRoute(admin, '/employees/week'), isTrue);
      expect(canAccessRoute(admin, '/employees/activity'), isTrue);
      expect(canAccessRoute(admin, '/employees/sales-plan'), isFalse);
      expect(canSeeFinance(admin), isFalse);
      expect(canAccessRoute(admin, '/finance'), isFalse);
    });

    test('smm_director can manage SMM, stories check, employees directory, but not admin KPI/access', () {
      final smmDirector = _user('smm_director');

      expect(canSeeSmmSection(smmDirector), isTrue);
      expect(canCheckStories(smmDirector), isTrue);
      expect(canSeeEmployees(smmDirector), isTrue);
      expect(canAccessRoute(smmDirector, '/employees'), isTrue);
      expect(canAccessRoute(smmDirector, '/employees/org'), isTrue);
      expect(canAccessRoute(smmDirector, '/employees/kpi'), isFalse);
      expect(canAccessRoute(smmDirector, '/employee-access'), isFalse);
      expect(canAccessRoute(smmDirector, '/stories-check'), isTrue);
      expect(canAccessRoute(smmDirector, '/smm/control'), isTrue);
    });

    test('producer works in SMM like a specialist but does not mark stories', () {
      final producer = _user('producer');

      expect(canSeeSmmSection(producer), isTrue);
      expect(isStoryWriter(producer), isFalse);
      expect(isSmmViewOnly(producer), isFalse);
      expect(userCan(producer, Perm.tasksCreate), isTrue);
      expect(userCan(producer, Perm.contentPlanEdit), isTrue);
      expect(userCan(producer, Perm.projectsCreate), isTrue);
      expect(canAccessRoute(producer, '/smm/control'), isTrue);
      expect(canCheckStories(producer), isFalse);
      expect(canSeeDevSection(producer), isFalse);
    });

    test('smm_specialist can publish stories and view SMM control, but cannot access stories-check audit', () {
      final smmSpec = _user('smm_specialist');

      expect(canSeeSmmSection(smmSpec), isTrue);
      expect(isStoryWriter(smmSpec), isTrue);
      expect(canCheckStories(smmSpec), isFalse);
      expect(canAccessRoute(smmSpec, '/smm/control'), isTrue);
      expect(canAccessRoute(smmSpec, '/stories-check'), isFalse);
    });

    test('sales_manager_smm and sales_manager_dev have CRM & onboarding access and SMM view-only', () {
      final salesSmm = _user('sales_manager_smm');
      final salesDev = _user('sales_manager_dev');

      for (final sales in [salesSmm, salesDev]) {
        expect(canSeeClients(sales), isTrue);
        expect(userCan(sales, Perm.clientsCreate), isTrue);
        expect(userCan(sales, Perm.projectsCreate), isTrue);
        expect(isSmmViewOnly(sales), isTrue);
        expect(canAccessRoute(sales, '/clients'), isTrue);
        expect(canAccessRoute(sales, '/onboarding'), isTrue);
      }
    });

    test('dev_director, pm_dev, and developer have correct Dev Tracker hierarchy', () {
      final devDir = _user('dev_director');
      final pmDev = _user('pm_dev');
      final dev = _user('developer');

      expect(canSeeDevSection(devDir), isTrue);
      expect(userCan(devDir, Perm.devTrackerManage), isTrue);
      expect(canAccessRoute(devDir, '/dev-board/reports'), isTrue);

      expect(canSeeDevSection(pmDev), isTrue);
      expect(userCan(pmDev, Perm.devTrackerManage), isTrue);
      expect(canAccessRoute(pmDev, '/dev-board/reports'), isTrue);

      expect(canSeeDevSection(dev), isTrue);
      expect(userCan(dev, Perm.devTrackerView), isTrue);
      expect(userCan(dev, Perm.devTrackerManage), isFalse);
      expect(canAccessRoute(dev, '/dev-board'), isTrue);
      expect(canAccessRoute(dev, '/dev-board/reports'), isFalse);
    });

    test('creative roles (designer, videographer, video_editor, targetologist, employee) have scoped access', () {
      for (final role in ['designer', 'videographer', 'video_editor', 'targetologist', 'employee']) {
        final u = _user(role);
        expect(userCan(u, Perm.dashboard), isTrue);
        expect(userCan(u, Perm.tasksView), isTrue);
        expect(userCan(u, Perm.projectsView), isTrue);
        expect(canSeeFinance(u), isFalse);
        expect(canManageAccess(u), isFalse);
        expect(canSeeSmmSection(u), isFalse);
        expect(canAccessRoute(u, '/smm/control'), isFalse);
        expect(canAccessRoute(u, '/stories-check'), isFalse);
      }
    });

    test('stories_checker is strictly isolated to dashboard, stories-check, notifications, profile, settings', () {
      final checker = _user('stories_checker');

      expect(canCheckStories(checker), isTrue);
      expect(canAccessRoute(checker, '/'), isTrue);
      expect(canAccessRoute(checker, '/stories-check'), isTrue);
      expect(canAccessRoute(checker, '/stories-check/month'), isTrue);
      expect(canAccessRoute(checker, '/profile'), isTrue);
      expect(canAccessRoute(checker, '/tasks'), isFalse);
      expect(canAccessRoute(checker, '/projects'), isFalse);
      expect(canAccessRoute(checker, '/clients'), isFalse);
    });

    test('implied permissions are automatically granted and deniedPermissions override role grants', () {
      final customUser = _user(
        'employee',
        extra: [Perm.projectsCreate, Perm.devTrackerManage],
      );
      expect(userCan(customUser, Perm.projectsCreate), isTrue);
      expect(userCan(customUser, Perm.projectsView), isTrue);
      expect(userCan(customUser, Perm.devTrackerView), isTrue);

      final restrictedAdmin = _user(
        'admin',
        denied: [Perm.tasksDelete, Perm.clientsDelete],
      );
      expect(userCan(restrictedAdmin, Perm.tasksView), isTrue);
      expect(userCan(restrictedAdmin, Perm.tasksDelete), isFalse);
      expect(userCan(restrictedAdmin, Perm.clientsDelete), isFalse);
    });

    test('subAdmin and secondaryRole combine permissions accurately', () {
      final subAdmin = _user('employee', isSubAdmin: true);
      expect(userCan(subAdmin, Perm.tasksApprove), isTrue);
      expect(userCan(subAdmin, Perm.projectsCreate), isTrue);
      expect(subAdmin.isTop, isTrue);

      final dualRole = _user('developer', secondaryRole: 'smm_specialist');
      expect(canSeeDevSection(dualRole), isTrue);
      expect(canSeeSmmSection(dualRole), isTrue);
      expect(isStoryWriter(dualRole), isTrue);
    });
  });
}
