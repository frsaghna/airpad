import 'package:airpad_core/airpad_core.dart';
import 'package:test/test.dart';

void main() {
  group('AirpadEvent', () {
    test('MoveEvent serialization and bounds clamping', () {
      const event = MoveEvent(dx: 15.5, dy: -20.2);
      final json = event.toJson();
      expect(json['type'], equals('move'));
      expect(json['dx'], equals(15.5));
      expect(json['dy'], equals(-20.2));

      final restored = AirpadEvent.fromJson(json) as MoveEvent;
      expect(restored.dx, equals(15.5));
      expect(restored.dy, equals(-20.2));

      // Test bounds clamping
      final extreme = AirpadEvent.fromJson({'type': 'move', 'dx': 99999.0, 'dy': -88888.0}) as MoveEvent;
      expect(extreme.dx, equals(1000.0));
      expect(extreme.dy, equals(-1000.0));
    });

    test('ScrollEvent serialization and bounds clamping', () {
      const event = ScrollEvent(dx: 0.0, dy: 10.0);
      final json = event.toJson();
      expect(json['type'], equals('scroll'));

      final restored = AirpadEvent.fromJson(json) as ScrollEvent;
      expect(restored.dx, equals(0.0));
      expect(restored.dy, equals(10.0));

      final extreme = AirpadEvent.fromJson({'type': 'scroll', 'dx': -5000.0, 'dy': 5000.0}) as ScrollEvent;
      expect(extreme.dx, equals(-1000.0));
      expect(extreme.dy, equals(1000.0));
    });

    test('ButtonEvent down and up states', () {
      const down = ButtonEvent(button: MouseButton.left, state: ButtonState.down);
      expect(down.toJson(), equals({'type': 'button', 'button': 'left', 'state': 'down'}));

      final restored = AirpadEvent.fromJson(down.toJson()) as ButtonEvent;
      expect(restored.button, equals(MouseButton.left));
      expect(restored.state, equals(ButtonState.down));

      const rightUp = ButtonEvent(button: MouseButton.right, state: ButtonState.up);
      final restoredRight = AirpadEvent.fromJson(rightUp.toJson()) as ButtonEvent;
      expect(restoredRight.button, equals(MouseButton.right));
      expect(restoredRight.state, equals(ButtonState.up));
    });

    test('ClickEvent count clamping', () {
      const click = ClickEvent(button: MouseButton.middle, count: 2);
      expect(click.toJson(), equals({'type': 'click', 'button': 'middle', 'count': 2}));

      final restored = AirpadEvent.fromJson(click.toJson()) as ClickEvent;
      expect(restored.button, equals(MouseButton.middle));
      expect(restored.count, equals(2));

      final overClick = AirpadEvent.fromJson({'type': 'click', 'button': 'left', 'count': 99}) as ClickEvent;
      expect(overClick.count, equals(5));
    });

    test('KeyEvent with modifiers', () {
      const key = KeyEvent(code: 'KeyA', state: KeyState.down, mods: ['ctrl', 'shift']);
      final json = key.toJson();
      expect(json['code'], equals('KeyA'));
      expect(json['mods'], equals(['ctrl', 'shift']));

      final restored = AirpadEvent.fromJson(json) as KeyEvent;
      expect(restored.code, equals('KeyA'));
      expect(restored.state, equals(KeyState.down));
      expect(restored.mods, equals(['ctrl', 'shift']));
    });

    test('TextEvent length bounding', () {
      const text = TextEvent(value: 'Hello World 🚀');
      final json = text.toJson();
      expect(json['value'], equals('Hello World 🚀'));

      final restored = AirpadEvent.fromJson(json) as TextEvent;
      expect(restored.value, equals('Hello World 🚀'));

      final hugeStr = 'A' * 5000;
      final bounded = AirpadEvent.fromJson({'type': 'text', 'value': hugeStr}) as TextEvent;
      expect(bounded.value.length, equals(4096));
    });

    test('MediaEvent actions', () {
      const media = MediaEvent(action: MediaAction.volumeUp);
      final json = media.toJson();
      expect(json['action'], equals('volume_up'));

      final restored = AirpadEvent.fromJson(json) as MediaEvent;
      expect(restored.action, equals(MediaAction.volumeUp));
    });

    test('SettingsEvent options', () {
      const settings = SettingsEvent(sensitivity: 1.5, naturalScroll: true);
      final json = settings.toJson();
      expect(json['sensitivity'], equals(1.5));
      expect(json['naturalScroll'], isTrue);

      final restored = AirpadEvent.fromJson(json) as SettingsEvent;
      expect(restored.sensitivity, equals(1.5));
      expect(restored.naturalScroll, isTrue);
    });

    test('fromJsonString and toJsonString roundtrip', () {
      const event = MoveEvent(dx: 1.2, dy: 3.4);
      final str = event.toJsonString();
      final decoded = AirpadEvent.fromJsonString(str) as MoveEvent;
      expect(decoded.dx, equals(1.2));
      expect(decoded.dy, equals(3.4));
    });

    test('throws on invalid or unknown event type', () {
      expect(() => AirpadEvent.fromJson({'type': 'unknown_type'}), throwsFormatException);
      expect(() => AirpadEvent.fromJson({}), throwsFormatException);
    });
  });
}
