import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:airpad_core/airpad_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Central state and services coordinator for the mobile AIRPAD client.
class MobileServices extends ChangeNotifier {
  MobileServices();

  @visibleForTesting
  MobileServices.forTesting({
    required DeviceIdentity identity,
    required TrustStore trustStore,
    required DiscoveryManager discoveryManager,
    required TlsSessionClient sessionClient,
    required TouchpadProcessor touchpadProcessor,
    required KeyboardState keyboardState,
  }) {
    _identity = identity;
    _trustStore = trustStore;
    _discoveryManager = discoveryManager;
    _sessionClient = sessionClient;
    _touchpadProcessor = touchpadProcessor;
    _keyboardState = keyboardState;
    _isInitialized = true;
  }

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  late DeviceIdentity _identity;
  late TrustStore _trustStore;
  late DiscoveryManager _discoveryManager;
  late TlsSessionClient _sessionClient;
  late TouchpadProcessor _touchpadProcessor;
  late KeyboardState _keyboardState;

  StreamSubscription<SessionState>? _sessionSub;

  // Settings
  double _sensitivity = 1.0;
  bool _naturalScroll = true;
  bool _threeFingerSwipes = true;
  bool _hapticsEnabled = true;
  bool _keepScreenOn = true;
  bool _isDark = true;

  File? _settingsFile;
  File? _identityFile;

  DeviceIdentity get identity => _identity;
  TrustStore get trustStore => _trustStore;
  DiscoveryManager get discoveryManager => _discoveryManager;
  TlsSessionClient get sessionClient => _sessionClient;
  TouchpadProcessor get touchpadProcessor => _touchpadProcessor;
  KeyboardState get keyboardState => _keyboardState;

  double get sensitivity => _sensitivity;
  bool get naturalScroll => _naturalScroll;
  bool get threeFingerSwipes => _threeFingerSwipes;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get keepScreenOn => _keepScreenOn;
  bool get isDark => _isDark;

  SessionState get sessionState => _sessionClient.state;

