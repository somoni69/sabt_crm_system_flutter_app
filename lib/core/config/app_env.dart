import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Compile-time configuration. All values can be overridden with
/// `--dart-define` (or `--dart-define-from-file=env.json`).
abstract final class AppEnv {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://sabtcrmsystem-production.up.railway.app/api',
  );

  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'https://sabtcrmsystem-production.up.railway.app',
  );

  /// Browser build of Sabt CRM. Used by the "open in web" hand-off screen.
  static const String webBaseUrl = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'https://crm.webrand.tj',
  );

  /// Origin used for `/api/avatars/...` and `/uploads/...` links.
  static String get apiOrigin {
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null) return wsBaseUrl;
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port';
  }

  static String get wsNamespaceUrl {
    final base = wsBaseUrl.replaceAll(RegExp(r'/$'), '');
    return '$base/ws';
  }

  // ─── Firebase (defaults to tjsabt-crm, overridable with --dart-define) ─
  static const String firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyBdb9kZ16J7pLqVMJP1uRZ09oOrR9E5DBM',
  );
  static const String firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'tjsabt-crm',
  );
  static const String firebaseSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '619703292379',
  );
  static const String firebaseStorageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: 'tjsabt-crm.firebasestorage.app',
  );
  static const String firebaseAndroidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
    defaultValue: '1:619703292379:android:7d995461a798e86e7e57fe',
  );
  static const String firebaseIosAppId = String.fromEnvironment(
    'FIREBASE_IOS_APP_ID',
    defaultValue: '1:619703292379:ios:c9d221921be19eda7e57fe',
  );
  static const String firebaseWebAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const String firebaseIosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
    defaultValue: 'tj.sabt.crm',
  );
  static const String firebaseWebVapidKey = String.fromEnvironment('FIREBASE_WEB_VAPID_KEY');

  static bool get isWeb => kIsWeb;
  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;

  static String? get firebaseAppId {
    if (kIsWeb) return firebaseWebAppId.isEmpty ? null : firebaseWebAppId;
    if (Platform.isAndroid) return firebaseAndroidAppId.isEmpty ? null : firebaseAndroidAppId;
    if (Platform.isIOS) return firebaseIosAppId.isEmpty ? null : firebaseIosAppId;
    return null;
  }

  static bool get firebaseConfigured =>
      !isDesktop &&
      firebaseApiKey.isNotEmpty &&
      firebaseProjectId.isNotEmpty &&
      firebaseSenderId.isNotEmpty &&
      firebaseAppId != null;

  static const String appVersion = '1.0.0';
}
