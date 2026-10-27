import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design/ambient_background.dart';
import 'core/dependencies.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/widgets/app_banner.dart';
import 'features/auth/presentation/auth_controller.dart';

class SabtApp extends ConsumerStatefulWidget {
  const SabtApp({super.key});

  @override
  ConsumerState<SabtApp> createState() => _SabtAppState();
}

/// iOS-style scrolling everywhere: elastic bounce, no Android glow.
/// On iOS this matches the platform; on Android it keeps the glass
/// surfaces free of the stock overscroll flash.
class _SabtScrollBehavior extends MaterialScrollBehavior {
  const _SabtScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
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

class _SabtAppState extends ConsumerState<SabtApp> with WidgetsBindingObserver {
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
      title: 'Sabt',
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
      scrollBehavior: const _SabtScrollBehavior(),
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
          child: Stack(
            children: [
              const Positioned.fill(
                child: RepaintBoundary(
                  child: AmbientBackground(animate: false),
                ),
              ),
              Positioned.fill(child: child ?? const SizedBox.shrink()),
              AppBannerHost(
                service: deps.banners,
                onOpen: (link) => deps.navigation.handleLink(link),
              ),
            ],
          ),
        );
      },
    );
  }
}
