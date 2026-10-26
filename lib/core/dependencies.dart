import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

import 'cache/cached_json.dart';
import 'cache/response_cache.dart';
import 'connectivity/connectivity_service.dart';
import 'firebase/analytics_service.dart';
import 'firebase/firebase_bootstrap.dart';
import 'firebase/push_service.dart';
import 'navigation/navigation_service.dart';
import 'network/api_client.dart';
import 'network/token_store.dart';
import 'realtime/realtime_service.dart';
import 'session/heartbeat_service.dart';
import 'widgets/app_banner.dart';

class AppDependencies {
  AppDependencies({
    required this.prefs,
    required this.tokens,
    required this.cache,
    required this.api,
    required this.cachedJson,
    required this.connectivity,
    required this.realtime,
    required this.banners,
    required this.analytics,
    required this.push,
    required this.heartbeat,
    required this.navigation,
    required this.firebase,
  });

  final Box<dynamic> prefs;
  final TokenStore tokens;
  final ResponseCache cache;
  final ApiClient api;
  final CachedJson cachedJson;
  final ConnectivityService connectivity;
  final RealtimeService realtime;
  final BannerService banners;
  final AnalyticsService analytics;
  final PushService push;
  final HeartbeatService heartbeat;
  final NavigationService navigation;
  final FirebaseRuntime firebase;
}

final dependenciesProvider = Provider<AppDependencies>((ref) {
  throw UnimplementedError('AppDependencies must be overridden in main.dart');
});
