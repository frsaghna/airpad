import 'dart:math';

/// Represents parsed QR code pairing payload.
class QrPairingPayload {
  const QrPairingPayload({
    required this.ip,
    required this.port,
    required this.fingerprint,
    required this.code,
    required this.alias,
  });

  final String ip;
  final int port;
  final String fingerprint;
  final String code;
  final String alias;

  /// Serializes into protocol QR code URI.
  String toUriString() {
    final encAlias = Uri.encodeComponent(alias);
    return 'airpad://v1?ip=$ip&port=$port&fp=$fingerprint&code=$code&alias=$encAlias';
  }

  /// Parses from protocol QR code URI.
  static QrPairingPayload? tryParse(String uriString) {
    try {
      final uri = Uri.parse(uriString);
      if (uri.scheme != 'airpad' || uri.host != 'v1') return null;

      final ip = uri.queryParameters['ip'];
      final portStr = uri.queryParameters['port'];
      final fp = uri.queryParameters['fp'];
      final code = uri.queryParameters['code'];
      final alias = uri.queryParameters['alias'];

      if (ip == null || portStr == null || fp == null || code == null || alias == null) {
        return null;
      }

      final port = int.tryParse(portStr);
      if (port == null || port < 1 || port > 65535) return null;

      return QrPairingPayload(
        ip: ip,
        port: port,
        fingerprint: fp.toLowerCase(),
        code: code,
        alias: Uri.decodeComponent(alias),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Helper for generating cryptographic 6-digit pairing codes and QR codes.
abstract final class PairingCodeHelper {
  static final _secureRandom = Random.secure();

  /// Generates a 6-digit verification code (e.g. "849201").
  static String generateCode() {
    final val = _secureRandom.nextInt(1000000);
    return val.toString().padLeft(6, '0');
  }

  /// Generates a QR code string for the desktop receiver.
  static String generateQrString({
    required String ip,
    required int port,
    required String fingerprint,
    required String code,
    required String alias,
  }) {
    return QrPairingPayload(
      ip: ip,
      port: port,
      fingerprint: fingerprint,
      code: code,
      alias: alias,
    ).toUriString();
  }
}
