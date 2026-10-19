import 'dart:convert';
import 'dart:io';
import '../models/device.dart';

/// Manages persistent and in-memory storage of trusted device fingerprints.
class TrustStore {
  TrustStore({this.storageFile});

  final File? storageFile;
  final Map<String, AirpadDevice> _trusted = {};

  /// Returns an unmodifiable list of trusted devices.
  List<AirpadDevice> get trustedDevices => List.unmodifiable(_trusted.values);

  /// Checks if a device fingerprint is trusted.
  bool isTrusted(String fingerprint) {
    return _trusted.containsKey(fingerprint.toLowerCase());
  }

  /// Retrieves a trusted device by fingerprint.
  AirpadDevice? getDevice(String fingerprint) {
    return _trusted[fingerprint.toLowerCase()];
  }

  /// Adds a device to the trusted device store and persists if file is provided.
  Future<void> trustDevice(AirpadDevice device) async {
    _trusted[device.fingerprint.toLowerCase()] = device;
    await save();
  }

  /// Removes a device from the trusted store.
  Future<bool> revokeDevice(String fingerprint) async {
    final removed = _trusted.remove(fingerprint.toLowerCase()) != null;
    if (removed) {
      await save();
    }
    return removed;
  }

  /// Clears all trusted devices.
  Future<void> clearAll() async {
    _trusted.clear();
    await save();
  }

  /// Loads trusted devices from [storageFile] if it exists.
  Future<void> load() async {
    final file = storageFile;
    if (file == null || !await file.exists()) return;

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as List<dynamic>;
      _trusted.clear();
      for (final item in json) {
        if (item is Map<String, dynamic>) {
          final device = AirpadDevice.fromJson(item);
          _trusted[device.fingerprint.toLowerCase()] = device;
        }
      }
    } catch (_) {
      // Corrupt file will be overwritten on next save
    }
  }

  /// Saves trusted devices to [storageFile].
  Future<void> save() async {
    final file = storageFile;
    if (file == null) return;

    try {
      final list = _trusted.values.map((d) => d.toJson()).toList();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(list), flush: true);
    } catch (_) {}
  }
}
