import 'dart:io';
import 'package:airpad_core/airpad_core.dart';
import 'package:airpad_ui/airpad_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/screens/controller_screen.dart';
import 'package:mobile/src/screens/discover_screen.dart';
import 'package:mobile/src/screens/pairing_screen.dart';
import 'package:mobile/src/screens/settings_screen.dart';
import 'package:mobile/src/services/mobile_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MobileServices services;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('airpad_mobile_test_');
    final id = await DeviceIdentity.generate(alias: 'Test Phone');
    final trustFile = File('${tempDir.path}/trusted.json');
    final trustStore = TrustStore(storageFile: trustFile);

    final localDevice = AirpadDevice(
      alias: id.alias,
      fingerprint: id.fingerprint,
      deviceType: DeviceType.mobile,
      ip: '127.0.0.1',
    );

    final touchProcessor = TouchpadProcessor(
      sensitivity: 1.0,
      naturalScroll: true,
    );

    final keyState = KeyboardState();

    final client = TlsSessionClient(
      localIdentity: id,
      trustStore: trustStore,
    );

    final disc = DiscoveryManager(localDevice: localDevice);

    services = MobileServices.forTesting(
      identity: id,
      trustStore: trustStore,
      discoveryManager: disc,
      sessionClient: client,
      touchpadProcessor: touchProcessor,
      keyboardState: keyState,
    );
  });

  tearDown(() async {
    services.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('DiscoverScreen renders title, scanning badge, and bottom buttons', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AirTheme.darkTheme,
        home: DiscoverScreen(services: services),
      ),
    );

    expect(find.text('AIRPAD'), findsOneWidget);
    expect(find.text('SCANNING'), findsOneWidget);
    expect(find.text('SCAN QR'), findsOneWidget);
    expect(find.text('ENTER IP'), findsOneWidget);
  });

  testWidgets('PairingScreen renders 6-digit code, target alias, and waiting badge', (tester) async {
    var connectedCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AirTheme.darkTheme,
        home: PairingScreen(
          services: services,
          code: '849201',
          desktopAlias: 'Cozy Desktop',
          desktopFingerprint: 'abcd1234efgh5678',
          onConnected: () => connectedCalled = true,
        ),
      ),
    );

    expect(find.text('PAIRING REQUEST'), findsOneWidget);
    expect(find.text('COZY DESKTOP'), findsOneWidget);
    expect(find.text('849 201'), findsOneWidget);
    expect(find.text('WAITING FOR DESKTOP...'), findsOneWidget);
    expect(connectedCalled, isFalse);
  });

  testWidgets('ControllerScreen renders touchpad surface and mouse buttons', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AirTheme.darkTheme,
        home: ControllerScreen(services: services),
      ),
    );

    expect(find.text('TOUCHPAD'), findsOneWidget);
    expect(find.text('SHORTCUTS'), findsOneWidget);
    expect(find.text('MEDIA'), findsOneWidget);
    expect(find.text('LEFT CLICK'), findsOneWidget);
    expect(find.text('RIGHT CLICK'), findsOneWidget);
    expect(find.text('CTRL'), findsOneWidget);
    expect(find.text('ALT'), findsOneWidget);
    expect(find.text('SHIFT'), findsOneWidget);
    expect(find.text('SUPER'), findsOneWidget);
  });

  testWidgets('ControllerScreen switches between TOUCHPAD, SHORTCUTS, and MEDIA', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AirTheme.darkTheme,
        home: ControllerScreen(services: services),
      ),
    );

    // Switch to SHORTCUTS
    await tester.tap(find.text('SHORTCUTS'));
    await tester.pumpAndSettle();

    expect(find.text('COMMON SHORTCUTS'), findsOneWidget);
    expect(find.text('Ctrl+C'), findsOneWidget);
    expect(find.text('Ctrl+V'), findsOneWidget);
    expect(find.text('F1'), findsOneWidget);

    // Switch to MEDIA
    await tester.tap(find.text('MEDIA'));
    await tester.pumpAndSettle();

    expect(find.text('MEDIA & AUDIO CONTROLS'), findsOneWidget);
    expect(find.text('> / || PLAY'), findsOneWidget);
    expect(find.text('MUTE'), findsOneWidget);
  });

  testWidgets('SettingsScreen renders sensitivity slider and toggles', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AirTheme.darkTheme,
        home: SettingsScreen(services: services),
      ),
    );

    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('DEVICE IDENTITY'), findsOneWidget);
    expect(find.text('TOUCHPAD & GESTURES'), findsOneWidget);
    expect(find.text('Sensitivity'), findsOneWidget);
    expect(find.text('Natural Scrolling'), findsOneWidget);
    expect(find.text('Haptic Feedback'), findsOneWidget);
    expect(find.text('Keep Screen Awake'), findsOneWidget);
    expect(find.text('TRUSTED RECEIVERS', skipOffstage: false), findsOneWidget);
  });
}
