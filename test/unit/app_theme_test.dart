import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:sabt_crm/core/cache/cached_json.dart';
import 'package:sabt_crm/core/cache/response_cache.dart';
import 'package:sabt_crm/core/connectivity/connectivity_service.dart';
import 'package:sabt_crm/core/dependencies.dart';
import 'package:sabt_crm/core/firebase/analytics_service.dart';
import 'package:sabt_crm/core/firebase/firebase_bootstrap.dart';
import 'package:sabt_crm/core/firebase/push_service.dart';
import 'package:sabt_crm/core/navigation/navigation_service.dart';
import 'package:sabt_crm/core/network/api_client.dart';
import 'package:sabt_crm/core/network/token_store.dart';
import 'package:sabt_crm/core/realtime/realtime_service.dart';
import 'package:sabt_crm/core/session/heartbeat_service.dart';
import 'package:sabt_crm/core/theme/app_palette.dart';
import 'package:sabt_crm/core/theme/app_theme.dart';
import 'package:sabt_crm/core/theme/theme_mode_provider.dart';
import 'package:sabt_crm/core/widgets/app_banner.dart';

void main() {
  group('AppPalette presets', () {
    test('dark and light keep the canonical Sabt violet as anchor', () {
      expect(AppPalette.dark.brandPurple, const Color(0xFF59479E));
      expect(AppPalette.light.brandPurple, const Color(0xFF59479E));
      expect(AppPalette.dark.brightness, Brightness.dark);
      expect(AppPalette.light.brightness, Brightness.light);
    });

    test('text always contrasts with its own canvas', () {
      expect(
        AppPalette.light.text.computeLuminance(),
        lessThan(AppPalette.light.background.computeLuminance()),
      );
      expect(
        AppPalette.dark.text.computeLuminance(),
        greaterThan(AppPalette.dark.background.computeLuminance()),
      );
    });

    test('lerp crosses over at the midpoint', () {
      final mid = AppPalette.dark.lerp(AppPalette.light, 0.5) as AppPalette;
      expect(mid.background.computeLuminance(), between(0.2, 0.8));
    });
  });

  group('AppTheme wiring', () {
    test('both themes carry their palette as an extension', () {
      expect(AppTheme.dark.brightness, Brightness.dark);
      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.dark.extension<AppPalette>(), AppPalette.dark);
      expect(AppTheme.light.extension<AppPalette>(), AppPalette.light);
    });

    testWidgets('context.palette follows the active theme', (tester) async {
      Color? seen;
      final probe = Builder(
        builder: (context) {
          seen = context.palette.background;
          return const SizedBox();
        },
      );

      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: probe));
      expect(seen, AppPalette.light.background);

      await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: probe));
      // MaterialApp cross-fades themes; the palette lerps with it.
      await tester.pump(const Duration(milliseconds: 250));
      expect(seen, AppPalette.dark.background);
    });
  });

  group('ThemeModeNotifier persistence', () {
    late Directory tempDir;
    late Box<dynamic> prefs;

    Future<AppDependencies> makeDeps() async {
      final cacheBox = await Hive.openBox<dynamic>('cache');
      final tokens = TokenStore(prefs);
      final api = ApiClient(tokens: tokens);
      final cache = ResponseCache(cacheBox);
      final connectivity = ConnectivityService();
      final banners = BannerService();
      final navigation = NavigationService(banners: banners);
      const runtime = FirebaseRuntime.disabled('test');
      final analytics = AnalyticsService(runtime);
      return AppDependencies(
        prefs: prefs,
        tokens: tokens,
        cache: cache,
        api: api,
        cachedJson: CachedJson(
          api: api,
          cache: cache,
          connectivity: connectivity,
        ),
        connectivity: connectivity,
        realtime: RealtimeService(tokens),
        banners: banners,
        analytics: analytics,
        push: PushService(
          api: api,
          navigation: navigation,
          analytics: analytics,
          runtime: runtime,
        ),
        heartbeat: HeartbeatService(api),
        navigation: navigation,
        firebase: runtime,
      );
    }

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      tempDir = await Directory.systemTemp.createTemp('sabt_theme_test');
      Hive.init(tempDir.path);
      prefs = await Hive.openBox<dynamic>('prefs');
    });

    tearDown(() async {
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    test('defaults to dark and round-trips a saved light choice', () async {
      final deps = await makeDeps();

      final first = ProviderContainer(
        overrides: [dependenciesProvider.overrideWithValue(deps)],
      );
      addTearDown(first.dispose);
      expect(first.read(themeModeProvider), ThemeMode.dark);

      await first.read(themeModeProvider.notifier).set(ThemeMode.light);

      final second = ProviderContainer(
        overrides: [dependenciesProvider.overrideWithValue(deps)],
      );
      addTearDown(second.dispose);
      expect(second.read(themeModeProvider), ThemeMode.light);
    });
  });
}

Matcher between(double low, double high) => predicate<double>(
  (value) => value > low && value < high,
  'between $low and $high',
);
