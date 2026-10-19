import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../crypto/device_identity.dart';
import '../crypto/trust_store.dart';
import '../models/device.dart';
import '../models/event.dart';
import '../models/pairing.dart';
import 'pairing_manager.dart';

/// Request presented to the desktop user when an unknown phone attempts to pair.
class PairingPromptRequest {
  PairingPromptRequest({
    required this.device,
    required this.code,
  }) : _completer = Completer<bool>();

  final AirpadDevice device;
  final String code;
  final Completer<bool> _completer;

  Future<bool> get decision => _completer.future;

  void accept() {
    if (!_completer.isCompleted) _completer.complete(true);
  }

  void reject() {
    if (!_completer.isCompleted) _completer.complete(false);
  }
}

/// Token bucket rate limiter preventing flood DOS attacks (Security Req #7).
class RateLimiter {
  RateLimiter({
    this.maxPerSecond = 240,
    this.burstCapacity = 60,
  })  : _tokens = burstCapacity.toDouble(),
        _lastCheck = DateTime.now();

  final int maxPerSecond;
  final int burstCapacity;
  double _tokens;
  DateTime _lastCheck;

  bool tryAcquire() {
    final now = DateTime.now();
    final elapsedMs = now.difference(_lastCheck).inMilliseconds;
    _lastCheck = now;

    _tokens = (_tokens + elapsedMs * (maxPerSecond / 1000.0))
        .clamp(0.0, burstCapacity.toDouble());
    if (_tokens >= 1.0) {
      _tokens -= 1.0;
      return true;
    }
    return false;
  }
}

/// TLS WebSocket server hosted by the Linux desktop receiver.
class TlsSessionServer {
  TlsSessionServer({
    required this.localIdentity,
    required this.trustStore,
    this.port = AirpadProtocolDefaults.port,
    this.askEveryTime = false,
  });

  final DeviceIdentity localIdentity;
  final TrustStore trustStore;
  final int port;
  bool askEveryTime;

  HttpServer? _server;
  WebSocket? _activeSocket;
  AirpadDevice? _activeController;
  Timer? _heartbeatTimer;
  DateTime? _lastPingTime;

  final Map<String, DateTime> _activeQrCodes = {};

  final _activeControllerController = StreamController<AirpadDevice?>.broadcast();
  final _pairingPromptController = StreamController<PairingPromptRequest>.broadcast();
  final _eventController = StreamController<AirpadEvent>.broadcast();
  final _disconnectController = StreamController<void>.broadcast();

  Stream<AirpadDevice?> get activeControllerStream => _activeControllerController.stream;
  Stream<PairingPromptRequest> get onPairingPrompt => _pairingPromptController.stream;
  Stream<AirpadEvent> get onEventReceived => _eventController.stream;
  Stream<void> get onClientDisconnected => _disconnectController.stream;

  AirpadDevice? get activeController => _activeController;
  bool get isRunning => _server != null;

  /// Starts the TLS WebSocket server on [port].
  Future<void> start() async {
    if (_server != null) return;

    final secContext = localIdentity.createSecurityContext();

    _server = await HttpServer.bindSecure(
      InternetAddress.anyIPv4,
      port,
      secContext,
      shared: true,
    );

    _server!.listen(_handleHttpRequest);
  }

  /// Generates a one-time QR code valid for 5 minutes.
  String createQrPairingCode() {
    final code = PairingCodeHelper.generateCode();
    _activeQrCodes[code] = DateTime.now().add(const Duration(minutes: 5));
    return code;
  }

  void _handleHttpRequest(HttpRequest request) async {
    final path = request.uri.path;

    if (path == '/v1/session') {
      if (!WebSocketTransformer.isUpgradeRequest(request)) {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
        return;
      }

      // Single active session rule (Section 5.5)
      if (_activeSocket != null) {
        request.response.statusCode = HttpStatus.serviceUnavailable;
        request.response.write('Another controller session is already active');
        await request.response.close();
        return;
      }

      final socket = await WebSocketTransformer.upgrade(request);
      _handleWebSocketConnection(socket, request.connectionInfo?.remoteAddress.address);
    } else {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    }
  }

