import '../config/app_env.dart';

abstract final class ApiUrls {
  static String avatar(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final value = raw.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    if (value.startsWith('data:')) return value;
    if (value.startsWith('db:')) {
      return '${AppEnv.apiOrigin}/api/avatars/${value.substring(3)}';
    }
    if (value.startsWith('/api/') || value.startsWith('/uploads/')) {
      return '${AppEnv.apiOrigin}$value';
    }
    return '${AppEnv.apiOrigin}/uploads/avatars/$value';
  }

  static String file(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    final value = path.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    if (value.startsWith('/api/') || value.startsWith('/uploads/')) {
      return '${AppEnv.apiOrigin}$value';
    }
    return '${AppEnv.apiOrigin}/uploads/$value';
  }
}
