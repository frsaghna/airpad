import 'package:airpad_core/airpad_core.dart';
import 'package:test/test.dart';

void main() {
  group('TouchpadProcessor', () {
    test('single finger move generates MoveEvent with sensitivity and acceleration', () async {
      final events = <AirpadEvent>[];
      final processor = TouchpadProcessor(
        sensitivity: 1.5,
        onEvent: events.add,
      );

      processor.onPointerDown(0, 100.0, 100.0);
      processor.onPointerMove(0, 110.0, 105.0, 10.0, 5.0);
      processor.onPointerUp(0, 110.0, 105.0);

      // Wait brief moment for coalescer flush
      await Future.delayed(const Duration(milliseconds: 30));

      expect(events.whereType<MoveEvent>().isNotEmpty, isTrue);
      final move = events.whereType<MoveEvent>().first;
      expect(move.dx, greaterThan(10.0 * 1.5)); // accelerated & scaled
      expect(move.dy, greaterThan(5.0 * 1.5));

      processor.dispose();
    });

    test('single finger tap emits left click', () async {
      final events = <AirpadEvent>[];
      final processor = TouchpadProcessor(onEvent: events.add);

      processor.onPointerDown(0, 50.0, 50.0);
      await Future.delayed(const Duration(milliseconds: 30));
      processor.onPointerUp(0, 50.0, 50.0);

      expect(events.whereType<ClickEvent>().isNotEmpty, isTrue);
      final click = events.whereType<ClickEvent>().first;
      expect(click.button, equals(MouseButton.left));
      expect(click.count, equals(1));

      processor.dispose();
    });

    test('rapid double tap emits double click', () async {
      final events = <AirpadEvent>[];
      final processor = TouchpadProcessor(
        doubleTapInterval: const Duration(milliseconds: 300),
        onEvent: events.add,
      );

      // Tap 1
      processor.onPointerDown(0, 50.0, 50.0);
      processor.onPointerUp(0, 50.0, 50.0);

      // Tap 2 within double tap interval
      await Future.delayed(const Duration(milliseconds: 50));
      processor.onPointerDown(0, 50.0, 50.0);
      processor.onPointerUp(0, 50.0, 50.0);

      final clicks = events.whereType<ClickEvent>().toList();
      expect(clicks.any((c) => c.count == 2), isTrue);

      processor.dispose();
    });

    test('two finger tap emits right click', () async {
      final events = <AirpadEvent>[];
      final processor = TouchpadProcessor(onEvent: events.add);

      processor.onPointerDown(0, 50.0, 50.0);
      processor.onPointerDown(1, 80.0, 50.0);
      await Future.delayed(const Duration(milliseconds: 30));
      processor.onPointerUp(0, 50.0, 50.0);
      processor.onPointerUp(1, 80.0, 50.0);

      final rightClicks = events.whereType<ClickEvent>().where((c) => c.button == MouseButton.right);
      expect(rightClicks.isNotEmpty, isTrue);
      expect(rightClicks.first.count, equals(1));

      processor.dispose();
    });

    test('two finger drag emits ScrollEvent', () {
      final events = <AirpadEvent>[];
      final processor = TouchpadProcessor(
        naturalScroll: true,
        onEvent: events.add,
      );

      processor.onPointerDown(0, 50.0, 50.0);
      processor.onPointerDown(1, 80.0, 50.0);
      processor.onPointerMove(0, 50.0, 65.0, 0.0, 15.0);
      processor.onPointerUp(0, 50.0, 65.0);
      processor.onPointerUp(1, 80.0, 50.0);

      final scrolls = events.whereType<ScrollEvent>().toList();
      expect(scrolls.isNotEmpty, isTrue);
      expect(scrolls.first.dy, equals(15.0));

      processor.dispose();
    });

    test('three finger tap emits middle click', () async {
      final events = <AirpadEvent>[];
      final processor = TouchpadProcessor(onEvent: events.add);

      processor.onPointerDown(0, 40.0, 50.0);
      processor.onPointerDown(1, 70.0, 50.0);
      processor.onPointerDown(2, 100.0, 50.0);
      await Future.delayed(const Duration(milliseconds: 30));
      processor.onPointerUp(0, 40.0, 50.0);
      processor.onPointerUp(1, 70.0, 50.0);
      processor.onPointerUp(2, 100.0, 50.0);

      final middleClicks = events.whereType<ClickEvent>().where((c) => c.button == MouseButton.middle);
      expect(middleClicks.isNotEmpty, isTrue);

      processor.dispose();
    });

    test('tap-then-hold-drag emits button down, moves, and button up', () async {
      final events = <AirpadEvent>[];
      final processor = TouchpadProcessor(onEvent: events.add);

      // Tap 1
      processor.onPointerDown(0, 50.0, 50.0);
      processor.onPointerUp(0, 50.0, 50.0);

      // Tap 2 down (hold)
      await Future.delayed(const Duration(milliseconds: 30));
      processor.onPointerDown(0, 50.0, 50.0);

      expect(processor.isDragging, isTrue);
      final downEvents = events.whereType<ButtonEvent>().where((b) => b.state == ButtonState.down);
      expect(downEvents.isNotEmpty, isTrue);

      // Drag motion
      processor.onPointerMove(0, 60.0, 70.0, 10.0, 20.0);

      // Lift finger up
      processor.onPointerUp(0, 60.0, 70.0);
      expect(processor.isDragging, isFalse);

      final upEvents = events.whereType<ButtonEvent>().where((b) => b.state == ButtonState.up);
      expect(upEvents.isNotEmpty, isTrue);

      processor.dispose();
    });

    test('reset releases held button if dragging', () {
      final events = <AirpadEvent>[];
      final processor = TouchpadProcessor(onEvent: events.add);

      processor.onPointerDown(0, 50.0, 50.0);
      processor.onPointerUp(0, 50.0, 50.0);
      processor.onPointerDown(0, 50.0, 50.0);
      expect(processor.isDragging, isTrue);

      // Unexpected reset / disconnect
      processor.reset();
      expect(processor.isDragging, isFalse);

      final upEvents = events.whereType<ButtonEvent>().where((b) => b.state == ButtonState.up);
      expect(upEvents.isNotEmpty, isTrue, reason: 'Reset must emit button up to avoid stuck buttons');

      processor.dispose();
    });

    test('three finger swipe left emits Super + Tab', () {
      final events = <AirpadEvent>[];
      SwipeDirection? detectedDir;
      final processor = TouchpadProcessor(
        onEvent: events.add,
        onThreeFingerSwipe: (dir) => detectedDir = dir,
      );

      processor.onPointerDown(0, 100.0, 100.0);
      processor.onPointerDown(1, 130.0, 100.0);
      processor.onPointerDown(2, 160.0, 100.0);

      // Swipe left by 50px
      processor.onPointerMove(0, 50.0, 100.0, -50.0, 0.0);
      processor.onPointerMove(1, 80.0, 100.0, -50.0, 0.0);
      processor.onPointerMove(2, 110.0, 100.0, -50.0, 0.0);

      expect(detectedDir, equals(SwipeDirection.left));
      final keyEvents = events.whereType<KeyEvent>().toList();
      expect(keyEvents.isNotEmpty, isTrue);
      expect(keyEvents.first.code, equals('Tab'));
      expect(keyEvents.first.mods, equals(['super']));

      // Release fingers should NOT trigger middle click
      processor.onPointerUp(0, 50.0, 100.0);
      processor.onPointerUp(1, 80.0, 100.0);
      processor.onPointerUp(2, 110.0, 100.0);

      expect(events.whereType<ClickEvent>().isEmpty, isTrue);

      processor.dispose();
    });

    test('three finger swipe right emits Super + Shift + Tab', () {
      final events = <AirpadEvent>[];
      SwipeDirection? detectedDir;
      final processor = TouchpadProcessor(
        onEvent: events.add,
        onThreeFingerSwipe: (dir) => detectedDir = dir,
      );

      processor.onPointerDown(0, 100.0, 100.0);
      processor.onPointerDown(1, 130.0, 100.0);
      processor.onPointerDown(2, 160.0, 100.0);

      // Swipe right by 50px
      processor.onPointerMove(0, 150.0, 100.0, 50.0, 0.0);
      processor.onPointerMove(1, 180.0, 100.0, 50.0, 0.0);
      processor.onPointerMove(2, 210.0, 100.0, 50.0, 0.0);

      expect(detectedDir, equals(SwipeDirection.right));
      final keyEvents = events.whereType<KeyEvent>().toList();
      expect(keyEvents.isNotEmpty, isTrue);
      expect(keyEvents.first.code, equals('Tab'));
      expect(keyEvents.first.mods, equals(['super', 'shift']));

      processor.dispose();
    });

    test('three finger swipe up and down emit corresponding shortcuts', () {
      final events = <AirpadEvent>[];
      SwipeDirection? detectedDir;
      final processor = TouchpadProcessor(
        onEvent: events.add,
        onThreeFingerSwipe: (dir) => detectedDir = dir,
      );

      // Swipe Up
      processor.onPointerDown(0, 100.0, 100.0);
      processor.onPointerDown(1, 130.0, 100.0);
      processor.onPointerDown(2, 160.0, 100.0);
      processor.onPointerMove(0, 100.0, 50.0, 0.0, -50.0);
      processor.onPointerMove(1, 130.0, 50.0, 0.0, -50.0);
      processor.onPointerMove(2, 160.0, 50.0, 0.0, -50.0);

      expect(detectedDir, equals(SwipeDirection.up));
      expect(events.whereType<KeyEvent>().last.code, equals('Space'));
      expect(events.whereType<KeyEvent>().last.mods, equals(['super']));

      processor.onPointerUp(0, 100.0, 50.0);
      processor.onPointerUp(1, 130.0, 50.0);
      processor.onPointerUp(2, 160.0, 50.0);

      // Swipe Down
      processor.onPointerDown(0, 100.0, 100.0);
      processor.onPointerDown(1, 130.0, 100.0);
      processor.onPointerDown(2, 160.0, 100.0);
      processor.onPointerMove(0, 100.0, 150.0, 0.0, 50.0);
      processor.onPointerMove(1, 130.0, 150.0, 0.0, 50.0);
      processor.onPointerMove(2, 160.0, 150.0, 0.0, 50.0);

      expect(detectedDir, equals(SwipeDirection.down));
      expect(events.whereType<KeyEvent>().last.code, equals('s'));
      expect(events.whereType<KeyEvent>().last.mods, equals(['super']));

      processor.dispose();
    });
  });
}
