import 'dart:io';
import 'package:airpad_core/airpad_core.dart';
import 'package:test/test.dart';

void main() {
  group('TrustStore', () {
    const dev1 = AirpadDevice(
      alias: 'Phone One',
      fingerprint: '1111111111111111111111111111111111111111111111111111111111111111',
      deviceType: DeviceType.mobile,
    );

    const dev2 = AirpadDevice(
      alias: 'Phone Two',
      fingerprint: '2222222222222222222222222222222222222222222222222222222222222222',
      deviceType: DeviceType.mobile,
    );

    test('trusts, checks, and revokes devices in memory', () async {
      final store = TrustStore();
      expect(store.isTrusted(dev1.fingerprint), isFalse);

      await store.trustDevice(dev1);
      expect(store.isTrusted(dev1.fingerprint), isTrue);
      expect(store.trustedDevices.length, equals(1));

      // Case insensitivity
      expect(store.isTrusted(dev1.fingerprint.toUpperCase()), isTrue);

      final revoked = await store.revokeDevice(dev1.fingerprint);
      expect(revoked, isTrue);
      expect(store.isTrusted(dev1.fingerprint), isFalse);
    });

    test('persists and reloads from file', () async {
      final tempDir = await Directory.systemTemp.createTemp('airpad_trust_test_');
      final file = File('${tempDir.path}/trusted.json');

      final store1 = TrustStore(storageFile: file);
      await store1.trustDevice(dev1);
      await store1.trustDevice(dev2);
      expect(await file.exists(), isTrue);

      final store2 = TrustStore(storageFile: file);
      await store2.load();
      expect(store2.trustedDevices.length, equals(2));
      expect(store2.isTrusted(dev1.fingerprint), isTrue);
      expect(store2.isTrusted(dev2.fingerprint), isTrue);

      await tempDir.delete(recursive: true);
    });
  });
}
