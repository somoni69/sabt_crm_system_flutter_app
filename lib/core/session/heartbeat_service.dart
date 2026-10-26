import 'dart:async';

import 'package:flutter/foundation.dart';

import '../network/api_client.dart';
import '../network/api_exception.dart';

/// The web sends `/auth/heartbeat` every few minutes; work sessions and the
/// "inactive" risk alerts depend on it. Mobile keeps the same rhythm.
class HeartbeatService {
  HeartbeatService(this.api);

  final ApiClient api;
  Timer? _timer;

  void start() {
    stop();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => beat());
  }

  Future<void> beat() async {
    try {
      await api.postJson('/auth/heartbeat');
    } on ApiException catch (error) {
      if (!error.isNetwork) debugPrint('heartbeat failed: ${error.message}');
    } catch (error) {
      debugPrint('heartbeat failed: $error');
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
