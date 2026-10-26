import 'package:flutter/foundation.dart';

import '../connectivity/connectivity_service.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import 'response_cache.dart';

class CachedPayload {
  const CachedPayload({
    required this.data,
    required this.savedAt,
    required this.fromCache,
    this.error,
  });

  final dynamic data;
  final DateTime savedAt;
  final bool fromCache;
  final String? error;

  CachedPayload withError(String message) => CachedPayload(
        data: data,
        savedAt: savedAt,
        fromCache: true,
        error: message,
      );
}

/// Cache-first stream: an instant snapshot from disk, then a fresh network
/// response. If the network fails, the cached snapshot stays on screen and is
/// annotated with the error instead of blanking the page.
class CachedJson {
  CachedJson({
    required this.api,
    required this.cache,
    required this.connectivity,
  });

  final ApiClient api;
  final ResponseCache cache;
  final ConnectivityService connectivity;

  Stream<CachedPayload> watch({
    required String userId,
    required String key,
    required String path,
    Map<String, dynamic>? query,
    bool bypassCacheWhenOnline = false,
  }) async* {
    final cacheKey = ResponseCache.staticKey(userId, key, query);
    final cached = cache.read(cacheKey);

    if (cached != null) {
      yield CachedPayload(
        data: cached.data,
        savedAt: cached.savedAt,
        fromCache: true,
      );
    }

    if (connectivity.isOffline && cached != null) {
      yield CachedPayload(
        data: cached.data,
        savedAt: cached.savedAt,
        fromCache: true,
        error: 'Нет сети — показаны сохранённые данные',
      );
      return;
    }

    try {
      final data = await api.getJson(path, query: query);
      await cache.write(cacheKey, data);
      yield CachedPayload(
        data: data,
        savedAt: DateTime.now(),
        fromCache: false,
      );
    } on ApiException catch (error) {
      if (cached != null) {
        yield CachedPayload(
          data: cached.data,
          savedAt: cached.savedAt,
          fromCache: true,
          error: error.message,
        );
        return;
      }
      rethrow;
    } catch (error, stack) {
      debugPrint('CachedJson network failure for $path: $error\n$stack');
      if (cached != null) {
        yield CachedPayload(
          data: cached.data,
          savedAt: cached.savedAt,
          fromCache: true,
          error: 'Не удалось обновить данные',
        );
        return;
      }
      throw ApiException('Не удалось загрузить данные. Проверьте соединение.');
    }
  }

  Future<dynamic> fetch({
    required String userId,
    required String key,
    required String path,
    Map<String, dynamic>? query,
    bool allowCache = true,
  }) async {
    final cacheKey = ResponseCache.staticKey(userId, key, query);
    try {
      final data = await api.getJson(path, query: query);
      await cache.write(cacheKey, data);
      return data;
    } on ApiException {
      if (!allowCache) rethrow;
      final cached = cache.read(cacheKey);
      if (cached == null) rethrow;
      return cached.data;
    }
  }
}
