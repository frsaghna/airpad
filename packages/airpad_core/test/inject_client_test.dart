import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:airpad_core/airpad_core.dart';
import 'package:test/test.dart';

void main() {
  group('AirpadInjectClient', () {
    test('returns false when socket does not exist', () async {
      final client = AirpadInjectClient(customSocketPath: '/tmp/non_existent_airpad.sock');
      final ok = await client.connect();
      expect(ok, isFalse);
      expect(client.isConnected, isFalse);
    });

    test('connects to Unix socket server and sends newline-delimited JSON events', () async {
      final tempDir = await Directory.systemTemp.createTemp('airpad_ipc_test_');
      final socketPath = '${tempDir.path}/test_inject.sock';

      final server = await ServerSocket.bind(
        InternetAddress(socketPath, type: InternetAddressType.unix),
        0,
      );

      final receivedLines = <String>[];
      final completer = Completer<void>();

      server.listen((clientSocket) {
        clientSocket
            .cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
          receivedLines.add(line);
          if (receivedLines.length >= 2 && !completer.isCompleted) {
            completer.complete();
          }
        });
      });

      final client = AirpadInjectClient(customSocketPath: socketPath);
      final connected = await client.connect();
      expect(connected, isTrue);
      expect(client.isConnected, isTrue);

      await client.sendEvent(const MoveEvent(dx: 5.0, dy: -3.0));
      await client.sendEvent(const ButtonEvent(button: MouseButton.left, state: ButtonState.down));

      await completer.future.timeout(const Duration(seconds: 2));

      expect(receivedLines.length, equals(2));
      final ev1 = AirpadEvent.fromJsonString(receivedLines[0]);
      expect(ev1, isA<MoveEvent>());
      expect((ev1 as MoveEvent).dx, equals(5.0));

      final ev2 = AirpadEvent.fromJsonString(receivedLines[1]);
      expect(ev2, isA<ButtonEvent>());
      expect((ev2 as ButtonEvent).state, equals(ButtonState.down));

      await client.disconnect();
      await server.close();
      await tempDir.delete(recursive: true);
    });
  });
}
