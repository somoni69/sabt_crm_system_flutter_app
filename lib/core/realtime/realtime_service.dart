import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_env.dart';
import '../network/token_store.dart';

class RealtimeEvent {
  const RealtimeEvent(this.name, this.data);

  final String name;
  final dynamic data;

  Map<String, dynamic>? get map => data is Map<String, dynamic> ? data as Map<String, dynamic> : null;
}

class RealtimeService {
  RealtimeService(this.tokens);

  final TokenStore tokens;
  final StreamController<RealtimeEvent> _events = StreamController<RealtimeEvent>.broadcast();
  final StreamController<bool> _connection = StreamController<bool>.broadcast();

  io.Socket? _socket;
  bool _connected = false;
  bool _started = false;

  Stream<RealtimeEvent> get events => _events.stream;
  Stream<bool> get connectionChanges => _connection.stream;
  bool get isConnected => _connected;

  static const _watchedEvents = [
    'notification',
    'tasks:changed',
    'projects:changed',
    'stories:changed',
    'workflow:changed',
    'content:changed',
    'smm:changed',
  ];

  void connect() {
    if (_started) {
      ensureConnected();
      return;
    }
    _started = true;
    _socket = io.io(
      AppEnv.wsNamespaceUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuthFn((callback) {
        callback({'token': tokens.accessToken ?? ''});
      })
          .enableReconnection()
          .setReconnectionAttempts(60)
          .setReconnectionDelay(900)
          .setReconnectionDelayMax(10000)
          .setTimeout(16000)
          .build(),
    );

    _socket!
      ..onConnect((_) {
        _connected = true;
        _connection.add(true);
        debugPrint('Realtime connected');
      })
      ..onDisconnect((reason) {
        _connected = false;
        _connection.add(false);
        debugPrint('Realtime disconnected: $reason');
      })
      ..onConnectError((error) {
        _connected = false;
        _connection.add(false);
        debugPrint('Realtime connect error: $error');
      });

    for (final name in _watchedEvents) {
      _socket!.on(name, (data) {
        _events.add(RealtimeEvent(name, data));
      });
    }
  }

  void ensureConnected() {
    if (_socket == null) {
      connect();
      return;
    }
    if (!_socket!.connected) _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _started = false;
    _connected = false;
  }

  void dispose() {
    disconnect();
    _events.close();
    _connection.close();
  }
}
