import 'package:airpad_core/airpad_core.dart';
import 'package:test/test.dart';

void main() {
  group('AirpadDevice', () {
    const validFingerprint =
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

    test('serializes and deserializes correctly', () {
      const device = AirpadDevice(
        alias: 'Quiet Falcon',
        fingerprint: validFingerprint,
        deviceType: DeviceType.desktop,
        port: 53318,
        announce: true,
        ip: '192.168.1.50',
      );

      final json = device.toJson();
      expect(json['alias'], equals('Quiet Falcon'));
      expect(json['fingerprint'], equals(validFingerprint));
      expect(json['deviceType'], equals('desktop'));
      expect(json['ip'], equals('192.168.1.50'));

      final restored = AirpadDevice.fromJson(json);
      expect(restored, equals(device));
      expect(restored.shortFingerprint, equals('e3b0-c442-98fc'));
    });

    test('validates valid and invalid device configurations', () {
      const validDevice = AirpadDevice(
        alias: 'Swift Otter',
        fingerprint: validFingerprint,
        deviceType: DeviceType.mobile,
      );
      expect(validDevice.isValid(), isTrue);

      const emptyAlias = AirpadDevice(
        alias: '  ',
        fingerprint: validFingerprint,
        deviceType: DeviceType.mobile,
      );
      expect(emptyAlias.isValid(), isFalse);

      const invalidPort = AirpadDevice(
        alias: 'Swift Otter',
        fingerprint: validFingerprint,
        deviceType: DeviceType.mobile,
        port: 70000,
      );
      expect(invalidPort.isValid(), isFalse);

      const shortFp = AirpadDevice(
        alias: 'Swift Otter',
        fingerprint: '1234abcd',
        deviceType: DeviceType.mobile,
      );
      expect(shortFp.isValid(), isFalse);
    });

    test('copyWith updates properties properly', () {
      const device = AirpadDevice(
        alias: 'Swift Otter',
        fingerprint: validFingerprint,
        deviceType: DeviceType.mobile,
      );

      final updated = device.copyWith(alias: 'Bold Eagle', announce: false);
      expect(updated.alias, equals('Bold Eagle'));
      expect(updated.announce, isFalse);
      expect(updated.fingerprint, equals(validFingerprint));
    });
  });
}
