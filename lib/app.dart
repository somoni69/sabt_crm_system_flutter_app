import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design/ambient_background.dart';
import 'core/dependencies.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_banner.dart';
import 'features/auth/presentation/auth_controller.dart';

class SabtApp extends ConsumerStatefulWidget {
  const SabtApp({super.key});

  @override
  ConsumerState<SabtApp> createState() => _SabtAppState();
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

    return MaterialApp.router(
      title: 'Sabt',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) {
        return Stack(
          children: [
            const Positioned.fill(
              child: RepaintBoundary(child: AmbientBackground()),
            ),
            Positioned.fill(child: child ?? const SizedBox.shrink()),
            AppBannerHost(
              service: deps.banners,
              onOpen: (link) => deps.navigation.handleLink(link),
            ),
          ],
        );
      },
    );
  }
}
