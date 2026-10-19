import 'package:airpad_core/airpad_core.dart';
import 'package:test/test.dart';

void main() {
  group('PairingMessage', () {
    test('PairPromptMessage serialization', () {
      const prompt = PairPromptMessage(code: '849201', fingerprint: 'aabbccdd');
      final json = prompt.toJson();
      expect(json['type'], equals('pair_prompt'));
      expect(json['code'], equals('849201'));
      expect(json['fingerprint'], equals('aabbccdd'));

      final restored = PairingMessage.fromJson(json) as PairPromptMessage;
      expect(restored, equals(prompt));
    });

    test('PairConfirmMessage serialization', () {
      const confirm = PairConfirmMessage(alias: 'My Phone', fingerprint: '11223344');
      final json = confirm.toJson();
      expect(json['type'], equals('pair_confirm'));
      expect(json['alias'], equals('My Phone'));

      final restored = PairingMessage.fromJson(json) as PairConfirmMessage;
      expect(restored, equals(confirm));
    });

    test('PairOkMessage serialization', () {
      const ok = PairOkMessage();
      final json = ok.toJson();
      expect(json['type'], equals('pair_ok'));

      final restored = PairingMessage.fromJson(json) as PairOkMessage;
      expect(restored, equals(ok));
    });

    test('PairRejectMessage serialization', () {
      const reject = PairRejectMessage(reason: 'Timeout');
      final json = reject.toJson();
      expect(json['type'], equals('pair_reject'));
      expect(json['reason'], equals('Timeout'));

      final restored = PairingMessage.fromJson(json) as PairRejectMessage;
      expect(restored, equals(reject));
    });

    test('PairQrMessage serialization', () {
      const qr = PairQrMessage(
        code: '123456',
        alias: 'Scanner',
        fingerprint: 'deadbeef',
      );
      final json = qr.toJson();
      expect(json['type'], equals('pair_qr'));
      expect(json['code'], equals('123456'));

      final restored = PairingMessage.fromJson(json) as PairQrMessage;
      expect(restored, equals(qr));
    });

    test('fromJsonString and toJsonString roundtrip', () {
      const prompt = PairPromptMessage(code: '654321', fingerprint: 'ffeeddcc');
      final str = prompt.toJsonString();
      final restored = PairingMessage.fromJsonString(str) as PairPromptMessage;
      expect(restored, equals(prompt));
    });

    test('throws on unknown pairing type or malformed input', () {
      expect(() => PairingMessage.fromJson({'type': 'invalid'}), throwsFormatException);
      expect(() => PairingMessage.fromJsonString('not-json'), throwsFormatException);
      expect(() => PairingMessage.fromJsonString('[]'), throwsFormatException);
    });
  });
}
