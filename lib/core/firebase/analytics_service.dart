import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'firebase_bootstrap.dart';

/// Thin, failure-tolerant wrapper. The app must never break because analytics
/// or crash reporting is unavailable (e.g. on a desktop dev build).
class AnalyticsService {
  AnalyticsService(this.runtime);

  final FirebaseRuntime runtime;

  bool get enabled => runtime.analyticsEnabled;

  Future<void> setUserId(String? userId) async {
    if (!enabled) return;
    try {
      await FirebaseAnalytics.instance.setUserId(id: userId);
      if (runtime.crashlyticsEnabled) {
        await FirebaseCrashlytics.instance.setUserIdentifier(userId ?? '');
      }
    } catch (error) {
      debugPrint('analytics.setUserId: $error');
    }
  }

  Future<void> logLogin({String? method}) async {
    if (!enabled) return;
    try {
      await FirebaseAnalytics.instance.logLogin(loginMethod: method ?? 'password');
    } catch (_) {}
  }

  Future<void> logScreen(String name) async {
    if (!enabled) return;
    try {
      await FirebaseAnalytics.instance.logScreenView(screenName: name);
    } catch (_) {}
  }

  Future<void> logEvent(String name, [Map<String, Object>? params]) async {
    if (!enabled) return;
    try {
      await FirebaseAnalytics.instance.logEvent(name: name, parameters: params);
    } catch (_) {}
  }

  Future<void> recordError(Object error, StackTrace stack, {bool fatal = false}) async {
    if (!runtime.crashlyticsEnabled) {
      debugPrint('Crashlytics disabled: $error');
      return;
    }
    try {
      await FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal);
    } catch (_) {}
  }
}
