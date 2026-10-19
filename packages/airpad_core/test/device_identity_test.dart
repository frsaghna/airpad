import 'package:airpad_core/airpad_core.dart';
import 'package:test/test.dart';

void main() {
  group('DeviceIdentity', () {
    test('generates self-signed identity and computes correct fingerprint', () async {
      // Use 1024-bit key for fast unit testing
      final identity = await DeviceIdentity.generate(
        alias: 'Test Falcon',
        keySize: 1024,
      );

      expect(identity.alias, equals('Test Falcon'));
      expect(identity.certificatePem, contains('BEGIN CERTIFICATE'));
      expect(identity.privateKeyPem, contains('PRIVATE KEY'));
      expect(identity.fingerprint.length, equals(64));
      expect(identity.certificateDer, isNotEmpty);
      expect(identity.shortFingerprint.split('-').length, equals(3));

      // Verify toDevice
      final device = identity.toDevice(
        deviceType: DeviceType.desktop,
        port: 53318,
      );
      expect(device.alias, equals('Test Falcon'));
      expect(device.fingerprint, equals(identity.fingerprint));
      expect(device.deviceType, equals(DeviceType.desktop));

      // Verify SecurityContext creation
      final secCtx = identity.createSecurityContext();
      expect(secCtx, isNotNull);

      // Verify JSON roundtrip
      final json = identity.toJson();
      final restored = DeviceIdentity.fromJson(json);
      expect(restored.alias, equals(identity.alias));
      expect(restored.fingerprint, equals(identity.fingerprint));
      expect(restored.certificatePem, equals(identity.certificatePem));
      expect(restored.privateKeyPem, equals(identity.privateKeyPem));
      expect(restored.certificateDer, equals(identity.certificateDer));

      // Verify derFromPem and computeFingerprintFromPem
      final der = DeviceIdentity.derFromPem(identity.certificatePem);
      expect(der, equals(identity.certificateDer));

      final fp = DeviceIdentity.computeFingerprintFromPem(identity.certificatePem);
      expect(fp, equals(identity.fingerprint));
    });
  });
}
