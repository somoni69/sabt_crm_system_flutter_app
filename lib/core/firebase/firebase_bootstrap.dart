import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../config/app_env.dart';

class FirebaseRuntime {
  const FirebaseRuntime({
    required this.initialized,
    required this.analyticsEnabled,
    required this.crashlyticsEnabled,
    required this.messagingEnabled,
    this.reason,
  });

  const FirebaseRuntime.disabled(String this.reason)
      : initialized = false,
        analyticsEnabled = false,
        crashlyticsEnabled = false,
        messagingEnabled = false;

  final bool initialized;
  final bool analyticsEnabled;
  final bool crashlyticsEnabled;
  final bool messagingEnabled;
  final String? reason;
}

abstract final class FirebaseBootstrap {
  static Future<FirebaseRuntime> initialize() async {
    if (kIsWeb) {
      // Web messaging needs a service worker + VAPID key. The mobile app is the
      // primary target, and the web build is intentionally used only for QA.
      if (!AppEnv.firebaseConfigured) {
        return const FirebaseRuntime.disabled(
          'Firebase не настроен (задайте FIREBASE_* через --dart-define)',
        );
      }
    }

    if (AppEnv.isDesktop) {
      return const FirebaseRuntime.disabled(
        'Firebase на desktop отключён — пуши и Crashlytics работают на Android/iOS',
      );
    }

    if (!AppEnv.firebaseConfigured) {
      return const FirebaseRuntime.disabled(
        'Firebase не настроен (задайте FIREBASE_* через --dart-define)',
      );
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: AppEnv.firebaseApiKey,
            appId: AppEnv.firebaseAppId!,
            messagingSenderId: AppEnv.firebaseSenderId,
            projectId: AppEnv.firebaseProjectId,
            storageBucket: AppEnv.firebaseStorageBucket.isEmpty
                ? null
                : AppEnv.firebaseStorageBucket,
            iosBundleId: AppEnv.isIOS ? AppEnv.firebaseIosBundleId : null,
          ),
        );
      }

      var crashlytics = false;
      if (!kIsWeb) {
        try {
          await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
          crashlytics = true;
          FlutterError.onError = (details) {
            FirebaseCrashlytics.instance.recordFlutterFatalError(details);
            FlutterError.presentError(details);
          };
          PlatformDispatcher.instance.onError = (error, stack) {
            FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
            return true;
          };
        } catch (error) {
          debugPrint('Crashlytics init failed: $error');
        }
      }

      var analytics = false;
      try {
        await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(!kDebugMode);
        analytics = true;
      } catch (error) {
        debugPrint('Analytics init failed: $error');
      }

      return FirebaseRuntime(
        initialized: true,
        analyticsEnabled: analytics,
        crashlyticsEnabled: crashlytics,
        messagingEnabled: !kIsWeb,
      );
    } catch (error, stack) {
      debugPrint('Firebase initialization failed: $error\n$stack');
      return FirebaseRuntime.disabled('Firebase не инициализирован: $error');
    }
  }
}
