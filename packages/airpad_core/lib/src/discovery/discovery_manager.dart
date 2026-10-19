import 'dart:async';

import '../models/device.dart';
import 'http_fallback_service.dart';
import 'multicast_service.dart';

class _DeviceEntry {
  _DeviceEntry(this.device, this.lastSeen);
  AirpadDevice device;
  DateTime lastSeen;
}

/// Unified discovery manager that coordinates UDP multicast announcement/listening,
/// HTTP registration fallback, and active device tracking.
class DiscoveryManager {
  DiscoveryManager({
    required this.localDevice,
    this.multicastGroup = AirpadProtocolDefaults.multicastGroup,
    this.port = AirpadProtocolDefaults.port,
    int? listenPort,
    this.deviceExpiry = const Duration(seconds: 10),
  })  : _multicast = MulticastDiscoveryService(
          localDevice: localDevice,
          multicastGroup: multicastGroup,
          port: port,
          listenPort: listenPort,
        ),
        _httpServer = HttpRegisterServer(
          localDevice: localDevice,
          port: port,
        ),
        _scanner = SubnetScanner(
          localDevice: localDevice,
          port: port,
        );

  final AirpadDevice localDevice;
  final String multicastGroup;
  final int port;
  final Duration deviceExpiry;

  final MulticastDiscoveryService _multicast;
  final HttpRegisterServer _httpServer;
  final SubnetScanner _scanner;

  final Map<String, _DeviceEntry> _activeDevices = {};
  final _devicesStreamController = StreamController<List<AirpadDevice>>.broadcast();

  StreamSubscription<AirpadDevice>? _multicastSub;
  StreamSubscription<AirpadDevice>? _httpSub;
  Timer? _cleanupTimer;

  /// Stream of active nearby devices, updated on new discovery or expiration.
  Stream<List<AirpadDevice>> get nearbyDevices => _devicesStreamController.stream;

  /// Current snapshot list of nearby active devices.
  List<AirpadDevice> get currentDevices =>
      _activeDevices.values.map((e) => e.device).toList();

  /// Starts advertising this device (for desktop receiver).
  Future<void> startAdvertising() async {
    await _multicast.startListening();
    _multicast.startAdvertising();
    await _httpServer.start();

    _httpSub?.cancel();
    _httpSub = _httpServer.onDeviceRegistered.listen(_onDeviceSeen);
  }

  /// Starts listening for nearby receivers (for mobile controller).
  Future<void> startDiscovery() async {
    await _multicast.startListening();
    _multicastSub?.cancel();
    _multicastSub = _multicast.discoveredDevices.listen(_onDeviceSeen);

    // Send initial query
    _multicast.broadcastAnnounce(localDevice.copyWith(announce: true));

    // Cleanup expired devices every 2 seconds
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(seconds: 2), (_) => _cleanExpired());
  }

  void _onDeviceSeen(AirpadDevice device) {
    if (device.fingerprint == localDevice.fingerprint) return;

    final now = DateTime.now();
    final existing = _activeDevices[device.fingerprint];
    if (existing != null) {
      existing.device = device;
      existing.lastSeen = now;
    } else {
      _activeDevices[device.fingerprint] = _DeviceEntry(device, now);
      _emitUpdate();
    }
  }

  void _cleanExpired() {
    final now = DateTime.now();
    var removed = false;

    _activeDevices.removeWhere((fp, entry) {
      final isExpired = now.difference(entry.lastSeen) > deviceExpiry;
      if (isExpired) removed = true;
      return isExpired;
    });

    if (removed) {
      _emitUpdate();
    }
  }

  void _emitUpdate() {
    if (!_devicesStreamController.isClosed) {
      _devicesStreamController.add(currentDevices);
    }
  }

  /// Manually triggers a subnet HTTP scan fallback.
  Future<List<AirpadDevice>> scanSubnetNow() async {
    final found = await _scanner.scanSubnet();
    for (final dev in found) {
      _onDeviceSeen(dev);
    }
    return currentDevices;
  }

  /// Stops all discovery, advertising, and background timers.
  Future<void> stop() async {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    await _multicastSub?.cancel();
    _multicastSub = null;
    await _httpSub?.cancel();
    _httpSub = null;

    await _multicast.stop();
    await _httpServer.stop();
    _activeDevices.clear();
    _emitUpdate();
  }

  void dispose() {
    stop();
    _multicast.dispose();
    _httpServer.dispose();
    _devicesStreamController.close();
  }
}
