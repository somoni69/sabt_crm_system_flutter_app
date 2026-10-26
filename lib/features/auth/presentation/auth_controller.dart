import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dependencies.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/widgets/app_banner.dart';
import '../data/auth_repository.dart';
import '../domain/user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dependenciesProvider));
});

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authControllerProvider).value?.user;
});

final authSessionProvider = Provider<AuthSession?>((ref) {
  return ref.watch(authControllerProvider).value;
});

final permissionsProvider = Provider<List<String>>((ref) {
  return effectivePermissions(ref.watch(currentUserProvider));
});

class AuthController extends AsyncNotifier<AuthSession?> {
  String? _servicesFor;
  bool _loggingOut = false;

  AppDependencies get _deps => ref.read(dependenciesProvider);
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<AuthSession?> build() async {
    final deps = ref.watch(dependenciesProvider);
    deps.api.onSessionExpired = () {
      unawaited(_expire(reason: 'Сессия истекла — войдите заново'));
    };

    final session = await ref.watch(authRepositoryProvider).restore();
    if (session != null) {
      unawaited(_startServices(session.user));
    }
    return session;
  }

  Future<void> _startServices(UserModel user) async {
    if (_servicesFor == user.id) return;
    _servicesFor = user.id;
    final deps = _deps;
    deps.realtime.connect();
    deps.heartbeat.start();
    await deps.analytics.setUserId(user.id);
    await deps.push.start(user.id);
  }

  Future<void> _stopServices({bool unregisterPush = true}) async {
    _servicesFor = null;
    final deps = _deps;
    deps.heartbeat.stop();
    deps.realtime.disconnect();
    await deps.push.stop(unregister: unregisterPush);
  }

  Future<void> login({
    required String email,
    required String password,
    String? twoFactorCode,
  }) async {
    try {
      final session = await _repo.login(
        email: email,
        password: password,
        twoFactorCode: twoFactorCode,
      );
      state = AsyncData(session);
      await _startServices(session.user);
      unawaited(_deps.analytics.logLogin(method: 'password'));
      _deps.banners.show(const AppBanner(
        title: 'Добро пожаловать',
        message: 'Рабочее пространство Sabt готово.',
        tone: BannerTone.accent,
      ));
    } catch (error) {
      rethrow;
    }
  }

  Future<void> refreshMe() async {
    try {
      final user = await _repo.me();
      final session = state.value;
      state = AsyncData(AuthSession(
        user: user,
        restoredOffline: session?.restoredOffline ?? false,
      ));
    } catch (error) {
      debugPrint('refreshMe failed: $error');
    }
  }

  Future<void> logout() async {
    if (_loggingOut) return;
    _loggingOut = true;
    final user = state.value?.user;
    try {
      await _stopServices();
      await _repo.logout();
      if (user != null) await _deps.cache.clearUser(user.id);
      await _deps.cache.clearAll();
      await _deps.analytics.setUserId(null);
      state = const AsyncData(null);
    } finally {
      _loggingOut = false;
    }
  }

  Future<void> _expire({required String reason}) async {
    if (_loggingOut) return;
    final current = state.value;
    if (current == null) return;
    _loggingOut = true;
    try {
      await _stopServices(unregisterPush: false);
      await _deps.tokens.clearAll();
      await _deps.cache.clearUser(current.user.id);
      await _deps.cache.clearAll();
      state = const AsyncData(null);
      _deps.banners.show(AppBanner(
        title: 'Нужно войти заново',
        message: reason,
        tone: BannerTone.warning,
      ));
    } finally {
      _loggingOut = false;
    }
  }

  Future<void> loginWithPasswordChangedReminder() async {
    _deps.banners.show(const AppBanner(
      title: 'Пароль был изменён',
      message: 'Войдите заново с новым паролем.',
      tone: BannerTone.warning,
    ));
    await _expire(reason: 'Пароль был изменён на другом устройстве');
  }

  Future<void> onAppResumed() async {
    final deps = _deps;
    unawaited(deps.connectivity.refresh());
    deps.realtime.ensureConnected();
    unawaited(deps.heartbeat.beat());
  }
}
