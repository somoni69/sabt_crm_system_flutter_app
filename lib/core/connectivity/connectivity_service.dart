import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  ConnectivityService() {
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final online = _isOnline(results);
      if (online != _online) {
        _online = online;
        _controller.add(online);
      }
    });
    refresh();
  }

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _online = true;

  bool get isOnline => _online;
  bool get isOffline => !_online;
  Stream<bool> get changes => _controller.stream;

  Future<bool> refresh() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final online = _isOnline(results);
      if (online != _online) {
        _online = online;
        _controller.add(online);
      }
      return online;
    } catch (error) {
      debugPrint('Connectivity check failed: $error');
      return _online;
    }
  }

  bool _isOnline(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return !results.every((result) => result == ConnectivityResult.none);
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
