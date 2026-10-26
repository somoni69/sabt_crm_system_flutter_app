import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_env.dart';
import 'api_exception.dart';
import 'token_store.dart';

enum _RefreshOutcome { success, invalid, network }

class ApiClient {
  ApiClient({required this.tokens}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppEnv.apiBaseUrl,
        connectTimeout: const Duration(seconds: 16),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        responseType: ResponseType.json,
      ),
    );
    _refreshDio = Dio(
      BaseOptions(
        baseUrl: AppEnv.apiBaseUrl,
        connectTimeout: const Duration(seconds: 16),
        receiveTimeout: const Duration(seconds: 20),
        headers: const {'Accept': 'application/json', 'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (!_isPublicAuthPath(options.path)) {
            final token = tokens.accessToken;
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final path = error.requestOptions.path;
          final retried = error.requestOptions.extra['_retried'] == true;
          if (status == 401 && !_isPublicAuthPath(path) && !retried) {
            final outcome = await _refreshSingleFlight();
            if (outcome == _RefreshOutcome.success) {
              final options = error.requestOptions;
              options.extra['_retried'] = true;
              options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
              try {
                final response = await _dio.fetch<dynamic>(options);
                return handler.resolve(response);
              } on DioException catch (retryError) {
                return handler.next(retryError);
              }
            }
            if (outcome == _RefreshOutcome.invalid) {
              onSessionExpired?.call();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final TokenStore tokens;
  late final Dio _dio;
  late final Dio _refreshDio;

  VoidCallback? onSessionExpired;
  VoidCallback? onTokensRefreshed;

  Future<_RefreshOutcome>? _refreshing;

  Future<_RefreshOutcome> _refreshSingleFlight() {
    return _refreshing ??= _performRefresh().whenComplete(() => _refreshing = null);
  }

  Future<_RefreshOutcome> _performRefresh() async {
    final refresh = tokens.refreshToken;
    if (refresh == null || refresh.isEmpty) {
      await tokens.clear();
      return _RefreshOutcome.invalid;
    }
    try {
      final response = await _refreshDio.post<dynamic>(
        '/auth/refresh',
        data: {'refreshToken': refresh},
      );
      final data = response.data;
      if (data is! Map) return _RefreshOutcome.invalid;
      final access = data['accessToken'] as String?;
      final newRefresh = data['refreshToken'] as String?;
      if (access == null || access.isEmpty || newRefresh == null || newRefresh.isEmpty) {
        return _RefreshOutcome.invalid;
      }
      final user = data['user'];
      await tokens.setTokens(
        accessToken: access,
        refreshToken: newRefresh,
        user: user is Map<String, dynamic> ? user : null,
      );
      onTokensRefreshed?.call();
      return _RefreshOutcome.success;
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403 || status == 400) {
        await tokens.clear();
        return _RefreshOutcome.invalid;
      }
      return _RefreshOutcome.network;
    } catch (error) {
      debugPrint('ApiClient refresh failed: $error');
      return _RefreshOutcome.network;
    }
  }

  bool _isPublicAuthPath(String path) {
    return path.startsWith('/auth/login') ||
        path.startsWith('/auth/refresh') ||
        path.startsWith('/auth/register') ||
        path.startsWith('/auth/founder-exists') ||
        path.startsWith('/auth/forgot-password') ||
        path.startsWith('/auth/reset-password');
  }

  Future<dynamic> getJson(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: _cleanQuery(query),
        cancelToken: cancelToken,
      );
      return response.data;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<dynamic> postJson(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: body,
        queryParameters: _cleanQuery(query),
        cancelToken: cancelToken,
      );
      return response.data;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<dynamic> patchJson(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.patch<dynamic>(
        path,
        data: body,
        queryParameters: _cleanQuery(query),
        cancelToken: cancelToken,
      );
      return response.data;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<dynamic> putJson(
    String path, {
    Object? body,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.put<dynamic>(
        path,
        data: body,
        cancelToken: cancelToken,
      );
      return response.data;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<dynamic> deleteJson(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.delete<dynamic>(
        path,
        data: body,
        queryParameters: _cleanQuery(query),
        cancelToken: cancelToken,
      );
      return response.data;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Future<dynamic> uploadBytes(
    String path, {
    required String field,
    required List<int> bytes,
    required String filename,
    Map<String, String> fields = const {},
    String method = 'POST',
    CancelToken? cancelToken,
  }) async {
    try {
      final form = FormData.fromMap({
        ...fields,
        field: MultipartFile.fromBytes(bytes, filename: filename),
      });
      final response = method == 'PATCH'
          ? await _dio.patch<dynamic>(
              path,
              data: form,
              cancelToken: cancelToken,
              options: Options(contentType: 'multipart/form-data'),
            )
          : await _dio.post<dynamic>(
              path,
              data: form,
              cancelToken: cancelToken,
              options: Options(contentType: 'multipart/form-data'),
            );
      return response.data;
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  Map<String, dynamic>? _cleanQuery(Map<String, dynamic>? query) {
    if (query == null) return null;
    final cleaned = <String, dynamic>{};
    query.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.isEmpty) return;
      cleaned[key] = value;
    });
    return cleaned.isEmpty ? null : cleaned;
  }

  ApiException _mapError(DioException error) {
    final response = error.response;
    if (response == null) {
      if (error.type == DioExceptionType.cancel) {
        return const ApiException('Запрос отменён');
      }
      return const ApiException(
        'Нет соединения с сервером. Проверьте интернет — сохранённые данные останутся доступны.',
        isNetwork: true,
      );
    }

    final status = response.statusCode ?? 0;
    final data = response.data;
    String message = '';
    bool validation = false;

    if (data is Map) {
      final raw = data['message'] ?? data['error'];
      if (raw is List) {
        message = raw.map((item) => '$item').join('\n');
        validation = status == 400;
      } else if (raw is String) {
        message = raw;
      }
    } else if (data is String && data.trim().isNotEmpty) {
      message = data;
    }

    final lower = message.toLowerCase();
    if (lower.contains('2fa_required') || lower.contains('2fa required')) {
      return const TwoFactorRequiredException();
    }
    if (lower.startsWith('blocked:') || lower.contains('вас заблокировал')) {
      return AccountBlockedException(
        message.replaceFirst(RegExp(r'^BLOCKED:\s*', caseSensitive: false), ''),
      );
    }

    if (status == 401) {
      if (message.isEmpty) return const SessionExpiredException();
      if (lower.contains('invalid credentials')) {
        return const ApiException('Неверный логин или пароль', statusCode: 401);
      }
      return ApiException(_humanize(message), statusCode: 401);
    }
    if (status == 403) {
      return ApiException(
        message.isEmpty ? 'Недостаточно прав для этого действия' : _humanize(message),
        statusCode: 403,
      );
    }
    if (status == 429) {
      return ApiException(
        message.isEmpty
            ? 'Слишком много запросов. Подождите минуту и повторите.'
            : _humanize(message),
        statusCode: 429,
      );
    }
    if (status == 400) {
      return ApiException(
        message.isEmpty ? 'Проверьте заполнение полей' : _humanize(message),
        statusCode: 400,
        data: data,
        isValidation: validation,
      );
    }
    if (status == 404) {
      return ApiException(
        message.isEmpty ? 'Не найдено' : _humanize(message),
        statusCode: 404,
      );
    }
    if (status >= 500) {
      return ApiException(
        'Сервер временно недоступен. Попробуйте ещё раз через минуту.',
        statusCode: status,
      );
    }
    return ApiException(
      message.isEmpty ? 'Не удалось выполнить запрос' : _humanize(message),
      statusCode: status,
      data: data,
      isValidation: validation,
    );
  }

  String _humanize(String message) {
    const map = {
      'Account is deactivated': 'Аккаунт деактивирован администратором',
      'Invalid credentials': 'Неверный логин или пароль',
      'User not found': 'Пользователь не найден',
      'Not allowed': 'Недостаточно прав',
      'Forbidden resource': 'Недостаточно прав',
    };
    return map[message] ?? message;
  }
}
