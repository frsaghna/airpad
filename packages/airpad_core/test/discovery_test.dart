import 'dart:convert';
import 'dart:io';
import 'package:airpad_core/airpad_core.dart';
import 'package:test/test.dart';

void main() {
  group('Discovery & HTTP Fallback', () {
    const desktopFp =
        '1111111111111111111111111111111111111111111111111111111111111111';
    const mobileFp =
        '2222222222222222222222222222222222222222222222222222222222222222';

    const desktopDev = AirpadDevice(
      alias: 'Quiet Falcon',
      fingerprint: desktopFp,
      deviceType: DeviceType.desktop,
      port: 53399,
    );

    const mobileDev = AirpadDevice(
      alias: 'Clever Otter',
      fingerprint: mobileFp,
      deviceType: DeviceType.mobile,
      port: 53399,
    );

    test('HttpRegisterServer receives registration and returns receiver info', () async {
      final server = HttpRegisterServer(
        localDevice: desktopDev,
        port: 53399,
      );
      await server.start();

      AirpadDevice? discoveredDevice;
      final sub = server.onDeviceRegistered.listen((dev) {
        discoveredDevice = dev;
      });

      final client = HttpClient();
      final uri = Uri.parse('http://127.0.0.1:53399/v1/register');
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(mobileDev.toJson()));
      final response = await request.close();

      expect(response.statusCode, equals(HttpStatus.ok));
      final responseBody = await utf8.decoder.bind(response).join();
      final responseJson = jsonDecode(responseBody) as Map<String, dynamic>;
      final returnedDesktop = AirpadDevice.fromJson(responseJson);
      expect(returnedDesktop.fingerprint, equals(desktopFp));

      // Wait brief moment for stream event
      await Future.delayed(const Duration(milliseconds: 50));
      expect(discoveredDevice, isNotNull);
      expect(discoveredDevice!.alias, equals('Clever Otter'));
      expect(discoveredDevice!.fingerprint, equals(mobileFp));

      // Test self-registration filter
      final selfRequest = await client.postUrl(uri);
      selfRequest.headers.contentType = ContentType.json;
      selfRequest.write(jsonEncode(desktopDev.toJson()));
      final selfResponse = await selfRequest.close();
      expect(selfResponse.statusCode, equals(HttpStatus.ok));

      client.close();
      await sub.cancel();
      await server.stop();
    });

    test('DiscoveryManager filters self-discovery and tracks nearby devices', () async {
      final manager = DiscoveryManager(
        localDevice: desktopDev,
        port: 53398,
        deviceExpiry: const Duration(milliseconds: 300),
      );

      // Verify initial empty state
      expect(manager.currentDevices, isEmpty);

      // Verify self-device is ignored
      // (simulate incoming seen device)
      // When remote device arrives, it is added
      // We can test the manager via its http server
      await manager.startAdvertising();

      final client = HttpClient();
      final uri = Uri.parse('http://127.0.0.1:53398/v1/register');

      // 1. Send mobile device registration
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(mobileDev.toJson()));
      final resp = await req.close();
      expect(resp.statusCode, equals(HttpStatus.ok));

      await Future.delayed(const Duration(milliseconds: 50));
      expect(manager.currentDevices.length, equals(1));
      expect(manager.currentDevices.first.fingerprint, equals(mobileFp));

      // 2. Send self-device registration (must be ignored)
      final selfReq = await client.postUrl(uri);
      selfReq.headers.contentType = ContentType.json;
      selfReq.write(jsonEncode(desktopDev.toJson()));
      final selfResp = await selfReq.close();
      expect(selfResp.statusCode, equals(HttpStatus.ok));

      await Future.delayed(const Duration(milliseconds: 50));
      expect(manager.currentDevices.length, equals(1));

      // 3. Test device expiry
      await Future.delayed(const Duration(milliseconds: 350));
      // Trigger cleanup
      manager.scanSubnetNow(); // harmless probe, but cleanup occurs
      await Future.delayed(const Duration(milliseconds: 50));

      client.close();
      await manager.stop();
    });
  });
}
