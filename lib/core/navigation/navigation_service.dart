import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../widgets/app_banner.dart';

/// Translates web notification links (`/tasks/:id`, `/smm/projects/:id`, …)
/// into mobile routes and tab switches, so a push lands on a real screen.
class NavigationService {
  NavigationService({required this.banners});

  final BannerService banners;

  GoRouter? _router;

  /// `dashboard` | `tasks` | `work` | `more`
  final ValueNotifier<String?> requestedSection = ValueNotifier<String?>(null);

  final ValueNotifier<String?> _pendingRoute = ValueNotifier<String?>(null);

  void attachRouter(GoRouter router) {
    _router = router;
    final pending = _pendingRoute.value;
    if (pending != null) {
      _pendingRoute.value = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_router?.canPop() ?? false) {
          _router!.push(pending);
        } else {
          _router!.go(pending);
        }
      });
    }
  }

  void handleLink(String? raw) {
    if (raw == null || raw.trim().isEmpty) return;
    String path = raw.trim();
    if (path.startsWith('http://') || path.startsWith('https://')) {
      final uri = Uri.tryParse(path);
      if (uri == null) return;
      path = uri.path + (uri.hasQuery ? '?${uri.query}' : '');
    }
    if (!path.startsWith('/')) path = '/$path';

    final smmProject = RegExp(r'^/smm/projects/([^/?]+)').firstMatch(path);
    if (smmProject != null) {
      _push('/projects/${smmProject.group(1)}');
      return;
    }

    if (_isWebOnly(path)) {
      banners.show(AppBanner(
        title: 'Откройте в веб-версии',
        message: 'Этот раздел пока доступен только в Sabt для браузера.',
        tone: BannerTone.info,
        icon: null,
        link: '/web-only?path=${Uri.encodeComponent(path)}',
      ));
      _push('/web-only?path=${Uri.encodeComponent(path)}');
      return;
    }

    if (_isDetailRoute(path)) {
      _push(path);
      return;
    }

    final section = _sectionFor(path);
    if (section != null) {
      requestedSection.value = section;
      if (_router != null) {
        _router!.go('/');
      }
      return;
    }

    if (path.startsWith('/calendar')) {
      _push('/calendar');
      return;
    }
    if (path.startsWith('/clients')) {
      _push(path);
      return;
    }
    if (path.startsWith('/projects')) {
      _push(path);
      return;
    }
    if (path.startsWith('/employees')) {
      _push(path);
      return;
    }
    if (path.startsWith('/notifications')) {
      _push('/notifications');
      return;
    }
    if (path.startsWith('/profile')) {
      _push('/profile');
      return;
    }
    if (path.startsWith('/settings')) {
      _push('/settings');
      return;
    }
    if (path.startsWith('/stories-check')) {
      _push('/stories-check');
      return;
    }

    banners.show(const AppBanner(
      title: 'Переход недоступен',
      message: 'Ссылка ведёт в раздел, которого нет в мобильном приложении.',
      tone: BannerTone.info,
    ));
  }

  bool _isDetailRoute(String path) {
    if (RegExp(r'^/tasks/[^/]+').hasMatch(path)) return true;
    if (RegExp(r'^/projects/[^/]+').hasMatch(path)) return true;
    if (RegExp(r'^/smm/projects/[^/]+').hasMatch(path)) {
      return true;
    }
    if (RegExp(r'^/employees/[^/]+').hasMatch(path)) return true;
    if (RegExp(r'^/clients/[^/]+').hasMatch(path)) return true;
    return false;
  }

  bool _isWebOnly(String path) {
    const prefixes = [
      '/finance',
      '/dev-board',
      '/dev/',
      '/analytics',
      '/risks',
      '/archive',
      '/files',
      '/tariffs',
      '/security-log',
      '/employee-access',
      '/onboarding',
      '/team-activity',
    ];
    return prefixes.any(path.startsWith);
  }

  String? _sectionFor(String path) {
    final clean = path.split('?').first;
    if (clean == '/' || clean.startsWith('/?')) return 'dashboard';
    if (clean == '/tasks') return 'tasks';
    if (clean == '/smm' || clean.startsWith('/smm/')) return 'work';
    if (clean == '/notifications') return 'more';
    return null;
  }

  void _push(String path) {
    final router = _router;
    if (router == null) {
      _pendingRoute.value = path;
      return;
    }
    router.push(path);
  }
}
