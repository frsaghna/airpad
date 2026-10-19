import 'package:airpad_core/airpad_core.dart';
import 'package:test/test.dart';

void main() {
  group('MoveCoalescer', () {
    test('coalesces multiple rapid deltas into a single MoveEvent', () async {
      final events = <MoveEvent>[];
      final coalescer = MoveCoalescer(
        tickInterval: const Duration(milliseconds: 20),
        onEvent: events.add,
      );

      // Add deltas before tick
      coalescer.addDelta(2.0, 3.0);
      coalescer.addDelta(1.5, -0.5);
      coalescer.addDelta(-0.5, 1.0);

      // Wait for tick
      await Future.delayed(const Duration(milliseconds: 35));

      expect(events.length, equals(1));
      expect(events.first.dx, closeTo(3.0, 0.001));
      expect(events.first.dy, closeTo(3.5, 0.001));

      coalescer.dispose();
    });

    test('emits nothing when no deltas added', () async {
      final events = <MoveEvent>[];
      final coalescer = MoveCoalescer(
        tickInterval: const Duration(milliseconds: 15),
        onEvent: events.add,
      );

      await Future.delayed(const Duration(milliseconds: 40));
      expect(events, isEmpty);

      coalescer.dispose();
    });

    test('flush immediately triggers emission of pending deltas', () {
      final events = <MoveEvent>[];
      final coalescer = MoveCoalescer(
        tickInterval: const Duration(seconds: 10), // long interval
        onEvent: events.add,
      );

      coalescer.addDelta(10.0, -5.0);
      expect(events, isEmpty);

      coalescer.flush();
      expect(events.length, equals(1));
      expect(events.first.dx, equals(10.0));
      expect(events.first.dy, equals(-5.0));

      coalescer.dispose();
    });
  });
}