  /// Initializes identity, trust store, discovery manager, and loads settings.
  Future<void> initialize() async {
    final docDir = await getApplicationDocumentsDirectory();
    final airpadDir = Directory('${docDir.path}/airpad');
    if (!await airpadDir.exists()) {
      await airpadDir.create(recursive: true);
    }

    _identityFile = File('${airpadDir.path}/identity.json');
    if (await _identityFile!.exists()) {
      try {
        final content = await _identityFile!.readAsString();
        _identity = DeviceIdentity.fromJson(jsonDecode(content) as Map<String, dynamic>);
      } catch (_) {
        _identity = await DeviceIdentity.generate(
          alias: AliasGenerator.generate(),
        );
        await _identityFile!.writeAsString(jsonEncode(_identity.toJson()), flush: true);
      }
    } else {
      _identity = await DeviceIdentity.generate(
        alias: AliasGenerator.generate(),
      );
      await _identityFile!.writeAsString(jsonEncode(_identity.toJson()), flush: true);
    }

    // Initialize TrustStore
    final trustFile = File('${airpadDir.path}/trusted.json');
    _trustStore = TrustStore(storageFile: trustFile);
    await _trustStore.load();

    // Load Settings
    _settingsFile = File('${airpadDir.path}/settings.json');
    await _loadSettings();

    // Initialize TouchpadProcessor & KeyboardState
    _touchpadProcessor = TouchpadProcessor(
      sensitivity: _sensitivity,
      naturalScroll: _naturalScroll,
      threeFingerSwipesEnabled: _threeFingerSwipes,
      onEvent: (event) {
        _sessionClient.sendEvent(event);
      },
      onThreeFingerSwipe: (dir) {
        if (_hapticsEnabled) {
          HapticFeedback.mediumImpact();
        }
      },
    );

    _keyboardState = KeyboardState(
      onEvent: (event) {
        _sessionClient.sendEvent(event);
      },
    );

    // Initialize TlsSessionClient
    _sessionClient = TlsSessionClient(
      localIdentity: _identity,
      trustStore: _trustStore,
    );

    _sessionSub = _sessionClient.onStateChanged.listen((state) {
      notifyListeners();
    });

    // Initialize DiscoveryManager in client mode
    final localDevice = AirpadDevice(
      alias: _identity.alias,
      fingerprint: _identity.fingerprint,
      deviceType: DeviceType.mobile,
      ip: '127.0.0.1',
    );

    _discoveryManager = DiscoveryManager(
      localDevice: localDevice,
    );

    try {
      await _discoveryManager.startDiscovery();
    } catch (e) {
      debugPrint('[AirpadMobile] Warning: Discovery failed to start: $e');
    }

    // Apply initial wakelock
    if (_keepScreenOn) {
      try {
        await WakelockPlus.enable();
      } catch (e) {
        debugPrint('[AirpadMobile] Warning: Wakelock enable failed: $e');
      }
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    if (_settingsFile != null && await _settingsFile!.exists()) {
      try {
        final raw = await _settingsFile!.readAsString();
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _sensitivity = (map['sensitivity'] as num?)?.toDouble() ?? 1.0;
        _naturalScroll = map['naturalScroll'] as bool? ?? true;
        _threeFingerSwipes = map['threeFingerSwipes'] as bool? ?? true;
        _hapticsEnabled = map['hapticsEnabled'] as bool? ?? true;
        _keepScreenOn = map['keepScreenOn'] as bool? ?? true;
        _isDark = map['isDark'] as bool? ?? true;
      } catch (_) {}
    }
  }

  Future<void> _saveSettings() async {
    if (_settingsFile == null) return;
    try {
      final map = {
        'sensitivity': _sensitivity,
        'naturalScroll': _naturalScroll,
        'threeFingerSwipes': _threeFingerSwipes,
        'hapticsEnabled': _hapticsEnabled,
        'keepScreenOn': _keepScreenOn,
        'isDark': _isDark,
      };
      await _settingsFile!.writeAsString(jsonEncode(map), flush: true);
    } catch (_) {}
  }

  Future<void> setSensitivity(double value) async {
    _sensitivity = value;
    _touchpadProcessor.sensitivity = value;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setNaturalScroll(bool value) async {
    _naturalScroll = value;
    _touchpadProcessor.naturalScroll = value;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setThreeFingerSwipes(bool value) async {
    _threeFingerSwipes = value;
    _touchpadProcessor.threeFingerSwipesEnabled = value;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setHapticsEnabled(bool value) async {
    _hapticsEnabled = value;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setKeepScreenOn(bool value) async {
    _keepScreenOn = value;
    if (_keepScreenOn) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setIsDark(bool value) async {
    _isDark = value;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> updateAlias(String newAlias) async {
    if (newAlias.trim().isEmpty) return;
    final updated = DeviceIdentity(
      alias: newAlias.trim(),
      privateKeyPem: _identity.privateKeyPem,
      certificatePem: _identity.certificatePem,
      fingerprint: _identity.fingerprint,
      certificateDer: _identity.certificateDer,
    );
    _identity = updated;
    if (_identityFile != null) {
      await _identityFile!.writeAsString(jsonEncode(updated.toJson()), flush: true);
    }
    notifyListeners();
  }

  /// Connects to a desktop receiver.
  Future<void> connectToDevice(AirpadDevice device) async {
    final ip = device.ip ?? '127.0.0.1';
    await _sessionClient.connect(
      host: ip,
      port: device.port,
      expectedFingerprint: device.fingerprint,
    );
  }

  /// Connects using scanned QR payload with secret code.
  Future<void> connectToQr(QrPairingPayload payload) async {
    await _sessionClient.connect(
      host: payload.ip,
      port: payload.port,
      expectedFingerprint: payload.fingerprint,
      qrCode: payload.code,
    );
  }

  /// Connects to manual IP and port.
  Future<void> connectToIp(String ip, int port) async {
    await _sessionClient.connect(
      host: ip,
      port: port,
    );
  }

  /// Cleanly disconnects the active session.
  Future<void> disconnect() async {
    await _sessionClient.disconnect();
    _keyboardState.clearModifiers();
  }

  /// Triggers a subtle tactile haptic tick if enabled.
  void triggerHaptic() {
    if (_hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
  }

  /// Triggers a mouse click haptic tick if enabled.
  void triggerClickHaptic() {
    if (_hapticsEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    _sessionClient.dispose();
    _discoveryManager.dispose();
    _touchpadProcessor.dispose();
    _keyboardState.dispose();
    super.dispose();
  }
}
