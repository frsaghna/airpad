import 'dart:async';
import 'package:airpad_core/airpad_core.dart';
import 'package:airpad_ui/airpad_ui.dart';
import 'package:flutter/material.dart';
import '../services/mobile_services.dart';
import 'controller_screen.dart';
import 'pairing_screen.dart';
import 'qr_scanner_screen.dart';
import 'settings_screen.dart';

/// Initial discovery screen listing nearby AIRPAD desktop receivers.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({
    super.key,
    required this.services,
  });

  final MobileServices services;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  StreamSubscription<SessionState>? _sessionSub;
  bool _isConnecting = false;
  String? _connectingDeviceAlias;

  @override
  void initState() {
    super.initState();
    _sessionSub = widget.services.sessionClient.onStateChanged.listen(_handleSessionState);
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    super.dispose();
  }

  void _handleSessionState(SessionState state) {
    if (!mounted) return;

    if (state is SessionPairingPrompt) {
      setState(() => _isConnecting = false);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PairingScreen(
            services: widget.services,
            code: state.code,
            desktopAlias: _connectingDeviceAlias ?? 'Desktop Receiver',
            desktopFingerprint: state.serverFingerprint,
            onConnected: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => ControllerScreen(services: widget.services),
                ),
              );
            },
          ),
        ),
      );
    } else if (state is SessionConnected) {
      setState(() => _isConnecting = false);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ControllerScreen(services: widget.services),
        ),
      );
    } else if (state is SessionRejected) {
      setState(() => _isConnecting = false);
      _showErrorDialog('PAIRING REJECTED', state.reason);
    } else if (state is SessionDisconnected && _isConnecting) {
      setState(() => _isConnecting = false);
      _showErrorDialog('CONNECTION FAILED', state.reason ?? 'Receiver closed connection');
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(message),
        actions: [
          AirButton(
            label: 'OK',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _connectToReceiver(AirpadDevice device) async {
    setState(() {
      _isConnecting = true;
      _connectingDeviceAlias = device.alias;
    });

    try {
      await widget.services.connectToDevice(device);
    } catch (e) {
      if (mounted) {
        setState(() => _isConnecting = false);
        _showErrorDialog('CONNECTION ERROR', e.toString());
      }
    }
  }

  Future<void> _openQrScanner() async {
    final payload = await Navigator.of(context).push<QrPairingPayload>(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );

    if (payload != null && mounted) {
      setState(() {
        _isConnecting = true;
        _connectingDeviceAlias = payload.alias;
      });

      try {
        await widget.services.connectToQr(payload);
      } catch (e) {
        if (mounted) {
          setState(() => _isConnecting = false);
          _showErrorDialog('QR PAIRING ERROR', e.toString());
        }
      }
    }
  }

  Future<void> _openManualIpDialog() async {
    final ipController = TextEditingController(text: '192.168.1.');
    final portController = TextEditingController(text: '${AirpadProtocolDefaults.port}');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'ENTER RECEIVER IP',
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: 'IP Address',
                hintText: '192.168.1.100',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: portController,
              decoration: InputDecoration(
                labelText: 'Port',
                hintText: '${AirpadProtocolDefaults.port}',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          AirButton(
            label: 'CANCEL',
            variant: AirButtonVariant.outline,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          const SizedBox(width: 8),
          AirButton(
            label: 'CONNECT',
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final ip = ipController.text.trim();
      final port = int.tryParse(portController.text.trim()) ?? AirpadProtocolDefaults.port;

      if (ip.isNotEmpty) {
        setState(() {
          _isConnecting = true;
          _connectingDeviceAlias = 'Manual ($ip)';
        });
        try {
          await widget.services.connectToIp(ip, port);
        } catch (e) {
          if (mounted) {
            setState(() => _isConnecting = false);
            _showErrorDialog('CONNECTION ERROR', e.toString());
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.services,
      builder: (context, _) {
        final colors = AirColors.of(context);
        final id = widget.services.identity;
        final shortFp = id.fingerprint.length > 12 ? id.fingerprint.substring(0, 12) : id.fingerprint;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AIRPAD',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
                Text(
                  '${id.alias.toUpperCase()} ($shortFp...)',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(
                  widget.services.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                ),
                onPressed: () {
                  widget.services.setIsDark(!widget.services.isDark);
                },
                tooltip: 'Toggle Theme',
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(services: widget.services),
                    ),
                  );
                },
                tooltip: 'Settings',
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Live Status Header Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: colors.cardBg,
                  child: Row(
                    children: [
                      const AirStatusBadge(
                        type: AirStatusType.advertising,
                        customLabel: 'SCANNING',
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'LAN DISCOVERY (MULTICAST + HTTP)',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      if (_isConnecting)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(colors.activeFill),
                          ),
                        ),
                    ],
                  ),
                ),

                // Receiver List
                Expanded(
                  child: StreamBuilder<List<AirpadDevice>>(
                    stream: widget.services.discoveryManager.nearbyDevices,
                    initialData: widget.services.discoveryManager.currentDevices,
                    builder: (context, snapshot) {
                      final devices = snapshot.data ?? [];

                      if (devices.isEmpty) {
                        return RefreshIndicator(
                          color: colors.activeFill,
                          backgroundColor: colors.bg,
                          onRefresh: () async {
                            await widget.services.discoveryManager.scanSubnetNow();
                          },
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(24.0),
                            children: [
                              const SizedBox(height: 60),
                              Icon(
                                Icons.wifi_tethering_outlined,
                                size: 56,
                                color: colors.textSecondary,
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'NO RECEIVERS DISCOVERED',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Ensure the AIRPAD desktop app is running on your PC and connected to the same Wi-Fi network.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'If router AP isolation prevents multicast discovery, use Scan QR or Enter IP below.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        color: colors.activeFill,
                        backgroundColor: colors.bg,
                        onRefresh: () async {
                          await widget.services.discoveryManager.scanSubnetNow();
                        },
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16.0),
                          itemCount: devices.length,
                          itemBuilder: (context, index) {
                            final dev = devices[index];
                            final isTrusted = widget.services.trustStore.isTrusted(dev.fingerprint);
                            final shortFp = dev.fingerprint.length > 16
                                ? '${dev.fingerprint.substring(0, 16)}...'
                                : dev.fingerprint;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12.0),
                              child: AirCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            dev.alias.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        AirStatusBadge(
                                          type: isTrusted
                                              ? AirStatusType.connected
                                              : AirStatusType.idle,
                                          customLabel: isTrusted ? 'PAIRED' : 'UNPAIRED',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${dev.ip ?? '127.0.0.1'}:${dev.port}',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 13,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'FP: $shortFp',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    SizedBox(
                                      width: double.infinity,
                                      child: AirButton(
                                        label: isTrusted ? 'CONNECT' : 'PAIR & CONNECT',
                                        onPressed: _isConnecting
                                            ? null
                                            : () => _connectToReceiver(dev),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Action Buttons
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: colors.cardBg,
                    border: Border(
                      top: BorderSide(
                        color: colors.border,
                        width: AirpadTokens.borderWidth,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: AirButton(
                          label: 'SCAN QR',
                          variant: AirButtonVariant.outline,
                          onPressed: _isConnecting ? null : _openQrScanner,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AirButton(
                          label: 'ENTER IP',
                          variant: AirButtonVariant.outline,
                          onPressed: _isConnecting ? null : _openManualIpDialog,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
