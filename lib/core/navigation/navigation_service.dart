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

    if (path.startsWith('/analytics')) {
      _push('/analytics');
      return;
    }
    if (path.startsWith('/finance/transport')) {
      _push('/finance/transport');
      return;
    }
    if (path.startsWith('/finance/income/') || path == '/finance/income') {
      _push(path.split('?').first);
      return;
    }
    if (path.startsWith('/finance/expense') ||
        path.startsWith('/finance/salary') ||
        path.startsWith('/finance/subscriptions') ||
        path.startsWith('/finance/debts') ||
        path.startsWith('/finance/transactions') ||
        path.startsWith('/finance/planning') ||
        path.startsWith('/finance/inventory') ||
        path.startsWith('/finance/activity') ||
        path.startsWith('/finance/settings')) {
      _push(path.split('?').first);
      return;
    }
    if (path.startsWith('/finance')) {
      _push('/finance');
      return;
    }
    if (path.startsWith('/dev/projects')) {
      _push(path.split('?').first);
      return;
    }
    if (path.startsWith('/dev-board/task/') ||
        path.startsWith('/dev-board/kpi') ||
        path.startsWith('/dev-board/reports')) {
      _push(path.split('?').first);
      return;
    }
    if (path.startsWith('/dev/kpi')) {
      _push('/dev-board/kpi');
      return;
    }
    if (path.startsWith('/dev/reports')) {
      _push('/dev-board/reports');
      return;
    }
    if (path.startsWith('/dev-board') || path.startsWith('/dev')) {
      _push('/dev-board');
      return;
    }
    if (path.startsWith('/files')) {
      _push('/files');
      return;
    }
    if (path.startsWith('/tariffs')) {
      _push('/tariffs');
      return;
    }
    if (path.startsWith('/archive')) {
      _push('/archive');
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
    if (path.startsWith('/employees/sales-plan')) {
      _push('/employees/sales-plan');
      return;
    }
    if (path.startsWith('/employees')) {
      _push(path.split('?').first);
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
      _push(path.split('?').first);
      return;
    }
    if (path.startsWith('/my-notes')) {
      _push('/my-notes');
      return;
    }
    if (path.startsWith('/ai')) {
      _push('/ai');
      return;
    }
    if (path.startsWith('/risks')) {
      _push('/risks');
      return;
    }
    if (path.startsWith('/security-log')) {
      _push('/security-log');
      return;
    }
    if (path.startsWith('/transport') || path.startsWith('/finance/transport')) {
      _push('/transport');
      return;
    }
    if (path.startsWith('/onboarding')) {
      _push('/onboarding');
      return;
    }
    if (path.startsWith('/employee-access')) {
      _push('/employee-access');
      return;
    }
    if (path.startsWith('/smm/control')) {
      _push('/smm/control');
      return;
    }
    if (path.startsWith('/team-activity')) {
      _push('/employees/activity');
      return;
    }

    if (_isWebOnly(path)) {
      _push('/web-only?path=${Uri.encodeComponent(path)}');
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
    return false;
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
