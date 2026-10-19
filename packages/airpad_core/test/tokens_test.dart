import 'package:airpad_core/airpad_core.dart';
import 'package:test/test.dart';

void main() {
  group('AirpadTokens', () {
    test('defines strictly monochrome color values', () {
      expect(AirpadTokens.black, equals(0xFF000000));
      expect(AirpadTokens.white, equals(0xFFFFFFFF));
      expect(AirpadTokens.gray900, equals(0xFF111111));
      expect(AirpadTokens.gray700, equals(0xFF2A2A2A));
      expect(AirpadTokens.gray500, equals(0xFF777777));
      expect(AirpadTokens.gray100, equals(0xFFEDEDED));
    });

    test('defines geometry and spacing matching design rules', () {
      expect(AirpadTokens.gridBase, equals(8.0));
      expect(AirpadTokens.borderWidth, equals(1.0));
      expect(AirpadTokens.cornerRadius, lessThanOrEqualTo(4.0));
      expect(AirpadTokens.minTouchTarget, greaterThanOrEqualTo(48.0));
    });

    test('animation durations respect fast responsiveness', () {
      expect(AirpadTokens.animFast.inMilliseconds, lessThanOrEqualTo(150));
      expect(AirpadTokens.animTapFlash.inMilliseconds, lessThanOrEqualTo(50));
    });
  });
}
