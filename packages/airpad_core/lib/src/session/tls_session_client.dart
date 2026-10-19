import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../crypto/device_identity.dart';
import '../crypto/trust_store.dart';
import '../models/device.dart';
import '../models/event.dart';
import '../models/pairing.dart';

/// Connection and pairing states for the mobile session client.
sealed class SessionState {
  const SessionState();
}

class SessionConnecting extends SessionState {
  const SessionConnecting();
}

class SessionPairingPrompt extends SessionState {
  const SessionPairingPrompt({
    required this.code,
    required this.serverFingerprint,
  });

  final String code;
  final String serverFingerprint;
}

class SessionConnected extends SessionState {
  const SessionConnected({required this.serverDevice});
  final AirpadDevice serverDevice;
}

class SessionDisconnected extends SessionState {
  const SessionDisconnected({this.reason});
  final String? reason;
}

class SessionRejected extends SessionState {
  const SessionRejected({required this.reason});
  final String reason;
}

/// TLS WebSocket client hosted on the mobile phone controller.
class TlsSessionClient {
  TlsSessionClient({
    required this.localIdentity,
    required this.trustStore,
  });

  final DeviceIdentity localIdentity;
  final TrustStore trustStore;

  WebSocket? _socket;
  Timer? _heartbeatTimer;
  SessionState _currentState = const SessionDisconnected();

  final _stateController = StreamController<SessionState>.broadcast();

  Stream<SessionState> get onStateChanged => _stateController.stream;
  SessionState get state => _currentState;
  bool get isConnected => _currentState is SessionConnected;

  /// Connects to a desktop receiver via TLS WebSocket with certificate pinning.
  Future<void> connect({
    required String host,
    int port = AirpadProtocolDefaults.port,
    String? expectedFingerprint,
    String? qrCode,
  }) async {
    _setState(const SessionConnecting());

    final pinnedFp = expectedFingerprint?.toLowerCase();
    String? actualServerFp;

    final httpClient = HttpClient();

    // Security Req #3: Certificate Pinning
    httpClient.badCertificateCallback = (X509Certificate cert, String certHost, int certPort) {
      actualServerFp = DeviceIdentity.computeFingerprintFromDer(cert.der);

      if (pinnedFp != null) {
        // Enforce strict pinning against expected fingerprint
        return actualServerFp == pinnedFp;
      }

      // If already trusted, allow
      if (trustStore.isTrusted(actualServerFp!)) {
        return true;
      }

      // For first-time pairing, allow handshake to verify 6-digit code
      return true;
    };

    try {
      final uri = Uri.parse('wss://$host:$port/v1/session');
      final ws = await WebSocket.connect(
        uri.toString(),
        customClient: httpClient,
      ).timeout(const Duration(seconds: 10));

      _socket = ws;

      // Start heartbeat ping every 2s
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        sendPing();
      });

      // Send initial handshake
      if (qrCode != null) {
        final msg = PairQrMessage(
          code: qrCode,
          alias: localIdentity.alias,
          fingerprint: localIdentity.fingerprint,
        );
        ws.add(msg.toJsonString());
      } else {
        final msg = PairConfirmMessage(
          alias: localIdentity.alias,
          fingerprint: localIdentity.fingerprint,
        );
        ws.add(msg.toJsonString());
      }

      ws.listen(
        (data) => _handleIncomingMessage(data.toString(), actualServerFp, host, port),
        onDone: () => _handleDisconnection(),
        onError: (e) => _handleDisconnection(reason: e.toString()),
      );
    } catch (e) {
      String reason = e.toString();
      if (e is TimeoutException) {
        reason = 'Connection timed out to $host:$port. Ensure AIRPAD is running and port $port is allowed by your firewall (e.g. "sudo ufw allow $port").';
      }
      _handleDisconnection(reason: reason);
      throw Exception(reason);
    }
  }

  void _handleIncomingMessage(String raw, String? serverFp, String host, int port) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed == '{"type":"pong"}') return;

    try {
      final json = jsonDecode(trimmed) as Map<String, dynamic>;
      final type = json['type'] as String?;

      if (type == 'pair_prompt') {
        final prompt = PairPromptMessage.fromJson(json);
        _setState(SessionPairingPrompt(
          code: prompt.code,
          serverFingerprint: prompt.fingerprint,
        ));
        return;
      }

      if (type == 'pair_ok') {
        final fp = serverFp ?? '';
        final serverDevice = AirpadDevice(
          alias: 'Desktop Receiver',
          fingerprint: fp,
          deviceType: DeviceType.desktop,
          ip: host,
          port: port,
        );
        if (fp.isNotEmpty) {
          await trustStore.trustDevice(serverDevice);
        }
        _setState(SessionConnected(serverDevice: serverDevice));
        return;
      }

      if (type == 'pair_reject') {
        final reject = PairRejectMessage.fromJson(json);
        _setState(SessionRejected(reason: reject.reason));
        await disconnect();
        return;
      }
    } catch (_) {}
  }

  /// Sends an Airpad event over the active TLS WebSocket session.
  void sendEvent(AirpadEvent event) {
    if (_socket != null && isConnected) {
      _socket!.add(event.toJsonString());
    }
  }

  /// Sends a heartbeat ping.
  void sendPing() {
    if (_socket != null) {
      _socket!.add('{"type":"ping"}');
    }
  }

  void _setState(SessionState newState) {
    _currentState = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  void _handleDisconnection({String? reason}) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _socket = null;
    if (_currentState is! SessionRejected) {
      _setState(SessionDisconnected(reason: reason));
    }
  }

  /// Closes the active session cleanly.
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    final ws = _socket;
    _socket = null;
    await ws?.close(WebSocketStatus.normalClosure);
    _setState(const SessionDisconnected());
  }

  void dispose() {
    disconnect();
    _stateController.close();
  }
}
