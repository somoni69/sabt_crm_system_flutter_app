/// Pure validation for the sign-in form.
///
/// Kept free of Flutter and Riverpod so the rules can be unit-tested
/// without pumping a widget, and so the page never grows its own ad-hoc
/// checks. Every function returns a user-facing message or `null`.
abstract final class LoginValidation {
  static final RegExp _emailPattern = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  static final RegExp _digitsOnly = RegExp(r'^\d+$');

  /// Login accepts either a work e-mail or a plain username.
  static String? login(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return 'Введите логин или почту';
    if (value.contains('@')) {
      return _emailPattern.hasMatch(value)
          ? null
          : 'Проверьте формат почты — например, name@webbrand.tj';
    }
    return value.length >= 3 ? null : 'Логин должен быть не короче 3 символов';
  }

  /// No length policy is invented here: password strength is the
  /// backend's contract, the form only guarantees a non-empty value.
  static String? password(String raw) {
    return raw.isEmpty ? 'Введите пароль' : null;
  }

  static String? twoFactorCode(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return 'Введите шестизначный код';
    if (value.length != 6 || !_digitsOnly.hasMatch(value)) {
      return 'Код состоит из шести цифр';
    }
    return null;
  }

  /// Recovery form: an e-mail is mandatory there, a username is not enough.
  static String? recoveryEmail(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return 'Укажите рабочую почту';
    return _emailPattern.hasMatch(value)
        ? null
        : 'Проверьте формат почты — например, name@webbrand.tj';
  }

  static String normalizeLogin(String raw) => raw.trim();

  static String normalizeCode(String raw) =>
      raw.replaceAll(RegExp(r'\D'), '').trim();
}
