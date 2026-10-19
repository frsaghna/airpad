import 'dart:convert';
import 'dart:io';
import 'package:airpad_core/airpad_core.dart';
import 'package:test/test.dart';

void main() {
  group('Phase 2 Discovery Acceptance Test', () {
    late DeviceIdentity desktopIdentity;
    late DeviceIdentity phoneIdentity;
    late AirpadDevice desktopDevice;
    late AirpadDevice phoneDevice;

    const testPort = 53395;

    setUp(() async {
      desktopIdentity = await DeviceIdentity.generate(
        alias: 'Desktop Receiver',
        keySize: 1024,
      );
      phoneIdentity = await DeviceIdentity.generate(
        alias: 'Mobile Controller',
        keySize: 1024,
      );

      desktopDevice = desktopIdentity.toDevice(
        deviceType: DeviceType.desktop,
        port: testPort,
      );
      phoneDevice = phoneIdentity.toDevice(
        deviceType: DeviceType.mobile,
        port: testPort,
      );
    });

    test('multicast discovery connects phone and desktop within 2s and filters self-discovery', () async {
      final desktopManager = DiscoveryManager(
        localDevice: desktopDevice,
        port: testPort,
      );
      final phoneManager = DiscoveryManager(
        localDevice: phoneDevice,
        port: testPort,
        listenPort: 0,
      );

      try {
        await desktopManager.startAdvertising();
        await phoneManager.startDiscovery();

        // Phone should discover desktop within 2s
        final stopwatch = Stopwatch()..start();
        AirpadDevice? foundDesktop;

        while (stopwatch.elapsed < const Duration(seconds: 2)) {
          final devices = phoneManager.currentDevices;
          final match = devices.where((d) => d.fingerprint == desktopDevice.fingerprint);
          if (match.isNotEmpty) {
            foundDesktop = match.first;
            break;
          }
          await Future.delayed(const Duration(milliseconds: 50));
        }

        expect(foundDesktop, isNotNull, reason: 'Phone must show desktop within 2s');
        expect(foundDesktop!.alias, equals('Desktop Receiver'));

        // Self-discovery must be strictly filtered out
        expect(
          phoneManager.currentDevices.any((d) => d.fingerprint == phoneDevice.fingerprint),
          isFalse,
          reason: 'Phone must never include itself in discovered devices',
        );
        expect(
          desktopManager.currentDevices.any((d) => d.fingerprint == desktopDevice.fingerprint),
          isFalse,
          reason: 'Desktop must never include itself in discovered devices',
        );
      } finally {
        await desktopManager.stop();
        await phoneManager.stop();
      }
    });

    test('HTTP fallback discovers receiver when multicast is unavailable', () async {
      // Simulate environment where multicast is blocked:
      // Desktop only runs HTTP register server on port 53396
      const fallbackPort = 53396;
      final httpServer = HttpRegisterServer(
        localDevice: desktopDevice.copyWith(port: fallbackPort),
        port: fallbackPort,
      );
      await httpServer.start();

      // Phone probes via HTTP register fallback
      final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 500);
      try {
        final uri = Uri.parse('http://127.0.0.1:$fallbackPort/v1/register');
        final request = await client.postUrl(uri);
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(phoneDevice.toJson()));
        final response = await request.close();

        expect(response.statusCode, equals(HttpStatus.ok));
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final discovered = AirpadDevice.fromJson(json).copyWith(ip: '127.0.0.1');

        expect(discovered.fingerprint, equals(desktopDevice.fingerprint));
        expect(discovered.alias, equals('Desktop Receiver'));
      } finally {
        client.close(force: true);
        await httpServer.stop();
      }
    });
  });
}
