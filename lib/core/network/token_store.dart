import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce/hive.dart';
import '../utils/json_utils.dart';

/// Tokens live in the platform keychain on mobile. On web (and on any platform
/// where the secure plugin is unavailable) they fall back to the app's Hive
/// preferences box, which is still sandboxed per origin/user profile.
class TokenStore {
  TokenStore(this._prefs);

  static const _accessKey = 'sabt.accessToken';
  static const _refreshKey = 'sabt.refreshToken';
  static const _userKey = 'sabt.userSnapshot';

  final Box<dynamic> _prefs;
  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  bool _secureAvailable = true;

  String? _access;
  String? _refresh;
  String? _cachedUserJson;

  String? get accessToken => _access;
  String? get refreshToken => _refresh;
  String? get cachedUserJson => _cachedUserJson;
  bool get hasSession => (_refresh?.isNotEmpty ?? false) || (_access?.isNotEmpty ?? false);
  bool get secureAvailable => _secureAvailable;

  Future<void> load() async {
    try {
      _access = await _secure.read(key: _accessKey);
      _refresh = await _secure.read(key: _refreshKey);
      _cachedUserJson = _prefs.get(_userKey) as String?;
    } catch (error, stack) {
      _secureAvailable = false;
      debugPrint('TokenStore: secure storage unavailable, using local box: $error');
      debugPrintStack(stackTrace: stack);
      _access = _prefs.get(_accessKey) as String?;
      _refresh = _prefs.get(_refreshKey) as String?;
      _cachedUserJson = _prefs.get(_userKey) as String?;
    }
  }

  Future<void> setTokens({
    required String accessToken,
    required String refreshToken,
    Map<String, dynamic>? user,
  }) async {
    _access = accessToken;
    _refresh = refreshToken;
    if (user != null) {
      _cachedUserJson = jsonEncode(user);
      await _prefs.put(_userKey, _cachedUserJson);
    }

    if (_secureAvailable) {
      try {
        await _secure.write(key: _accessKey, value: accessToken);
        await _secure.write(key: _refreshKey, value: refreshToken);
        return;
      } catch (error) {
        _secureAvailable = false;
        debugPrint('TokenStore: secure write failed, falling back: $error');
      }
    }
    await _prefs.put(_accessKey, accessToken);
    await _prefs.put(_refreshKey, refreshToken);
  }

  Future<void> updateAccessToken(String accessToken) async {
    _access = accessToken;
    if (_secureAvailable) {
      try {
        await _secure.write(key: _accessKey, value: accessToken);
        return;
      } catch (_) {
        _secureAvailable = false;
      }
    }
    await _prefs.put(_accessKey, accessToken);
  }

  Future<void> saveUserSnapshot(Map<String, dynamic> user) async {
    _cachedUserJson = jsonEncode(user);
    await _prefs.put(_userKey, _cachedUserJson);
  }

  Map<String, dynamic>? get cachedUser {
    final raw = _cachedUserJson;
    if (raw == null || raw.isEmpty) return null;
    try {
      return asMap(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    if (_secureAvailable) {
      try {
        await _secure.delete(key: _accessKey);
        await _secure.delete(key: _refreshKey);
      } catch (_) {
        _secureAvailable = false;
      }
    }
    await _prefs.delete(_accessKey);
    await _prefs.delete(_refreshKey);
  }

  Future<void> clearAll() async {
    await clear();
    await _prefs.delete(_userKey);
    _cachedUserJson = null;
  }
}
