import 'dart:async';
import 'package:airpad_core/airpad_core.dart';
import 'package:test/test.dart';

void main() {
  group('Phase 3 TLS Session & Pairing Integration Acceptance Tests', () {
    late DeviceIdentity desktopIdentity;
    late DeviceIdentity phone1Identity;
    late DeviceIdentity phone2Identity;
    late TrustStore desktopTrustStore;
    late TrustStore phone1TrustStore;
    late TrustStore phone2TrustStore;

    const serverPort = 53401;

    setUp(() async {
      desktopIdentity = await DeviceIdentity.generate(alias: 'Desktop PC', keySize: 1024);
      phone1Identity = await DeviceIdentity.generate(alias: 'Phone One', keySize: 1024);
      phone2Identity = await DeviceIdentity.generate(alias: 'Rogue Phone', keySize: 1024);

      desktopTrustStore = TrustStore();
      phone1TrustStore = TrustStore();
      phone2TrustStore = TrustStore();
    });

    test('unpaired device connects -> rejected on desktop -> disconnected', () async {
      final server = TlsSessionServer(
        localIdentity: desktopIdentity,
        trustStore: desktopTrustStore,
        port: serverPort,
      );
      await server.start();

      final client = TlsSessionClient(
        localIdentity: phone1Identity,
        trustStore: phone1TrustStore,
      );

      // Desktop auto-rejects incoming prompt
      final sub = server.onPairingPrompt.listen((prompt) {
        expect(prompt.code.length, equals(6));
        prompt.reject();
      });

      try {
        await client.connect(host: '127.0.0.1', port: serverPort);

        // Wait for state change to rejected
        while (client.state is! SessionRejected && client.state is! SessionDisconnected) {
          await Future.delayed(const Duration(milliseconds: 50));
        }

        expect(client.isConnected, isFalse);
        expect(desktopTrustStore.isTrusted(phone1Identity.fingerprint), isFalse);
      } finally {
        await sub.cancel();
        client.dispose();
        await server.stop();
      }
    });

    test('unpaired device pairs -> accepted on desktop -> connects and sends input', () async {
      const port = serverPort + 1;
      final server = TlsSessionServer(
        localIdentity: desktopIdentity,
        trustStore: desktopTrustStore,
        port: port,
      );
      await server.start();

      final client = TlsSessionClient(
        localIdentity: phone1Identity,
        trustStore: phone1TrustStore,
      );

      String? promptCode;
      final promptSub = server.onPairingPrompt.listen((prompt) {
        promptCode = prompt.code;
        prompt.accept();
      });

      AirpadEvent? receivedEvent;
      final eventSub = server.onEventReceived.listen((e) {
        receivedEvent = e;
      });

      try {
        await client.connect(host: '127.0.0.1', port: port);

        // Wait until connected
        while (!client.isConnected) {
          await Future.delayed(const Duration(milliseconds: 50));
        }

        expect(promptCode, isNotNull);
        expect(client.isConnected, isTrue);
        expect(desktopTrustStore.isTrusted(phone1Identity.fingerprint), isTrue);
        expect(phone1TrustStore.isTrusted(desktopIdentity.fingerprint), isTrue);

        // Test sending an event
        client.sendEvent(const MoveEvent(dx: 12.0, dy: -8.0));
        await Future.delayed(const Duration(milliseconds: 100));

        expect(receivedEvent, isNotNull);
        expect(receivedEvent, isA<MoveEvent>());
        final move = receivedEvent as MoveEvent;
        expect(move.dx, equals(12.0));
        expect(move.dy, equals(-8.0));
      } finally {
        await promptSub.cancel();
        await eventSub.cancel();
        client.dispose();
        await server.stop();
      }
    });

    test('paired device reconnects automatically without prompt', () async {
      const port = serverPort + 2;
      // Pre-trust phone1
      await desktopTrustStore.trustDevice(phone1Identity.toDevice(deviceType: DeviceType.mobile));
      await phone1TrustStore.trustDevice(desktopIdentity.toDevice(deviceType: DeviceType.desktop));

      final server = TlsSessionServer(
        localIdentity: desktopIdentity,
        trustStore: desktopTrustStore,
        port: port,
      );
      await server.start();

      final client = TlsSessionClient(
        localIdentity: phone1Identity,
        trustStore: phone1TrustStore,
      );

      var promptTriggered = false;
      final promptSub = server.onPairingPrompt.listen((_) {
        promptTriggered = true;
      });

      try {
        await client.connect(
          host: '127.0.0.1',
          port: port,
          expectedFingerprint: desktopIdentity.fingerprint,
        );

        while (!client.isConnected) {
          await Future.delayed(const Duration(milliseconds: 50));
        }

        expect(client.isConnected, isTrue);
        expect(promptTriggered, isFalse, reason: 'Paired device must reconnect automatically without prompt');
      } finally {
        await promptSub.cancel();
        client.dispose();
        await server.stop();
      }
    });

    test('revoking device disconnects immediately and removes trust', () async {
      const port = serverPort + 3;
      await desktopTrustStore.trustDevice(phone1Identity.toDevice(deviceType: DeviceType.mobile));

      final server = TlsSessionServer(
        localIdentity: desktopIdentity,
        trustStore: desktopTrustStore,
        port: port,
      );
      await server.start();

      final client = TlsSessionClient(
        localIdentity: phone1Identity,
        trustStore: phone1TrustStore,
      );

      try {
        await client.connect(host: '127.0.0.1', port: port);
        while (!client.isConnected) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
        expect(client.isConnected, isTrue);

        // Desktop revokes phone1
        await server.revokeDevice(phone1Identity.fingerprint);

        // Client must disconnect immediately
        await Future.delayed(const Duration(milliseconds: 100));
        expect(client.isConnected, isFalse);
        expect(desktopTrustStore.isTrusted(phone1Identity.fingerprint), isFalse);
      } finally {
        client.dispose();
        await server.stop();
      }
    });

    test('rogue device cannot hijack trusted slot of another phone', () async {
      const port = serverPort + 4;
      // Trust phone1
      await desktopTrustStore.trustDevice(phone1Identity.toDevice(deviceType: DeviceType.mobile));

      final server = TlsSessionServer(
        localIdentity: desktopIdentity,
        trustStore: desktopTrustStore,
        port: port,
      );
      await server.start();

      // Rogue phone connects claiming to be phone1 alias, but has its own fingerprint
      final rogueClient = TlsSessionClient(
        localIdentity: phone2Identity,
        trustStore: phone2TrustStore,
      );

      var promptForRogue = false;
      final promptSub = server.onPairingPrompt.listen((prompt) {
        promptForRogue = true;
        expect(prompt.device.fingerprint, equals(phone2Identity.fingerprint));
        prompt.reject();
      });

      try {
        await rogueClient.connect(host: '127.0.0.1', port: port);
        await Future.delayed(const Duration(milliseconds: 200));

        expect(promptForRogue, isTrue, reason: 'Rogue device with different fingerprint must NOT auto-connect');
        expect(rogueClient.isConnected, isFalse);
      } finally {
        await promptSub.cancel();
        rogueClient.dispose();
        await server.stop();
      }
    });

    test('QR code pairing auto-connects and trusts out-of-band', () async {
      const port = serverPort + 5;
      final server = TlsSessionServer(
        localIdentity: desktopIdentity,
        trustStore: desktopTrustStore,
        port: port,
      );
      await server.start();

      final qrCode = server.createQrPairingCode();

      final client = TlsSessionClient(
        localIdentity: phone1Identity,
        trustStore: phone1TrustStore,
      );

      var promptShown = false;
      final promptSub = server.onPairingPrompt.listen((_) => promptShown = true);

      try {
        await client.connect(
          host: '127.0.0.1',
          port: port,
          expectedFingerprint: desktopIdentity.fingerprint,
          qrCode: qrCode,
        );

        while (!client.isConnected) {
          await Future.delayed(const Duration(milliseconds: 50));
        }

        expect(client.isConnected, isTrue);
        expect(promptShown, isFalse, reason: 'QR pairing skips manual code confirmation');
        expect(desktopTrustStore.isTrusted(phone1Identity.fingerprint), isTrue);
      } finally {
        await promptSub.cancel();
        client.dispose();
        await server.stop();
      }
    });
  });
}
