import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/device.dart';

/// Handles UDP multicast and broadcast announcement and discovery on the local network.
class MulticastDiscoveryService {
  MulticastDiscoveryService({
    required this.localDevice,
    this.multicastGroup = AirpadProtocolDefaults.multicastGroup,
    this.port = AirpadProtocolDefaults.port,
    int? listenPort,
  }) : listenPort = listenPort ?? port;

  final AirpadDevice localDevice;
  final String multicastGroup;
  final int port;
  final int listenPort;

  RawDatagramSocket? _socket;
  Timer? _advertiseTimer;
  final _discoveredController = StreamController<AirpadDevice>.broadcast();

  /// Stream of nearby devices discovered via multicast packets.
  Stream<AirpadDevice> get discoveredDevices => _discoveredController.stream;

  bool get isRunning => _socket != null;

  /// Starts listening for incoming multicast announce packets.
  Future<void> startListening() async {
    if (_socket != null) return;

    final mAddress = InternetAddress(multicastGroup);

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        listenPort,
        reuseAddress: true,
        reusePort: true,
      );
      _socket!.broadcastEnabled = true;
      _socket!.multicastLoopback = true;
      _socket!.multicastHops = 2;

      // Join default multicast group
      try {
        _socket!.joinMulticast(mAddress);
      } catch (_) {}

      // Also join multicast on every available network interface (including loopback)
      try {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLoopback: true,
        );
        for (final iface in interfaces) {
          try {
            _socket!.joinMulticast(mAddress, iface);
          } catch (_) {}
        }
      } catch (_) {}
    } catch (e) {
      // In case reusePort or multicast join fails on specific environments,
      // fallback to standard bind
      _socket ??= await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
    }

    _socket!.listen((event) {
      if (event == RawSocketEvent.read) {
        _handleIncomingDatagram();
      }
    });
  }

  void _handleIncomingDatagram() {
    final socket = _socket;
    if (socket == null) return;

    final datagram = socket.receive();
    if (datagram == null) return;

    try {
      final rawStr = utf8.decode(datagram.data);
      final json = jsonDecode(rawStr) as Map<String, dynamic>;
      final remoteDevice = AirpadDevice.fromJson(json).copyWith(
        ip: datagram.address.address,
      );

      // Filter out self-discovery (Section 5.3 & Phase 2 criteria)
      if (remoteDevice.fingerprint == localDevice.fingerprint) {
        return;
      }

      if (!remoteDevice.isValid()) {
        return;
      }

      // If remote device is requesting announce (e.g. phone looking for desktop),
      // reply with announce: false so the phone discovers us immediately
      if (remoteDevice.announce && localDevice.deviceType == DeviceType.desktop) {
        _sendReply(datagram.address, datagram.port);
      }

      _discoveredController.add(remoteDevice);
    } catch (_) {
      // Malformed datagram ignored
    }
  }

  void _sendReply(InternetAddress remoteAddress, int remotePort) {
    final socket = _socket;
    if (socket == null) return;

    try {
      final replyDevice = localDevice.copyWith(announce: false);
      final payload = utf8.encode(jsonEncode(replyDevice.toJson()));
      // Unicast reply directly to requester to avoid multicast loops
      socket.send(payload, remoteAddress, remotePort);
    } catch (_) {}
  }

  /// Starts periodic multicast advertisement on the given interval.
  void startAdvertising({Duration interval = const Duration(seconds: 3)}) {
    _advertiseTimer?.cancel();
    broadcastAnnounce(localDevice.copyWith(announce: true));
    _advertiseTimer = Timer.periodic(interval, (_) {
      broadcastAnnounce(localDevice.copyWith(announce: true));
    });
  }

  /// Broadcasts announce datagram to multicast group and broadcast address.
  void broadcastAnnounce(AirpadDevice device) {
    final socket = _socket;
    if (socket == null) return;

    try {
      final payload = utf8.encode(jsonEncode(device.toJson()));
      final mAddress = InternetAddress(multicastGroup);

      // Send to multicast group
      socket.send(payload, mAddress, port);

      // Also send to UDP broadcast address (LocalSend fallback technique)
      socket.send(payload, InternetAddress('255.255.255.255'), port);

      // If loopback is active, deliver to loopback interface for local unit testing
      socket.send(payload, InternetAddress.loopbackIPv4, port);
    } catch (_) {}
  }

  /// Stops advertising and closes the UDP socket.
  Future<void> stop() async {
    _advertiseTimer?.cancel();
    _advertiseTimer = null;

    final socket = _socket;
    if (socket != null) {
      try {
        socket.leaveMulticast(InternetAddress(multicastGroup));
      } catch (_) {}
      socket.close();
      _socket = null;
    }
  }

  void dispose() {
    stop();
    _discoveredController.close();
  }
}
