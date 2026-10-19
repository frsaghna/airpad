import 'dart:io';

import '../models/event.dart';

/// Client that communicates with the `airpad-inject` daemon over its Unix domain socket.
class AirpadInjectClient {
  AirpadInjectClient({String? customSocketPath})
      : socketPath = customSocketPath ?? _defaultSocketPath();

  final String socketPath;
  Socket? _socket;
  bool _isConnecting = false;

  bool get isConnected => _socket != null;

  static String _defaultSocketPath() {
    final runtimeDir = Platform.environment['XDG_RUNTIME_DIR'] ?? '/tmp';
    return '$runtimeDir/airpad/inject.sock';
  }

  /// Connects to the helper Unix domain socket.
  Future<bool> connect() async {
    if (_socket != null) return true;
    if (_isConnecting) return false;

    _isConnecting = true;
    try {
      final file = File(socketPath);
      if (!await file.exists()) {
        _isConnecting = false;
        return false;
      }

      final address = InternetAddress(socketPath, type: InternetAddressType.unix);
      _socket = await Socket.connect(address, 0);

      _socket!.listen(
        null,
        onDone: () {
          _socket = null;
        },
        onError: (_) {
          _socket = null;
        },
      );
      _isConnecting = false;
      return true;
    } catch (_) {
      _socket = null;
      _isConnecting = false;
      return false;
    }
  }

  /// Sends an Airpad event formatted as newline-delimited JSON.
  Future<void> sendEvent(AirpadEvent event) async {
    if (_socket == null) {
      final ok = await connect();
      if (!ok) return;
    }

    try {
      final payload = '${event.toJsonString()}\n';
      _socket!.write(payload);
      await _socket!.flush();
    } catch (_) {
      _socket = null;
    }
  }

  /// Disconnects from the helper socket. The helper will automatically release all held keys.
  Future<void> disconnect() async {
    final sock = _socket;
    _socket = null;
    try {
      await sock?.flush();
      await sock?.close();
    } catch (_) {}
  }

  void dispose() {
    disconnect();
  }
}
