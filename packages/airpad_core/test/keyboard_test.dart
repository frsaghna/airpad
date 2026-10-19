import 'dart:async';
import 'package:airpad_core/airpad_core.dart';
import 'package:test/test.dart';

void main() {
  group('KeyboardState & Phase 5 Keyboard Acceptance Tests', () {
    test('toggles and clears sticky modifiers properly', () {
      final emitted = <AirpadEvent>[];
      final keyboard = KeyboardState(onEvent: emitted.add);

      expect(keyboard.isCtrlActive, isFalse);

      // Toggle Ctrl ON
      keyboard.toggleModifier('ctrl');
      expect(keyboard.isCtrlActive, isTrue);
      expect(keyboard.activeModifiers, contains('ctrl'));
      expect(emitted.last, isA<KeyEvent>());
      final ctrlDown = emitted.last as KeyEvent;
      expect(ctrlDown.code, equals('ControlLeft'));
      expect(ctrlDown.state, equals(KeyState.down));

      // Toggle Ctrl OFF
      keyboard.toggleModifier('ctrl');
      expect(keyboard.isCtrlActive, isFalse);
      expect(emitted.last, isA<KeyEvent>());
      final ctrlUp = emitted.last as KeyEvent;
      expect(ctrlUp.code, equals('ControlLeft'));
      expect(ctrlUp.state, equals(KeyState.up));

      // Toggle Alt and Shift, then clear
      keyboard.toggleModifier('alt');
      keyboard.toggleModifier('shift');
      expect(keyboard.activeModifiers.length, equals(2));

      keyboard.clearModifiers();
      expect(keyboard.activeModifiers, isEmpty);

      keyboard.dispose();
    });

    test('sendShortcut emits down and up events for Ctrl+C, Ctrl+V, and Alt+Tab', () {
      final emitted = <AirpadEvent>[];
      final keyboard = KeyboardState(onEvent: emitted.add);

      // 1. Test Ctrl+C
      keyboard.sendShortcut('KeyC', mods: ['ctrl']);
      final keyEvents = emitted.whereType<KeyEvent>().toList();
      expect(keyEvents.any((k) => k.code == 'ControlLeft' && k.state == KeyState.down), isTrue);
      expect(keyEvents.any((k) => k.code == 'KeyC' && k.state == KeyState.down), isTrue);
      expect(keyEvents.any((k) => k.code == 'KeyC' && k.state == KeyState.up), isTrue);
      expect(keyEvents.any((k) => k.code == 'ControlLeft' && k.state == KeyState.up), isTrue);

      emitted.clear();

      // 2. Test Ctrl+V
      keyboard.sendShortcut('KeyV', mods: ['ctrl']);
      final vEvents = emitted.whereType<KeyEvent>().toList();
      expect(vEvents.any((k) => k.code == 'ControlLeft' && k.state == KeyState.down), isTrue);
      expect(vEvents.any((k) => k.code == 'KeyV' && k.state == KeyState.down), isTrue);
      expect(vEvents.any((k) => k.code == 'KeyV' && k.state == KeyState.up), isTrue);
      expect(vEvents.any((k) => k.code == 'ControlLeft' && k.state == KeyState.up), isTrue);

      emitted.clear();

      // 3. Test Alt+Tab
      keyboard.sendShortcut('Tab', mods: ['alt']);
      final tabEvents = emitted.whereType<KeyEvent>().toList();
      expect(tabEvents.any((k) => k.code == 'AltLeft' && k.state == KeyState.down), isTrue);
      expect(tabEvents.any((k) => k.code == 'Tab' && k.state == KeyState.down), isTrue);
      expect(tabEvents.any((k) => k.code == 'Tab' && k.state == KeyState.up), isTrue);
      expect(tabEvents.any((k) => k.code == 'AltLeft' && k.state == KeyState.up), isTrue);

      keyboard.dispose();
    });

    test('sendText and sendMedia emit respective protocol events', () {
      final emitted = <AirpadEvent>[];
      final keyboard = KeyboardState(onEvent: emitted.add);

      keyboard.sendText('The quick brown fox jumps over the lazy dog.');
      expect(emitted.last, isA<TextEvent>());
      expect((emitted.last as TextEvent).value, equals('The quick brown fox jumps over the lazy dog.'));

      keyboard.sendMedia(MediaAction.volumeUp);
      expect(emitted.last, isA<MediaEvent>());
      expect((emitted.last as MediaEvent).action, equals(MediaAction.volumeUp));

      keyboard.dispose();
    });

    test('Phase 5 acceptance: streams sentence, shortcuts, and non-ASCII text across TLS session', () async {
      final desktopIdentity = await DeviceIdentity.generate(alias: 'Desktop PC', keySize: 1024);
      final phoneIdentity = await DeviceIdentity.generate(alias: 'Phone Controller', keySize: 1024);

      final desktopTrust = TrustStore();
      final phoneTrust = TrustStore();
      await desktopTrust.trustDevice(phoneIdentity.toDevice(deviceType: DeviceType.mobile));
      await phoneTrust.trustDevice(desktopIdentity.toDevice(deviceType: DeviceType.desktop));

      const port = 53420;
      final server = TlsSessionServer(
        localIdentity: desktopIdentity,
        trustStore: desktopTrust,
        port: port,
      );
      await server.start();

      final client = TlsSessionClient(
        localIdentity: phoneIdentity,
        trustStore: phoneTrust,
      );

      final receivedEvents = <AirpadEvent>[];
      final sub = server.onEventReceived.listen(receivedEvents.add);

      await client.connect(host: '127.0.0.1', port: port);
      while (!client.isConnected) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      expect(client.isConnected, isTrue);

      final keyboard = KeyboardState(onEvent: client.sendEvent);

      // 1. Type a sentence
      keyboard.sendText('Typing a full sentence with Airpad keyboard.');

      // 2. Send shortcuts: Ctrl+C, Ctrl+V, Alt+Tab
      keyboard.sendShortcut('KeyC', mods: ['ctrl']);
      keyboard.sendShortcut('KeyV', mods: ['ctrl']);
      keyboard.sendShortcut('Tab', mods: ['alt']);

      // 3. Send non-ASCII string
      keyboard.sendText('Unicode test: Café, résumé, and 🚀 rocket emoji!');

      await Future.delayed(const Duration(milliseconds: 150));

      final textEvents = receivedEvents.whereType<TextEvent>().toList();
      expect(textEvents.length, equals(2));
      expect(textEvents[0].value, equals('Typing a full sentence with Airpad keyboard.'));
      expect(textEvents[1].value, equals('Unicode test: Café, résumé, and 🚀 rocket emoji!'));

      final keyEvents = receivedEvents.whereType<KeyEvent>().toList();
      expect(keyEvents.any((k) => k.code == 'KeyC'), isTrue);
      expect(keyEvents.any((k) => k.code == 'KeyV'), isTrue);
      expect(keyEvents.any((k) => k.code == 'Tab'), isTrue);

      await sub.cancel();
      keyboard.dispose();
      client.dispose();
      await server.stop();
    });
  });
}
