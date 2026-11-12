import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../navigation/navigation_service.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import 'analytics_service.dart';
import 'firebase_bootstrap.dart';

class AppPushMessage {
  const AppPushMessage({required this.title, required this.body, this.link});

  final String title;
  final String body;
  final String? link;
}

/// FCM is already implemented on the backend (`POST /users/register-fcm` and
/// `firebase-admin` multicast). This service closes the mobile loop: permission,
/// token lifecycle, foreground delivery, deep link on tap.
class PushService {
  PushService({
    required this.api,
    required this.navigation,
    required this.analytics,
    required this.runtime,
  });

  final ApiClient api;
  final NavigationService navigation;
  final AnalyticsService analytics;
  final FirebaseRuntime runtime;

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  final StreamController<AppPushMessage> _foreground =
      StreamController<AppPushMessage>.broadcast();

  Stream<AppPushMessage> get foregroundMessages => _foreground.stream;

  bool _active = false;
  bool _initialized = false;
  bool _localReady = false;
  String? _token;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedSub;
  StreamSubscription<String>? _onTokenSub;

  bool Function()? isRealtimeConnected;

  bool get _messagingAvailable =>
      runtime.messagingEnabled && runtime.initialized && !kIsWeb;

  Future<void> init() async {
    if (_initialized || !_messagingAvailable) return;
    _initialized = true;
    await _initLocalNotifications();

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: true,
    );

    _onMessageSub = FirebaseMessaging.onMessage.listen(_handleForeground);
    _onOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleOpened);
    _onTokenSub = FirebaseMessaging.instance.onRegistered.listen((token) {
      _token = token;
      if (_active) unawaited(_register(token));
    });

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _handleOpened(initial);
  }

  Future<void> start(String userId) async {
    _active = true;
    await analytics.setUserId(userId);
    if (!_messagingAvailable) return;
    await init();

    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
          alert: false,
          badge: true,
          sound: true,
        );
      }
      await FirebaseMessaging.instance.register();
    } catch (error, stack) {
      debugPrint('PushService.start failed: $error\n$stack');
      await analytics.recordError(error, stack);
    }
  }

  Future<void> stop({bool unregister = true}) async {
    _active = false;
    if (!_messagingAvailable) return;
    final token = _token;
    if (unregister && token != null) {
      try {
        await api.postJson('/users/unregister-fcm', body: {'token': token});
      } on ApiException catch (error) {
        debugPrint('unregister-fcm failed: ${error.message}');
      }
    }
    try {
      await FirebaseMessaging.instance.unregister();
    } catch (_) {}
    _token = null;
  }

  Future<void> _register(String token) async {
    try {
      await api.postJson('/users/register-fcm', body: {'token': token});
      await analytics.logEvent('fcm_token_registered');
    } on ApiException catch (error) {
      debugPrint('register-fcm failed: ${error.message}');
    } catch (error) {
      debugPrint('register-fcm failed: $error');
    }
  }

  void _handleForeground(RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title']?.toString() ?? 'WeBrand';
    final body = message.notification?.body ?? message.data['body']?.toString() ?? '';
    if (body.isEmpty && title.isEmpty) return;
    final link = message.data['link']?.toString();
    _foreground.add(AppPushMessage(title: title, body: body, link: link));
    unawaited(analytics.logEvent('push_received', {
      'link': link ?? '',
    }));

    // Socket.IO normally renders the in-app banner. If it is disconnected,
    // fall back to a native local notification so the event is not lost.
    if (!(isRealtimeConnected?.call() ?? false)) {
      unawaited(_showLocal(title, body));
    }
  }

  void _handleOpened(RemoteMessage message) {
    final link = message.data['link']?.toString();
    navigation.handleLink(link);
    unawaited(analytics.logEvent('push_opened', {'link': link ?? ''}));
  }

  Future<void> _initLocalNotifications() async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) return;
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _local.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) {
          navigation.handleLink(response.payload);
        },
      );

      if (defaultTargetPlatform == TargetPlatform.android) {
        const channel = AndroidNotificationChannel(
          'webrand_push',
          'WeBrand — уведомления',
          description: 'Задачи, дедлайны, оплаты и упоминания',
          importance: Importance.high,
        );
        await _local
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
        await _local
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
      _localReady = true;
    } catch (error) {
      debugPrint('Local notifications init failed: $error');
    }
  }

  Future<void> _showLocal(String title, String body) async {
    if (!_localReady) return;
    try {
      await _local.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: title,
        body: body,
        payload: null,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'webrand_push',
            'WeBrand — уведомления',
            channelDescription: 'Задачи, дедлайны, оплаты и упоминания',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (error) {
      debugPrint('Local notification failed: $error');
    }
  }

  void dispose() {
    _onMessageSub?.cancel();
    _onOpenedSub?.cancel();
    _onTokenSub?.cancel();
    _foreground.close();
  }
}
