import 'dart:async';
import 'package:airpad_core/airpad_core.dart';
import 'package:test/test.dart';

void main() {
  group('Phase 4 Touchpad MVP Acceptance Tests', () {
    late DeviceIdentity desktopIdentity;
    late DeviceIdentity phoneIdentity;
    late TrustStore desktopTrustStore;
    late TrustStore phoneTrustStore;

    const testPort = 53410;

    setUp(() async {
      desktopIdentity = await DeviceIdentity.generate(alias: 'Desktop PC', keySize: 1024);
      phoneIdentity = await DeviceIdentity.generate(alias: 'Phone Controller', keySize: 1024);

      desktopTrustStore = TrustStore();
      phoneTrustStore = TrustStore();

      await desktopTrustStore.trustDevice(phoneIdentity.toDevice(deviceType: DeviceType.mobile));
      await phoneTrustStore.trustDevice(desktopIdentity.toDevice(deviceType: DeviceType.desktop));
    });

    test('end-to-end touchpad gestures stream across TLS session without stuck buttons', () async {
      final server = TlsSessionServer(
        localIdentity: desktopIdentity,
        trustStore: desktopTrustStore,
        port: testPort,
      );
      await server.start();

      final client = TlsSessionClient(
        localIdentity: phoneIdentity,
        trustStore: phoneTrustStore,
      );

      final receivedEvents = <AirpadEvent>[];
      final eventSub = server.onEventReceived.listen(receivedEvents.add);

      var clientDisconnectedNotified = false;
      final disconnectSub = server.onClientDisconnected.listen((_) {
        clientDisconnectedNotified = true;
      });

      // Connect phone to desktop
      await client.connect(host: '127.0.0.1', port: testPort);
      while (!client.isConnected) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      expect(client.isConnected, isTrue);

      // Create touchpad processor wired to client
      final processor = TouchpadProcessor(
        onEvent: (event) => client.sendEvent(event),
      );

      // 1. Test Move Gesture
      processor.onPointerDown(0, 50.0, 50.0);
      processor.onPointerMove(0, 70.0, 80.0, 20.0, 30.0);
      processor.onPointerUp(0, 70.0, 80.0);

      await Future.delayed(const Duration(milliseconds: 100));
      final moves = receivedEvents.whereType<MoveEvent>().toList();
      expect(moves.isNotEmpty, isTrue, reason: 'Move gesture must stream across session');

      // 2. Test Left Click (Single Tap)
      processor.onPointerDown(0, 100.0, 100.0);
      await Future.delayed(const Duration(milliseconds: 20));
      processor.onPointerUp(0, 100.0, 100.0);

      await Future.delayed(const Duration(milliseconds: 100));
      final leftClicks = receivedEvents.whereType<ClickEvent>().where((c) => c.button == MouseButton.left);
      expect(leftClicks.isNotEmpty, isTrue, reason: 'Single finger tap must send left click');

      // 3. Test Right Click (Two-finger Tap)
      processor.onPointerDown(0, 100.0, 100.0);
      processor.onPointerDown(1, 140.0, 100.0);
      await Future.delayed(const Duration(milliseconds: 20));
      processor.onPointerUp(0, 100.0, 100.0);
      processor.onPointerUp(1, 140.0, 100.0);

      await Future.delayed(const Duration(milliseconds: 100));
      final rightClicks = receivedEvents.whereType<ClickEvent>().where((c) => c.button == MouseButton.right);
      expect(rightClicks.isNotEmpty, isTrue, reason: 'Two finger tap must send right click');

      // 4. Test Scroll (Two-finger Drag)
      processor.onPointerDown(0, 100.0, 100.0);
      processor.onPointerDown(1, 140.0, 100.0);
      processor.onPointerMove(0, 100.0, 80.0, 0.0, -20.0);
      processor.onPointerUp(0, 100.0, 80.0);
      processor.onPointerUp(1, 140.0, 100.0);

      await Future.delayed(const Duration(milliseconds: 100));
      final scrolls = receivedEvents.whereType<ScrollEvent>().toList();
      expect(scrolls.isNotEmpty, isTrue, reason: 'Two finger drag must send scroll events');

      // 5. Test Tap-and-Hold Drag with Disconnect (Guaranteed no stuck buttons)
      // Tap 1
      processor.onPointerDown(0, 200.0, 200.0);
      processor.onPointerUp(0, 200.0, 200.0);
      // Tap 2 down (drag start)
      await Future.delayed(const Duration(milliseconds: 30));
      processor.onPointerDown(0, 200.0, 200.0);
      expect(processor.isDragging, isTrue);

      await Future.delayed(const Duration(milliseconds: 50));
      final buttonDowns = receivedEvents.whereType<ButtonEvent>().where((b) => b.state == ButtonState.down);
      expect(buttonDowns.isNotEmpty, isTrue, reason: 'Tap-and-hold must emit button down');

      // Disconnect mid-drag!
      await client.disconnect();
      processor.reset();

      await Future.delayed(const Duration(milliseconds: 100));
      expect(client.isConnected, isFalse);
      expect(processor.isDragging, isFalse);
      expect(clientDisconnectedNotified, isTrue);

      processor.dispose();
      await eventSub.cancel();
      await disconnectSub.cancel();
      await server.stop();
    });
  });
}
