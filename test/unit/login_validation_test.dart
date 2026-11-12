import 'package:flutter_test/flutter_test.dart';
import 'package:webrand_app/features/auth/domain/login_validation.dart';

void main() {
  group('LoginValidation.login', () {
    test('accepts a well-formed work e-mail', () {
      expect(LoginValidation.login('farzod@webbrand.tj'), isNull);
    });

    test('accepts a plain username of three or more characters', () {
      expect(LoginValidation.login('farzod'), isNull);
    });

    test('trims surrounding whitespace before judging', () {
      expect(LoginValidation.login('  farzod@webbrand.tj  '), isNull);
    });

    test('rejects an empty value', () {
      expect(LoginValidation.login('   '), isNotNull);
    });

    test('rejects a malformed e-mail', () {
      expect(LoginValidation.login('farzod@webbrand'), isNotNull);
      expect(LoginValidation.login('farzod@.tj'), isNotNull);
    });

    test('rejects a two-character username', () {
      expect(LoginValidation.login('ab'), isNotNull);
    });
  });

  group('LoginValidation.password', () {
    test('accepts any non-empty password', () {
      expect(LoginValidation.password('x'), isNull);
    });

    test('rejects an empty password', () {
      expect(LoginValidation.password(''), isNotNull);
    });
  });

  group('LoginValidation.twoFactorCode', () {
    test('accepts exactly six digits', () {
      expect(LoginValidation.twoFactorCode('123456'), isNull);
    });

    test('rejects short, long and non-numeric codes', () {
      expect(LoginValidation.twoFactorCode('12345'), isNotNull);
      expect(LoginValidation.twoFactorCode('1234567'), isNotNull);
      expect(LoginValidation.twoFactorCode('12a456'), isNotNull);
      expect(LoginValidation.twoFactorCode(''), isNotNull);
    });
  });

  group('LoginValidation.recoveryEmail', () {
    test('requires a real e-mail, not a username', () {
      expect(LoginValidation.recoveryEmail('farzod'), isNotNull);
      expect(LoginValidation.recoveryEmail('farzod@webbrand.tj'), isNull);
    });
  });

  group('normalizers', () {
    test('code normalization keeps digits only', () {
      expect(LoginValidation.normalizeCode('12 34-56'), '123456');
    });

    test('login normalization trims', () {
      expect(LoginValidation.normalizeLogin('  a@b.tj '), 'a@b.tj');
    });
  });
}
