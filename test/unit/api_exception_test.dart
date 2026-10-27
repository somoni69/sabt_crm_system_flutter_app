import 'package:flutter_test/flutter_test.dart';
import 'package:sabt_crm/core/network/api_exception.dart';

void main() {
  group('ApiException hierarchy', () {
    test('status code helpers reflect HTTP status correctly', () {
      const authErr = ApiException('Unauthorized', statusCode: 401);
      expect(authErr.isUnauthorized, isTrue);
      expect(authErr.isForbidden, isFalse);

      const forbiddenErr = ApiException('Forbidden', statusCode: 403);
      expect(forbiddenErr.isForbidden, isTrue);

      const notFoundErr = ApiException('Not Found', statusCode: 404);
      expect(notFoundErr.isNotFound, isTrue);

      const rateErr = ApiException('Rate limit', statusCode: 429);
      expect(rateErr.isRateLimited, isTrue);
    });

    test('TwoFactorRequiredException sets 401 and specific instruction', () {
      const err = TwoFactorRequiredException();
      expect(err.statusCode, 401);
      expect(err.isUnauthorized, isTrue);
      expect(err.message, contains('аутентификатора'));
    });

    test('AccountBlockedException sets 403 and user reason', () {
      const err = AccountBlockedException('Нарушение правил доступа');
      expect(err.statusCode, 403);
      expect(err.isForbidden, isTrue);
      expect(err.message, 'Нарушение правил доступа');
    });

    test('SessionExpiredException sets 401 and logout message', () {
      const err = SessionExpiredException();
      expect(err.statusCode, 401);
      expect(err.isUnauthorized, isTrue);
      expect(err.message, contains('Сессия истекла'));
    });
  });
}
