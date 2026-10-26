import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

class CacheEntry {
  const CacheEntry({required this.data, required this.savedAt});

  final dynamic data;
  final DateTime savedAt;
}

/// Offline read cache. Values are stored as JSON strings so Hive never has to
/// reinterpret nested maps after a schema change and the cache can be cleared
/// by user without touching tokens.
class ResponseCache {
  ResponseCache(this._box);

  final Box<dynamic> _box;
  static const int _maxEntries = 280;

  int get entries => _box.length;

  static String staticKey(String userId, String logicalKey, [Map<String, dynamic>? query]) {
    final buffer = StringBuffer('u:$userId|$logicalKey');
    if (query != null && query.isNotEmpty) {
      final keys = query.keys.toList()..sort();
      for (final key in keys) {
        final value = query[key];
        if (value == null || '$value'.isEmpty) continue;
        buffer.write('|$key=$value');
      }
    }
    return buffer.toString();
  }

  CacheEntry? read(String key) {
    final raw = _box.get(key);
    if (raw is! Map) return null;
    final json = raw['json'];
    final ts = raw['ts'];
    if (json is! String || ts is! int) return null;
    try {
      return CacheEntry(
        data: jsonDecode(json),
        savedAt: DateTime.fromMillisecondsSinceEpoch(ts),
      );
    } catch (error) {
      debugPrint('ResponseCache: corrupted entry $key — $error');
      _box.delete(key);
      return null;
    }
  }

  Future<void> write(String key, dynamic data) async {
    try {
      await _box.put(key, {
        'json': jsonEncode(data),
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
      await _prune();
    } catch (error) {
      debugPrint('ResponseCache: write failed for $key — $error');
    }
  }

  Future<void> remove(String key) => _box.delete(key);

  Future<void> clearUser(String userId) async {
    final prefix = 'u:$userId|';
    final keys = _box.keys.where((key) => key.toString().startsWith(prefix)).toList();
    if (keys.isNotEmpty) await _box.deleteAll(keys);
  }

  Future<void> clearAll() => _box.clear();

  Future<void> _prune() async {
    if (_box.length <= _maxEntries) return;
    final entries = <({dynamic key, int ts})>[];
    for (final key in _box.keys) {
      final value = _box.get(key);
      if (value is Map && value['ts'] is int) {
        entries.add((key: key, ts: value['ts'] as int));
      }
    }
    entries.sort((a, b) => a.ts.compareTo(b.ts));
    final removeCount = (_box.length - _maxEntries + 40).clamp(0, entries.length);
    if (removeCount > 0) {
      await _box.deleteAll(entries.take(removeCount).map((e) => e.key));
    }
  }
}
