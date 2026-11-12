import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/dependencies.dart';
import 'core/design/ambient_background.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/widgets/app_banner.dart';
import 'features/auth/presentation/auth_controller.dart';

class WeBrandApp extends ConsumerStatefulWidget {
  const WeBrandApp({super.key});

  @override
  ConsumerState<WeBrandApp> createState() => _WeBrandAppState();
}

typedef SabtApp = WeBrandApp;

/// Platform scroll: bounce on iOS, clamp on Android. The glow stays off
/// so both platforms share the same quiet edge.
class _WeBrandScrollBehavior extends MaterialScrollBehavior {
  const _WeBrandScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    switch (getPlatform(context)) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        );
      default:
        return const ClampingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        );
    }
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class _WeBrandAppState extends ConsumerState<WeBrandApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final controller = ref.read(authControllerProvider.notifier);
    unawaited(controller.onAppResumed());
    if (ref.read(authSessionProvider) != null) {
      unawaited(controller.refreshMe());
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final deps = ref.watch(dependenciesProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'WeBrand',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      scrollBehavior: const _WeBrandScrollBehavior(),
      routerConfig: router,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            systemNavigationBarDividerColor: Colors.transparent,
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(decoration: TextDecoration.none),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: RepaintBoundary(
                    child: AmbientBackground(),
                  ),
                ),
                Positioned.fill(child: child ?? const SizedBox.shrink()),
                AppBannerHost(
                  service: deps.banners,
                  onOpen: (link) => deps.navigation.handleLink(link),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
