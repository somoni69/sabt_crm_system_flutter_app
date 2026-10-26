import '../../../core/dependencies.dart';
import '../../../core/network/api_exception.dart';
import '../domain/user.dart';

class AuthSession {
  const AuthSession({
    required this.user,
    this.restoredOffline = false,
  });

  final UserModel user;
  final bool restoredOffline;
}

class AuthRepository {
  AuthRepository(this.deps);

  final AppDependencies deps;

  Future<AuthSession> login({
    required String email,
    required String password,
    String? twoFactorCode,
  }) async {
    final body = <String, dynamic>{
      'email': email.trim(),
      'password': password,
    };
    if (twoFactorCode != null && twoFactorCode.trim().isNotEmpty) {
      body['twoFactorCode'] = twoFactorCode.trim();
    }

    final data = await deps.api.postJson('/auth/login', body: body);
    if (data is! Map) {
      throw const ApiException('Неожиданный ответ сервера при входе');
    }
    final token = data['token'] as String?;
    final refreshToken = data['refreshToken'] as String?;
    final userJson = data['user'];
    if (token == null || refreshToken == null || userJson is! Map<String, dynamic>) {
      throw const ApiException('Сервер не вернул токены авторизации');
    }

    await deps.tokens.setTokens(
      accessToken: token,
      refreshToken: refreshToken,
      user: userJson,
    );
    return AuthSession(user: UserModel.fromJson(userJson));
  }

  Future<AuthSession?> restore() async {
    if (!deps.tokens.hasSession) return null;

    try {
      final data = await deps.api.getJson('/auth/me');
      if (data is! Map<String, dynamic>) return null;
      await deps.tokens.saveUserSnapshot(data);
      return AuthSession(user: UserModel.fromJson(data));
    } on SessionExpiredException {
      await deps.tokens.clearAll();
      return null;
    } on AccountBlockedException {
      await deps.tokens.clearAll();
      return null;
    } on ApiException catch (error) {
      if (error.isNetwork) {
        final cached = deps.tokens.cachedUser;
        if (cached != null) {
          return AuthSession(
            user: UserModel.fromJson(cached),
            restoredOffline: true,
          );
        }
        return null;
      }
      if (error.isUnauthorized || error.isForbidden) {
        await deps.tokens.clearAll();
        return null;
      }
      rethrow;
    }
  }

  Future<UserModel> me() async {
    final data = await deps.api.getJson('/auth/me');
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Не удалось обновить профиль');
    }
    await deps.tokens.saveUserSnapshot(data);
    return UserModel.fromJson(data);
  }

  Future<void> logout() async {
    try {
      await deps.api.postJson('/auth/logout');
    } catch (_) {
      // Local session must be cleared even when the network is down.
    }
    await deps.tokens.clearAll();
  }

  Future<void> forgotPassword(String email) async {
    await deps.api.postJson('/auth/forgot-password', body: {'email': email.trim()});
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await deps.api.patchJson('/auth/change-password', body: {
      'oldPassword': oldPassword,
      'newPassword': newPassword,
    });
  }

  Future<List<dynamic>> sessions({int days = 7}) async {
    final data = await deps.api.getJson('/auth/sessions', query: {'days': days});
    return data is List ? data : const [];
  }

  Future<void> saveProfile(Map<String, dynamic> json) async {
    await deps.tokens.saveUserSnapshot(json);
  }

  Future<Map<String, dynamic>> setupTwoFactor() async {
    final data = await deps.api.postJson('/auth/2fa/setup');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<void> enableTwoFactor(String code) async {
    await deps.api.postJson('/auth/2fa/enable', body: {'code': code.trim()});
  }

  Future<void> disableTwoFactor(String code) async {
    await deps.api.postJson('/auth/2fa/disable', body: {'code': code.trim()});
  }
}
