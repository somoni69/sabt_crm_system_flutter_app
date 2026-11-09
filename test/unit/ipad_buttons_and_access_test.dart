import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabt_crm/core/design/liquid_glass_bar.dart';
import 'package:sabt_crm/core/theme/app_theme.dart';
import 'package:sabt_crm/core/widgets/app_controls.dart';
import 'package:sabt_crm/core/widgets/app_page.dart';
import 'package:sabt_crm/features/access/data/access_repository.dart';
import 'package:sabt_crm/features/access/domain/access_models.dart';
import 'package:sabt_crm/features/access/presentation/access_providers.dart';
import 'package:sabt_crm/features/access/presentation/employee_access_page.dart';
import 'package:sabt_crm/features/auth/domain/user.dart';
import 'package:sabt_crm/features/auth/presentation/auth_controller.dart';
import 'package:sabt_crm/features/work_shifts/presentation/work_shift_card.dart';

void main() {
  group('iPad Button & Sheet Hit-Testing Across Resolutions', () {
    for (final ipadSize in const [
      Size(768, 1024), // iPad mini / 9.7" Portrait
      Size(834, 1194), // iPad Air / Pro 11" Portrait
      Size(1024, 1366), // iPad Pro 12.9" / 13" Portrait
      Size(1194, 834), // iPad Pro 11" Landscape
      Size(1366, 1024), // iPad Pro 12.9" / 13" Landscape
    ]) {
      testWidgets(
        'showGlassSheet and showConfirmSheet buttons are wide and tappable on iPad ${ipadSize.width.toInt()}x${ipadSize.height.toInt()}',
        (tester) async {
          tester.view.physicalSize = ipadSize;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          var sheetActionPressed = false;
          var confirmPressed = false;

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.dark,
              home: Scaffold(
                body: Builder(
                  builder: (context) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppButton(
                          label: 'Открыть шторку проекта',
                          onPressed: () {
                            showGlassSheet<void>(
                              context: context,
                              title: 'Настройки проекта',
                              subtitle: 'Проверка нажатия кнопок на iPad',
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  AppButton(
                                    label: 'Сохранить проект',
                                    expand: true,
                                    onPressed: () {
                                      sheetActionPressed = true;
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          label: 'Открыть подтверждение',
                          onPressed: () {
                            showConfirmSheet(
                              context: context,
                              title: 'Удалить объявление?',
                              message: 'Проверка кнопки подтверждения на iPad.',
                              confirmLabel: 'Удалить сейчас',
                              danger: true,
                              onConfirm: () async {
                                confirmPressed = true;
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();

          // Open glass sheet on iPad
          await tester.tap(find.text('Открыть шторку проекта'));
          await tester.pumpAndSettle();

          final saveBtnFinder = find.text('Сохранить проект');
          expect(saveBtnFinder, findsOneWidget);

          // Verify button inside sheet did NOT collapse on wide iPad screen
          final btnSize = tester.getSize(saveBtnFinder);
          expect(btnSize.width, greaterThan(100));

          await tester.tap(saveBtnFinder);
          await tester.pumpAndSettle();
          expect(sheetActionPressed, isTrue);

          // Open confirm sheet on iPad
          await tester.tap(find.text('Открыть подтверждение'));
          await tester.pumpAndSettle();

          final confirmBtnFinder = find.text('Удалить сейчас');
          expect(confirmBtnFinder, findsOneWidget);
          await tester.tap(confirmBtnFinder);
          await tester.pumpAndSettle();
          expect(confirmPressed, isTrue);
        },
      );
    }

    testWidgets('LiquidGlassNavBar tabs are tappable on iPad Pro 1366x1024', (tester) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      int selectedTab = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LiquidGlassNavBar(
                      selectedIndex: selectedTab,
                      onSelected: (index) => setState(() => selectedTab = index),
                      items: const [
                        GlassNavItem(
                          icon: Icons.grid_view_outlined,
                          activeIcon: Icons.grid_view_rounded,
                          label: 'Главная',
                        ),
                        GlassNavItem(
                          icon: Icons.checklist_outlined,
                          activeIcon: Icons.checklist_rounded,
                          label: 'Задачи',
                        ),
                        GlassNavItem(
                          icon: Icons.workspaces_outline,
                          activeIcon: Icons.workspaces_rounded,
                          label: 'Проекты',
                        ),
                        GlassNavItem(
                          icon: Icons.more_horiz_rounded,
                          activeIcon: Icons.more_rounded,
                          label: 'Ещё',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Проекты'));
      await tester.pumpAndSettle();
      expect(selectedTab, 2);
      expect(find.byIcon(Icons.add_rounded), findsNothing);
    });

    testWidgets('EmployeeAccessPage renders roles audit and opens 3-state permissions sheet on iPad', (tester) async {
      tester.view.physicalSize = const Size(1024, 1366);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockUsers = [
        const AccessUser(
          id: 'u-1',
          name: 'Дилноза Рахимова',
          email: 'dilnoza@webbrand.tj',
          role: 'smm_specialist',
          position: 'SMM-специалист',
          extraPermissions: ['finance.manage'],
          deniedPermissions: ['tasks.delete'],
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accessUsersProvider.overrideWith((ref) async => mockUsers),
            accessCatalogProvider.overrideWith((ref) async => defaultAccessCatalog),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const EmployeeAccessPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Доступы сотрудников'), findsOneWidget);
      expect(find.text('Дилноза Рахимова'), findsOneWidget);
      expect(find.text('Персональных прав: 1'), findsOneWidget);
      expect(find.text('−1 снято'), findsOneWidget);

      // Expand Roles Audit card
      await tester.tap(find.text('Роли: кто на них сидит'));
      await tester.pumpAndSettle();
      expect(find.textContaining('SMM-специалист'), findsWidgets);

      // Open employee permissions sheet on iPad
      await tester.tap(find.text('Дилноза Рахимова'));
      await tester.pumpAndSettle();

      expect(find.text('Права: Дилноза Рахимова'), findsOneWidget);
      expect(find.text('Сохранить права'), findsOneWidget);
      expect(find.text('Сбросить к роли'), findsOneWidget);
    });

    testWidgets('WorkShiftBannerCard renders status text and action button inside Row without BoxConstraints(w=Infinity) crash', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(
              const UserModel(
                id: 'dev-1',
                name: 'Фарзод',
                email: 'farzod@sabt.tj',
                role: 'developer',
              ),
            ),
            myWorkShiftProvider.overrideWith(
              (ref) async => const WorkShiftData(
                state: 'working',
                todayMinutes: 145,
                closedMinutes: 145,
                normMinutes: 480,
                normStart: '09:00',
                normEnd: '18:00',
                paidBreakMinutes: 30,
                isLate: false,
                dayStartedLabel: '09:05',
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16),
                child: WorkShiftBannerCard(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('2 ч 25 м · идёт смена'), findsOneWidget);
      expect(find.text('Смена'), findsOneWidget);
    });
  });
}