  void _handleWebSocketConnection(WebSocket socket, String? remoteIp) {
    var isAuthenticated = false;
    AirpadDevice? remoteDevice;
    final rateLimiter = RateLimiter(maxPerSecond: 240, burstCapacity: 60);

    _lastPingTime = DateTime.now();

    // Setup heartbeat monitor
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final now = DateTime.now();
      if (_lastPingTime != null && now.difference(_lastPingTime!) > const Duration(seconds: 6)) {
        _closeActiveSession(socket, code: 4408, reason: 'Heartbeat timeout');
      }
    });

    socket.listen(
      (message) async {
        _lastPingTime = DateTime.now();
        final rawStr = message.toString().trim();
        if (rawStr.isEmpty) return;

        // Security Req #7: Validate and bound payload size (max 8KB)
        if (rawStr.length > 8192) return;

        // Security Req #7: Rate limit high-frequency motion events (max 240/sec).
        // Never drop discrete state events (keys, buttons, clicks) to prevent stuck keys.
        final isHighFrequency = rawStr.contains('"type":"move"') || rawStr.contains('"type":"scroll"');
        if (isHighFrequency && !rateLimiter.tryAcquire()) return;

        // 1. Handle heartbeat ping
        if (rawStr == 'ping' || rawStr == '{"type":"ping"}') {
          socket.add('{"type":"pong"}');
          return;
        }

        try {
          final json = jsonDecode(rawStr) as Map<String, dynamic>;
          final type = json['type'] as String?;

          // 2. Initial handshake / pairing negotiation
          if (!isAuthenticated) {
            if (type == 'pair_qr') {
              final qrMsg = PairQrMessage.fromJson(json);
              final expiry = _activeQrCodes[qrMsg.code];
              if (expiry != null && DateTime.now().isBefore(expiry)) {
                _activeQrCodes.remove(qrMsg.code);
                remoteDevice = AirpadDevice(
                  alias: qrMsg.alias,
                  fingerprint: qrMsg.fingerprint,
                  deviceType: DeviceType.mobile,
                  ip: remoteIp,
                );
                await trustStore.trustDevice(remoteDevice!);
                isAuthenticated = true;
                _setActiveController(socket, remoteDevice!);
                socket.add(const PairOkMessage().toJsonString());
              } else {
                socket.add(const PairRejectMessage(reason: 'Invalid or expired QR code').toJsonString());
                await socket.close(4403, 'Invalid QR code');
              }
              return;
            }

            if (type == 'pair_confirm' || type == 'hello') {
              final alias = json['alias'] as String? ?? 'Mobile Controller';
              final fingerprint = (json['fingerprint'] as String? ?? '').toLowerCase();

              remoteDevice = AirpadDevice(
                alias: alias,
                fingerprint: fingerprint,
                deviceType: DeviceType.mobile,
                ip: remoteIp,
              );

              if (trustStore.isTrusted(fingerprint) && !askEveryTime) {
                // Auto-connect trusted device (Section 5.4)
                isAuthenticated = true;
                _setActiveController(socket, remoteDevice!);
                socket.add(const PairOkMessage().toJsonString());
                return;
              }

              // Unknown device -> initiate 6-digit pairing prompt
              final code = PairingCodeHelper.generateCode();
              final promptReq = PairingPromptRequest(device: remoteDevice!, code: code);

              _pairingPromptController.add(promptReq);
              socket.add(PairPromptMessage(
                code: code,
                fingerprint: localIdentity.fingerprint,
              ).toJsonString());

              // Await user decision on desktop
              final approved = await promptReq.decision.timeout(
                const Duration(seconds: 60),
                onTimeout: () => false,
              );

              if (approved) {
                await trustStore.trustDevice(remoteDevice!);
                isAuthenticated = true;
                _setActiveController(socket, remoteDevice!);
                socket.add(const PairOkMessage().toJsonString());
              } else {
                socket.add(const PairRejectMessage(reason: 'Pairing rejected by desktop').toJsonString());
                await socket.close(4403, 'Pairing rejected');
              }
              return;
            }

            // Reject any input messages before authentication (Security Req #1)
            socket.add(const PairRejectMessage(reason: 'Authentication required').toJsonString());
            await socket.close(4401, 'Unauthenticated');
            return;
          }

          // 3. Authenticated session event handling
          final event = AirpadEvent.fromJson(json);
          _eventController.add(event);
        } catch (e) {
          // Ignore corrupted single messages
        }
      },
      onDone: () {
        _handleDisconnect(socket);
      },
      onError: (_) {
        _handleDisconnect(socket);
      },
    );
  }

  void _setActiveController(WebSocket socket, AirpadDevice device) {
    _activeSocket = socket;
    _activeController = device;
    _activeControllerController.add(device);
  }

  void _handleDisconnect(WebSocket socket) {
    if (_activeSocket == socket) {
      _activeSocket = null;
      _activeController = null;
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      _activeControllerController.add(null);
      _disconnectController.add(null);
    }
  }

  void _closeActiveSession(WebSocket socket, {required int code, required String reason}) {
    socket.close(code, reason);
    _handleDisconnect(socket);
  }

  /// Revokes trust for a device and instantly closes its session if active (Security Req #5).
  Future<void> revokeDevice(String fingerprint) async {
    final cleanFp = fingerprint.toLowerCase();
    await trustStore.revokeDevice(cleanFp);

    if (_activeController?.fingerprint.toLowerCase() == cleanFp) {
      final sock = _activeSocket;
      if (sock != null) {
        _closeActiveSession(sock, code: 4401, reason: 'Device revoked');
      }
    }
  }

  /// Disconnects any currently active controller session.
  Future<void> disconnectAll() async {
    final sock = _activeSocket;
    if (sock != null) {
      _closeActiveSession(sock, code: 1000, reason: 'Disconnected by desktop');
    }
  }

  /// Stops the TLS server and releases all connections.
  Future<void> stop() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await disconnectAll();
    await _server?.close(force: true);
    _server = null;
  }

  void dispose() {
    stop();
    _activeControllerController.close();
    _pairingPromptController.close();
    _eventController.close();
    _disconnectController.close();
  }
}
