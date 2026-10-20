import 'dart:convert';
import 'dart:io';
import 'package:airpad_core/airpad_core.dart';
import 'package:airpad_ui/airpad_ui.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AirpadDesktopApp());
}

class AirpadDesktopApp extends StatefulWidget {
  const AirpadDesktopApp({super.key});

  @override
  State<AirpadDesktopApp> createState() => _AirpadDesktopAppState();
}

class _AirpadDesktopAppState extends State<AirpadDesktopApp> {
  bool _isDark = true;

  void _toggleTheme() {
    setState(() => _isDark = !_isDark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AIRPAD Receiver',
      debugShowCheckedModeBanner: false,
      theme: _isDark ? AirTheme.darkTheme : AirTheme.lightTheme,
      home: AirpadDesktopHome(
        onToggleTheme: _toggleTheme,
        isDark: _isDark,
      ),
    );
  }
}

class AirpadDesktopHome extends StatefulWidget {
  const AirpadDesktopHome({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  final VoidCallback onToggleTheme;
  final bool isDark;

  @override
  State<AirpadDesktopHome> createState() => _AirpadDesktopHomeState();
}

class _AirpadDesktopHomeState extends State<AirpadDesktopHome> {
  DeviceIdentity? _identity;
  TrustStore? _trustStore;
  TlsSessionServer? _sessionServer;
  DiscoveryManager? _discoveryManager;
  AirpadInjectClient? _injectClient;

  AirpadDevice? _activeController;
  bool _isAdvertising = false;
  bool _askEveryTime = false;
  bool _autoStart = false;
  String _localIp = '127.0.0.1';
  bool _injectConnected = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final home = Platform.environment['HOME'] ?? '';
    final configDir = Directory('$home/.config/airpad');
    if (!await configDir.exists()) {
      await configDir.create(recursive: true);
    }

    // 1. Load or generate DeviceIdentity
    final idFile = File('${configDir.path}/identity.json');
    DeviceIdentity id;
    if (await idFile.exists()) {
      try {
        final content = await idFile.readAsString();
        id = DeviceIdentity.fromJson(jsonDecode(content) as Map<String, dynamic>);
      } catch (_) {
        id = await DeviceIdentity.generate();
        await idFile.writeAsString(jsonEncode(id.toJson()), flush: true);
      }
    } else {
      id = await DeviceIdentity.generate();
      await idFile.writeAsString(jsonEncode(id.toJson()), flush: true);
    }

    // 2. Trust store
    final trustFile = File('${configDir.path}/trusted.json');
    final trust = TrustStore(storageFile: trustFile);
    await trust.load();

    // 3. Determine primary IP address
    final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
    if (ifaces.isNotEmpty && ifaces.first.addresses.isNotEmpty) {
      _localIp = ifaces.first.addresses.first.address;
    }

    final localDevice = id.toDevice(
      deviceType: DeviceType.desktop,
      port: AirpadProtocolDefaults.port,
      ip: _localIp,
    );

    // 4. Inject client to helper daemon
    final inject = AirpadInjectClient();
    _injectConnected = await inject.connect();

    // 5. TLS Session Server
    final server = TlsSessionServer(
      localIdentity: id,
      trustStore: trust,
      port: AirpadProtocolDefaults.port,
      askEveryTime: _askEveryTime,
    );
    await server.start();

    // Forward events from session to uinput helper
    server.onEventReceived.listen((event) {
      inject.sendEvent(event);
    });

    server.activeControllerStream.listen((controller) {
      setState(() {
        _activeController = controller;
      });
    });

    server.onClientDisconnected.listen((_) {
      // Disconnect clears any held keys in the helper
      inject.disconnect();
    });

    // Pairing prompt dialog handler
    server.onPairingPrompt.listen((prompt) {
      _showPairingPromptDialog(prompt);
    });

    // 6. Discovery Manager
    final discovery = DiscoveryManager(
      localDevice: localDevice,
      port: AirpadProtocolDefaults.port,
    );
    await discovery.startAdvertising();

    setState(() {
      _identity = id;
      _trustStore = trust;
      _sessionServer = server;
      _discoveryManager = discovery;
      _injectClient = inject;
      _isAdvertising = true;
    });
  }

  void _showPairingPromptDialog(PairingPromptRequest prompt) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        final dialogColors = AirColors.of(dialogCtx);
        return AlertDialog(
          backgroundColor: dialogColors.cardBg,
          title: const Text('PAIRING REQUEST'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'A mobile device is requesting permission to control this desktop:',
                style: TextStyle(color: dialogColors.textPrimary, fontSize: AirpadTokens.fontBody),
              ),
              const SizedBox(height: AirpadTokens.spacing16),
              AirCard(
                title: 'DEVICE DETAILS',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Alias: ${prompt.device.alias}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4.0),
                    Text(
                      'Fingerprint: ${prompt.device.shortFingerprint}',
                      style: TextStyle(fontFamily: 'monospace', color: dialogColors.textSecondary),
                    ),
                    if (prompt.device.ip != null) ...[
                      const SizedBox(height: 4.0),
                      Text('IP: ${prompt.device.ip}', style: TextStyle(color: dialogColors.textSecondary)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AirpadTokens.spacing16),
              AirCodeBox(code: prompt.code),
              const SizedBox(height: AirpadTokens.spacing12),
              Text(
                'Verify that this 6-digit code matches the code on your phone.',
                style: TextStyle(color: dialogColors.textSecondary, fontSize: AirpadTokens.fontCaption),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            AirButton(
              label: 'REJECT',
              variant: AirButtonVariant.outline,
              onPressed: () {
                prompt.reject();
                Navigator.of(dialogCtx).pop();
              },
            ),
            AirButton(
              label: 'PAIR & ALLOW',
              variant: AirButtonVariant.primary,
              onPressed: () {
                prompt.accept();
                Navigator.of(dialogCtx).pop();
                setState(() {});
              },
            ),
          ],
        );
      },
    );
  }

  void _showQrCodeDialog() {
    final server = _sessionServer;
    final id = _identity;
    if (server == null || id == null) return;

    final code = server.createQrPairingCode();
    final qrString = PairingCodeHelper.generateQrString(
      ip: _localIp,
      port: AirpadProtocolDefaults.port,
      fingerprint: id.fingerprint,
      code: code,
      alias: id.alias,
    );

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        final dialogColors = AirColors.of(dialogCtx);
        return AlertDialog(
          backgroundColor: dialogColors.cardBg,
          title: const Text('PAIR VIA QR CODE'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AirpadTokens.cornerRadius),
                  border: Border.all(color: dialogColors.border),
                ),
                child: QrImageView(
                  data: qrString,
                  version: QrVersions.auto,
                  size: 220.0,
                  backgroundColor: Colors.white,
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: AirpadTokens.spacing16),
              AirCodeBox(code: code, label: 'ONE-TIME CODE'),
              const SizedBox(height: AirpadTokens.spacing12),
              Text(
                'Open the Airpad mobile app and tap "Scan QR". Valid for 5 minutes.',
                style: TextStyle(color: dialogColors.textSecondary, fontSize: AirpadTokens.fontCaption),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            AirButton(
              label: 'CLOSE',
              variant: AirButtonVariant.outline,
              onPressed: () => Navigator.of(dialogCtx).pop(),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _sessionServer?.dispose();
    _discoveryManager?.dispose();
    _injectClient?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AirColors.of(context);
    final id = _identity;
    final trust = _trustStore;

    final AirStatusType statusType = _activeController != null
        ? AirStatusType.connected
        : (_isAdvertising ? AirStatusType.advertising : AirStatusType.idle);

    final statusLabel = _activeController != null
        ? 'CONTROLLED BY ${_activeController!.alias.toUpperCase()}'
        : (_isAdvertising ? 'ADVERTISING ON WI-FI' : 'OFFLINE');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('AIRPAD'),
            const SizedBox(width: AirpadTokens.spacing8),
            Text(
              'RECEIVER',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: AirpadTokens.fontCaption,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(widget.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: widget.onToggleTheme,
            tooltip: 'Toggle Theme',
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => exit(0),
            tooltip: 'Close Airpad',
          ),
          const SizedBox(width: AirpadTokens.spacing8),
        ],
      ),
      body: id == null
          ? Center(child: CircularProgressIndicator(color: colors.activeFill))
          : ListView(
              padding: const EdgeInsets.all(AirpadTokens.spacing24),
              children: [
                // Top Status Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AirStatusBadge(type: statusType, customLabel: statusLabel),
                    if (!_injectConnected)
                      const AirStatusBadge(type: AirStatusType.error, customLabel: 'INPUT HELPER DISCONNECTED'),
                  ],
                ),
                const SizedBox(height: AirpadTokens.spacing16),

                // Active Session Controller Banner (Security Req #9)
                if (_activeController != null) ...[
                  AirCard(
                    title: 'ACTIVE SESSION',
                    trailing: AirButton(
                      label: 'DISCONNECT',
                      variant: AirButtonVariant.outline,
                      onPressed: () => _sessionServer?.disconnectAll(),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Controlled by: ${_activeController!.alias}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: AirpadTokens.fontH2),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          'Fingerprint: ${_activeController!.shortFingerprint} (${_activeController!.ip ?? 'LAN'})',
                          style: TextStyle(fontFamily: 'monospace', color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AirpadTokens.spacing16),
                ],

                // Device Identity
                AirCard(
                  title: 'THIS DESKTOP DEVICE',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            id.alias,
                            style: const TextStyle(fontSize: AirpadTokens.fontH2, fontWeight: FontWeight.bold),
                          ),
                          AirButton(
                            label: 'PAIR VIA QR CODE',
                            icon: const Icon(Icons.qr_code, size: 16.0),
                            variant: AirButtonVariant.primary,
                            onPressed: _showQrCodeDialog,
                          ),
                        ],
                      ),
                      const SizedBox(height: AirpadTokens.spacing8),
                      Text(
                        'Fingerprint: ${id.fingerprint}',
                        style: TextStyle(fontFamily: 'monospace', fontSize: 11.0, color: colors.textSecondary),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        'Listening Endpoint: $_localIp:${AirpadProtocolDefaults.port}',
                        style: TextStyle(color: colors.textSecondary, fontSize: AirpadTokens.fontCaption),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AirpadTokens.spacing16),

                // Trusted Devices (Security Req #4, #5)
                AirCard(
                  title: 'PAIRED & TRUSTED DEVICES',
                  child: (trust == null || trust.trustedDevices.isEmpty)
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: AirpadTokens.spacing12),
                          child: Text(
                            'No paired devices yet. Scan the QR code or select this PC on the phone.',
                            style: TextStyle(color: colors.textSecondary),
                          ),
                        )
                      : Column(
                          children: trust.trustedDevices.map((dev) {
                            return AirTile(
                              title: dev.alias,
                              subtitle: dev.shortFingerprint,
                              trailing: AirButton(
                                label: 'REVOKE',
                                variant: AirButtonVariant.ghost,
                                onPressed: () async {
                                  await _sessionServer?.revokeDevice(dev.fingerprint);
                                  setState(() {});
                                },
                              ),
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: AirpadTokens.spacing16),

                // Settings & Preferences
                AirCard(
                  title: 'SECURITY & SETTINGS',
                  child: Column(
                    children: [
                      AirToggle(
                        label: 'Ask confirmation every time a device connects',
                        value: _askEveryTime,
                        onChanged: (val) {
                          setState(() {
                            _askEveryTime = val;
                            if (_sessionServer != null) {
                              _sessionServer!.askEveryTime = val;
                            }
                          });
                        },
                      ),
                      Divider(color: colors.border, height: AirpadTokens.spacing16),
                      AirToggle(
                        label: 'Auto-start on system login',
                        value: _autoStart,
                        onChanged: (val) {
                          setState(() => _autoStart = val);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
