import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabt_crm/core/network/api_exception.dart';
import 'package:sabt_crm/core/theme/app_theme.dart';
import 'package:sabt_crm/features/auth/data/auth_repository.dart';
import 'package:sabt_crm/features/auth/presentation/auth_controller.dart';
import 'package:sabt_crm/features/auth/presentation/login_page.dart';
import 'package:sabt_crm/features/auth/presentation/widgets/login_button.dart';
import 'package:sabt_crm/features/auth/presentation/widgets/otp_field.dart';
import 'package:sabt_crm/features/auth/presentation/widgets/shake.dart';

void main() {
  group('OtpField', () {
    testWidgets('mirrors typed digits into cells and completes at six', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      String? completed;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: OtpField(
                controller: controller,
                onCompleted: (value) => completed = value,
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();

      expect(completed, '123456');
      for (final digit in ['1', '2', '3', '4', '5', '6']) {
        expect(find.text(digit), findsOneWidget);
      }

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('ignores non-digits and never exceeds six cells', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OtpField(controller: controller)),
        ),
      );

      await tester.enterText(find.byType(TextField), '12a3');
      await tester.pump();

      expect(controller.text, '123');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('LoginButton', () {
    testWidgets('idle fires onPressed, loading does not', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginButton(
              phase: LoginButtonPhase.idle,
              label: 'Войти',
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Войти'));
      await tester.pump();
      expect(taps, 1);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoginButton(phase: LoginButtonPhase.loading, label: 'Войти'),
          ),
        ),
      );
      expect(find.text('Входим…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('success shows the welcome state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoginButton(phase: LoginButtonPhase.success, label: 'Войти'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.text('Добро пожаловать'), findsOneWidget);
    });
  });

  group('Shake', () {
    testWidgets('moves horizontally only while the shake runs', (tester) async {
      var signal = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  Shake(signal: signal, child: const Text('Карточка')),
                  TextButton(
                    onPressed: () => setState(() => signal++),
                    child: const Text('Трясти'),
                  ),
                ],
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Трясти'));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 60));

      final transform = tester.widget<Transform>(
        find
            .ancestor(
              of: find.text('Карточка'),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(transform.transform.getTranslation().x, isNot(0));

      await tester.pump(const Duration(milliseconds: 420));
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('LoginPage', () {
    void usePhoneViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('reduced motion renders instantly and validates empty form', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final fake = _FakeAuthController();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authControllerProvider.overrideWith(() => fake)],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: LoginPage(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Войти'), findsNWidgets(2));

      await tester.tap(find.widgetWithText(LoginButton, 'Войти'));
      await tester.pump();

      expect(find.text('Введите логин или почту'), findsOneWidget);
      expect(find.text('Введите пароль'), findsOneWidget);
      expect(fake.loginCalls, 0);
    });

    testWidgets('valid credentials reach the auth controller normalized', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final fake = _FakeAuthController();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authControllerProvider.overrideWith(() => fake)],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: LoginPage(),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byType(TextField).at(0),
        '  farzod@webbrand.tj ',
      );
      await tester.enterText(find.byType(TextField).at(1), 'secret');
      await tester.tap(find.widgetWithText(LoginButton, 'Войти'));
      await tester.pump();

      expect(fake.loginCalls, 1);
      expect(fake.lastEmail, 'farzod@webbrand.tj');
      expect(fake.lastPassword, 'secret');
    });

    testWidgets('a two-factor challenge reveals the OTP cells', (tester) async {
      usePhoneViewport(tester);
      final fake = _FakeAuthController()..requireTwoFactor = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authControllerProvider.overrideWith(() => fake)],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: LoginPage(),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byType(TextField).at(0),
        'farzod@webbrand.tj',
      );
      await tester.enterText(find.byType(TextField).at(1), 'secret');
      await tester.tap(find.widgetWithText(LoginButton, 'Войти'));
      await tester.pump();

      expect(find.text('Подтвердите вход'), findsOneWidget);
      expect(find.byType(OtpField), findsOneWidget);
    });

    testWidgets('theme pill toggles brightness on the web sign-in card', (
      tester,
    ) async {
      usePhoneViewport(tester);
      final fake = _FakeAuthController();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authControllerProvider.overrideWith(() => fake)],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: LoginPage(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Войти'), findsWidgets);
      expect(find.text('Тёмная'), findsOneWidget);
      await tester.tap(find.text('Тёмная'));
      await tester.pump();
      expect(find.text('Светлая'), findsOneWidget);
    });
  });
}

class _FakeAuthController extends AuthController {
  int loginCalls = 0;
  String? lastEmail;
  String? lastPassword;
  bool requireTwoFactor = false;

  @override
  Future<AuthSession?> build() async => null;

  @override
  Future<void> login({
    required String email,
    required String password,
    String? twoFactorCode,
  }) async {
    loginCalls++;
    lastEmail = email;
    lastPassword = password;
    if (requireTwoFactor && twoFactorCode == null) {
      throw const TwoFactorRequiredException();
    }
  }
}
