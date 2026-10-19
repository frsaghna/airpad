import 'package:airpad_core/airpad_core.dart';
import 'package:test/test.dart';

void main() {
  group('Security: RateLimiter & Message Bounding', () {
    test('RateLimiter allows burst up to capacity and throttles excessive requests', () {
      final limiter = RateLimiter(maxPerSecond: 10, burstCapacity: 5);

      // Consume initial burst
      for (var i = 0; i < 5; i++) {
        expect(limiter.tryAcquire(), isTrue);
      }

      // Next immediate attempt should be rejected
      expect(limiter.tryAcquire(), isFalse);
    });

    test('RateLimiter recovers tokens over time', () async {
      final limiter = RateLimiter(maxPerSecond: 100, burstCapacity: 2);

      expect(limiter.tryAcquire(), isTrue);
      expect(limiter.tryAcquire(), isTrue);
      expect(limiter.tryAcquire(), isFalse);

      // Wait 30ms for ~3 tokens
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(limiter.tryAcquire(), isTrue);
    });
  });
}
