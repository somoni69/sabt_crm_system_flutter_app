import 'package:flutter_test/flutter_test.dart';
import 'package:sabt_crm/features/auth/domain/user.dart';

void main() {
  group('UserModel', () {
    test('firstName extracts first word from name safely', () {
      const user = UserModel(
        id: 'u-1',
        name: 'Фарход Сафаров',
        email: 'farhod@webbrand.tj',
        role: 'founder',
      );
      expect(user.firstName, 'Фарход');

      const singleNameUser = UserModel(
        id: 'u-2',
        name: 'Мадина',
        email: 'madina@webbrand.tj',
        role: 'smm_specialist',
      );
      expect(singleNameUser.firstName, 'Мадина');

      const emptyNameUser = UserModel(
        id: 'u-3',
        name: '   ',
        email: 'test@webbrand.tj',
        role: 'employee',
      );
      expect(emptyNameUser.firstName, 'Коллега');
    });

    test('combinedRoleLabel merges primary and secondary roles', () {
      const userWithSecondary = UserModel(
        id: 'u-1',
        name: 'Рустам',
        email: 'rustam@webbrand.tj',
        role: 'designer',
        secondaryRole: 'video_editor',
      );
      expect(userWithSecondary.combinedRoleLabel, 'Дизайнер / Монтажёр');

      const userSingleRole = UserModel(
        id: 'u-2',
        name: 'Фарход',
        email: 'farhod@webbrand.tj',
        role: 'founder',
      );
      expect(userSingleRole.combinedRoleLabel, 'Основатель');
    });

    test('fromJson and toJson maintain data fidelity', () {
      final json = <String, dynamic>{
        'id': 'u-10',
        'name': 'Далер Холов',
        'email': 'daler@webbrand.tj',
        'role': 'videographer',
        'secondaryRole': null,
        'avatar': 'https://crm.webrand.tj/avatars/daler.jpg',
        'isActive': true,
        'isSubAdmin': false,
        'isStoryMaker': true,
        'extraPermissions': ['calendar.view'],
        'deniedPermissions': ['finance.manage'],
        'position': 'Главный видеограф',
        'department': 'Медиа',
        'twoFactorEnabled': true,
        'themeColor': 'accent-blue',
      };

      final user = UserModel.fromJson(json);
      expect(user.id, 'u-10');
      expect(user.name, 'Далер Холов');
      expect(user.position, 'Главный видеограф');
      expect(user.twoFactorEnabled, isTrue);
      expect(user.isStoryMaker, isTrue);
      expect(user.extraPermissions, ['calendar.view']);

      final serialized = user.toJson();
      expect(serialized['id'], 'u-10');
      expect(serialized['twoFactorEnabled'], isTrue);
    });
  });
}
