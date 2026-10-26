class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.data,
    this.isNetwork = false,
    this.isValidation = false,
  });

  final String message;
  final int? statusCode;
  final dynamic data;
  final bool isNetwork;
  final bool isValidation;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class TwoFactorRequiredException extends ApiException {
  const TwoFactorRequiredException()
      : super('Введите код из приложения-аутентификатора', statusCode: 401);
}

class AccountBlockedException extends ApiException {
  const AccountBlockedException(super.message) : super(statusCode: 403);
}

class SessionExpiredException extends ApiException {
  const SessionExpiredException()
      : super('Сессия истекла — войдите заново', statusCode: 401);
}
