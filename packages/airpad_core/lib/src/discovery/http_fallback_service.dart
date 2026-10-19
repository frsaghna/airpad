import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/device.dart';

/// HTTP Server running on the receiver to handle HTTP fallback registration.
class HttpRegisterServer {
  HttpRegisterServer({
    required this.localDevice,
    this.port = AirpadProtocolDefaults.port,
  });

  final AirpadDevice localDevice;
  final int port;

  HttpServer? _server;
  final _registeredController = StreamController<AirpadDevice>.broadcast();

  /// Stream of remote devices that registered via HTTP POST.
  Stream<AirpadDevice> get onDeviceRegistered => _registeredController.stream;

  bool get isRunning => _server != null;

  /// Starts the HTTP server on [port].
  Future<void> start() async {
    if (_server != null) return;

    _server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
    _server!.listen(_handleRequest);
  }

  void _handleRequest(HttpRequest request) async {
    final path = request.uri.path;

    if (path == '/v1/register' && request.method == 'POST') {
      try {
        final content = await utf8.decoder.bind(request).join();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final remoteDevice = AirpadDevice.fromJson(json).copyWith(
          ip: request.connectionInfo?.remoteAddress.address,
        );

        if (remoteDevice.fingerprint != localDevice.fingerprint &&
            remoteDevice.isValid()) {
          _registeredController.add(remoteDevice);
        }

        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(localDevice.toJson()));
      } catch (e) {
        request.response.statusCode = HttpStatus.badRequest;
      } finally {
        await request.response.close();
      }
    } else if (path == '/v1/register' || path == '/v1/info') {
      // Allow GET for quick health/discovery probe
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(localDevice.toJson()));
      await request.response.close();
    } else {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    }
  }

  /// Stops the HTTP server.
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  void dispose() {
    stop();
    _registeredController.close();
  }
}

/// Fallback subnet scanner that searches the local LAN subnet via HTTP
/// when multicast packets are blocked.
class SubnetScanner {
  SubnetScanner({
    required this.localDevice,
    this.port = AirpadProtocolDefaults.port,
    this.timeout = const Duration(milliseconds: 600),
  });

  final AirpadDevice localDevice;
  final int port;
  final Duration timeout;

  /// Scans the local network subnet(s) and returns discovered desktop receivers.
  Future<List<AirpadDevice>> scanSubnet() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );

    final discovered = <String, AirpadDevice>{};
    final client = HttpClient()..connectionTimeout = timeout;

    final ipsToScan = <String>[];

    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        final parts = addr.address.split('.');
        if (parts.length == 4) {
          final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
          for (int i = 1; i <= 254; i++) {
            final targetIp = '$prefix.$i';
            if (targetIp != addr.address) {
              ipsToScan.add(targetIp);
            }
          }
        }
      }
    }

    // Scan in concurrent batches of 32 to avoid exhausting socket file descriptors
    const batchSize = 32;
    for (int i = 0; i < ipsToScan.length; i += batchSize) {
      final batch = ipsToScan.sublist(
        i,
        (i + batchSize > ipsToScan.length) ? ipsToScan.length : i + batchSize,
      );

      final results = await Future.wait(
        batch.map((ip) => _probeHost(client, ip)),
      );

      for (final dev in results) {
        if (dev != null && dev.fingerprint != localDevice.fingerprint) {
          discovered[dev.fingerprint] = dev;
        }
      }
    }

    client.close(force: true);
    return discovered.values.toList();
  }

  Future<AirpadDevice?> _probeHost(HttpClient client, String hostIp) async {
    try {
      final uri = Uri.parse('http://$hostIp:$port/v1/register');
      final request = await client.postUrl(uri).timeout(timeout);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(localDevice.toJson()));
      final response = await request.close().timeout(timeout);

      if (response.statusCode == HttpStatus.ok) {
        final body = await utf8.decoder.bind(response).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final device = AirpadDevice.fromJson(json).copyWith(ip: hostIp);
        if (device.isValid()) {
          return device;
        }
      }
    } catch (_) {
      // Expected for inactive hosts on the subnet
    }
    return null;
  }
}
