import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

import '../models/device.dart';
import '../utils/alias_generator.dart';

/// Cryptographic identity of an Airpad device: keypair, self-signed TLS certificate,
/// SHA-256 fingerprint, and user-friendly alias.
@immutable
class DeviceIdentity {
  const DeviceIdentity({
    required this.alias,
    required this.certificatePem,
    required this.privateKeyPem,
    required this.fingerprint,
    required this.certificateDer,
  });

  /// Friendly two-word alias.
  final String alias;

  /// Self-signed X.509 certificate in PEM format.
  final String certificatePem;

  /// RSA private key in PKCS#1 or PKCS#8 PEM format.
  final String privateKeyPem;

  /// SHA-256 fingerprint in lowercase hex (64 characters).
  final String fingerprint;

  /// Raw DER-encoded certificate bytes.
  final Uint8List certificateDer;

  /// Formatted short fingerprint (e.g. "a1b2-c3d4-e5f6").
  String get shortFingerprint {
    if (fingerprint.length < 12) return fingerprint;
    return '${fingerprint.substring(0, 4)}-${fingerprint.substring(4, 8)}-${fingerprint.substring(8, 12)}';
  }

  /// Converts this identity into an [AirpadDevice] announce descriptor.
  AirpadDevice toDevice({
    required DeviceType deviceType,
    int port = AirpadProtocolDefaults.port,
    bool announce = true,
    String? ip,
  }) {
    return AirpadDevice(
      alias: alias,
      fingerprint: fingerprint,
      deviceType: deviceType,
      port: port,
      announce: announce,
      ip: ip,
    );
  }

  /// Creates a configured [SecurityContext] for TLS server or client use.
  SecurityContext createSecurityContext() {
    final context = SecurityContext(withTrustedRoots: false);
    context.useCertificateChainBytes(utf8.encode(certificatePem));
    context.usePrivateKeyBytes(utf8.encode(privateKeyPem));
    return context;
  }

  /// Generates a new self-signed certificate, RSA key pair, and identity.
  static Future<DeviceIdentity> generate({
    String? alias,
    int keySize = 2048,
  }) async {
    final deviceAlias = alias ?? AliasGenerator.generate();
    final keyPair = CryptoUtils.generateRSAKeyPair(keySize: keySize);
    final privKey = keyPair.privateKey as RSAPrivateKey;
    final pubKey = keyPair.publicKey as RSAPublicKey;

    final csr = X509Utils.generateRsaCsrPem(
      {'CN': 'airpad-$deviceAlias'},
      privKey,
      pubKey,
    );

    // 10-year validity (~3650 days) per protocol specification
    final certPem = X509Utils.generateSelfSignedCertificate(
      privKey,
      csr,
      3650,
      sans: ['airpad.local', 'localhost'],
    );

    final privKeyPem = CryptoUtils.encodeRSAPrivateKeyToPem(privKey);
    final derBytes = derFromPem(certPem);
    final fp = computeFingerprintFromDer(derBytes);

    return DeviceIdentity(
      alias: deviceAlias,
      certificatePem: certPem,
      privateKeyPem: privKeyPem,
      fingerprint: fp,
      certificateDer: derBytes,
    );
  }

  /// Computes SHA-256 fingerprint (hex) from DER certificate bytes.
  static String computeFingerprintFromDer(List<int> derBytes) {
    return sha256.convert(derBytes).toString().toLowerCase();
  }

  /// Computes SHA-256 fingerprint (hex) from PEM certificate string.
  static String computeFingerprintFromPem(String pem) {
    return computeFingerprintFromDer(derFromPem(pem));
  }

  /// Extracts DER bytes from a PEM certificate string.
  static Uint8List derFromPem(String pem) {
    final clean = pem.replaceAll(RegExp(r'-----[^\n]+-----|\s+'), '');
    return Uint8List.fromList(base64.decode(base64.normalize(clean)));
  }

  Map<String, dynamic> toJson() => {
        'alias': alias,
        'certificatePem': certificatePem,
        'privateKeyPem': privateKeyPem,
        'fingerprint': fingerprint,
        'certificateDer': base64.encode(certificateDer),
      };

  factory DeviceIdentity.fromJson(Map<String, dynamic> json) {
    final certPem = json['certificatePem'] as String;
    final privKeyPem = json['privateKeyPem'] as String;
    final alias = json['alias'] as String? ?? 'Quiet Falcon';
    final rawFp = json['fingerprint'] as String?;
    final rawDer = json['certificateDer'] as String?;

    final der = rawDer != null
        ? Uint8List.fromList(base64.decode(rawDer))
        : derFromPem(certPem);
    final fp = rawFp ?? computeFingerprintFromDer(der);

    return DeviceIdentity(
      alias: alias,
      certificatePem: certPem,
      privateKeyPem: privKeyPem,
      fingerprint: fp.toLowerCase(),
      certificateDer: der,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceIdentity &&
          runtimeType == other.runtimeType &&
          fingerprint == other.fingerprint &&
          alias == other.alias &&
          certificatePem == other.certificatePem &&
          privateKeyPem == other.privateKeyPem;

  @override
  int get hashCode =>
      fingerprint.hashCode ^
      alias.hashCode ^
      certificatePem.hashCode ^
      privateKeyPem.hashCode;
}
