import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'core/cache/cached_json.dart';
import 'core/cache/response_cache.dart';
import 'core/connectivity/connectivity_service.dart';
import 'core/dependencies.dart';
import 'core/firebase/analytics_service.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/firebase/push_service.dart';
import 'core/navigation/navigation_service.dart';
import 'core/network/api_client.dart';
import 'core/network/token_store.dart';
import 'core/realtime/realtime_service.dart';
import 'core/session/heartbeat_service.dart';
import 'core/widgets/app_banner.dart';

abstract final class AppBootstrap {
  static Future<AppDependencies> initialize() async {
    await Hive.initFlutter();

    final cacheBox = await Hive.openBox<dynamic>('sabt_cache_v1');
    final prefs = await Hive.openBox<dynamic>('sabt_prefs_v1');

    final tokens = TokenStore(prefs);
    await tokens.load();

    final cache = ResponseCache(cacheBox);
    final api = ApiClient(tokens: tokens);
    final connectivity = ConnectivityService();
    final realtime = RealtimeService(tokens);
    final banners = BannerService();
    final navigation = NavigationService(banners: banners);

    final firebase = await FirebaseBootstrap.initialize();
    final analytics = AnalyticsService(firebase);
    final push = PushService(
      api: api,
      navigation: navigation,
      analytics: analytics,
      runtime: firebase,
    );
    push.isRealtimeConnected = () => realtime.isConnected;
    await push.init();
    final heartbeat = HeartbeatService(api);

    final cachedJson = CachedJson(
      api: api,
      cache: cache,
      connectivity: connectivity,
    );

    if (kDebugMode) {
      debugPrint(
        'Sabt bootstrap: api=${ApiEnvLog.api}, firebase=${firebase.initialized}, '
        'secureStorage=${tokens.secureAvailable}',
      );
    }

    return AppDependencies(
      prefs: prefs,
      tokens: tokens,
      cache: cache,
      api: api,
      cachedJson: cachedJson,
      connectivity: connectivity,
      realtime: realtime,
      banners: banners,
      analytics: analytics,
      push: push,
      heartbeat: heartbeat,
      navigation: navigation,
      firebase: firebase,
    );
  }
}

abstract final class ApiEnvLog {
  static const api = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://sabtcrmsystem-production.up.railway.app/api',
  );
}
