import 'package:meta/meta.dart';

/// Type of device in the Airpad ecosystem.
enum DeviceType {
  desktop,
  mobile;

  String toJson() => name;

  static DeviceType fromJson(String value) {
    switch (value) {
      case 'desktop':
        return DeviceType.desktop;
      case 'mobile':
        return DeviceType.mobile;
      default:
        throw ArgumentError.value(value, 'deviceType', 'Unknown device type');
    }
  }
}

/// Constant protocol defaults.
abstract final class AirpadProtocolDefaults {
  static const int port = 53318;
  static const String multicastGroup = '224.0.0.167';
  static const String version = 'airpad/1';
}

/// Represents an Airpad device announced over LAN or saved in trusted devices.
@immutable
class AirpadDevice {
  const AirpadDevice({
    required this.alias,
    required this.fingerprint,
    required this.deviceType,
    this.version = AirpadProtocolDefaults.version,
    this.port = AirpadProtocolDefaults.port,
    this.announce = true,
    this.ip,
  });

  /// Protocol version string (e.g. "airpad/1").
  final String version;

  /// User-friendly alias (e.g. "Quiet Falcon").
  final String alias;

  /// SHA-256 certificate fingerprint in lowercase hexadecimal.
  final String fingerprint;

  /// Port on which service or WebSocket is running.
  final int port;

  /// Whether this is a desktop or mobile device.
  final DeviceType deviceType;

  /// For discovery messages: whether receivers should reply.
  final bool announce;

  /// IP address from which the message was received or where host is reachable.
  final String? ip;

  /// Formatted short fingerprint for pairing UI (e.g. "a1b2-c3d4-e5f6").
  String get shortFingerprint {
    final clean = fingerprint.replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toLowerCase();
    if (clean.length < 12) return clean;
    return '${clean.substring(0, 4)}-${clean.substring(4, 8)}-${clean.substring(8, 12)}';
  }

  /// Validates the device fields against protocol specifications.
  bool isValid() {
    if (version != AirpadProtocolDefaults.version) return false;
    if (alias.trim().isEmpty) return false;
    if (port < 1 || port > 65535) return false;
    final hexRegex = RegExp(r'^[0-9a-fA-F]{64}$');
    if (!hexRegex.hasMatch(fingerprint)) return false;
    return true;
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'alias': alias,
        'fingerprint': fingerprint.toLowerCase(),
        'port': port,
        'deviceType': deviceType.toJson(),
        'announce': announce,
        if (ip != null) 'ip': ip,
      };

  factory AirpadDevice.fromJson(Map<String, dynamic> json) {
    return AirpadDevice(
      version: json['version'] as String? ?? AirpadProtocolDefaults.version,
      alias: json['alias'] as String? ?? 'Unknown',
      fingerprint: (json['fingerprint'] as String? ?? '').toLowerCase(),
      port: (json['port'] as num?)?.toInt() ?? AirpadProtocolDefaults.port,
      deviceType: DeviceType.fromJson(json['deviceType'] as String? ?? 'desktop'),
      announce: json['announce'] as bool? ?? true,
      ip: json['ip'] as String?,
    );
  }

  AirpadDevice copyWith({
    String? version,
    String? alias,
    String? fingerprint,
    int? port,
    DeviceType? deviceType,
    bool? announce,
    String? ip,
  }) {
    return AirpadDevice(
      version: version ?? this.version,
      alias: alias ?? this.alias,
      fingerprint: fingerprint ?? this.fingerprint,
      port: port ?? this.port,
      deviceType: deviceType ?? this.deviceType,
      announce: announce ?? this.announce,
      ip: ip ?? this.ip,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AirpadDevice &&
          runtimeType == other.runtimeType &&
          fingerprint == other.fingerprint &&
          alias == other.alias &&
          port == other.port &&
          deviceType == other.deviceType &&
          announce == other.announce &&
          ip == other.ip;

  @override
  int get hashCode =>
      fingerprint.hashCode ^
      alias.hashCode ^
      port.hashCode ^
      deviceType.hashCode ^
      announce.hashCode ^
      (ip?.hashCode ?? 0);

  @override
  String toString() =>
      'AirpadDevice(alias: $alias, type: ${deviceType.name}, shortFp: $shortFingerprint, ip: $ip:$port)';
}
