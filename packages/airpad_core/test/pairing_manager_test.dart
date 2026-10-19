import 'package:airpad_core/airpad_core.dart';
import 'package:test/test.dart';

void main() {
  group('PairingCodeHelper & QrPairingPayload', () {
    test('generateCode returns 6-digit zero-padded string', () {
      for (int i = 0; i < 20; i++) {
        final code = PairingCodeHelper.generateCode();
        expect(code.length, equals(6));
        expect(int.tryParse(code), isNotNull);
      }
    });

    test('generateQrString and tryParse roundtrip correctly', () {
      const ip = '192.168.1.100';
      const port = 53318;
      const fp = '11223344556677889900aabbccddeeff11223344556677889900aabbccddeeff';
      const code = '849201';
      const alias = 'Swift Otter';

      final uriString = PairingCodeHelper.generateQrString(
        ip: ip,
        port: port,
        fingerprint: fp,
        code: code,
        alias: alias,
      );

      expect(uriString, startsWith('airpad://v1?'));
      expect(uriString, contains('ip=192.168.1.100'));
      expect(uriString, contains('code=849201'));

      final payload = QrPairingPayload.tryParse(uriString);
      expect(payload, isNotNull);
      expect(payload!.ip, equals(ip));
      expect(payload.port, equals(port));
      expect(payload.fingerprint, equals(fp));
      expect(payload.code, equals(code));
      expect(payload.alias, equals(alias));
    });

    test('tryParse returns null on invalid URI', () {
      expect(QrPairingPayload.tryParse('invalid-uri'), isNull);
      expect(QrPairingPayload.tryParse('http://example.com'), isNull);
      expect(QrPairingPayload.tryParse('airpad://v2?ip=1.1.1.1'), isNull);
    });
  });
}
