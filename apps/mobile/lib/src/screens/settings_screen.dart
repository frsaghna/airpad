import 'package:airpad_core/airpad_core.dart';
import 'package:airpad_ui/airpad_ui.dart';
import 'package:flutter/material.dart';
import '../services/mobile_services.dart';

/// Settings screen for configuring alias, sensitivity, scroll direction, haptics, and trusted receivers.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.services,
  });

  final MobileServices services;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _aliasController;
  bool _isEditingAlias = false;

  @override
  void initState() {
    super.initState();
    _aliasController = TextEditingController(text: widget.services.identity.alias);
  }

  @override
  void dispose() {
    _aliasController.dispose();
    super.dispose();
  }

  void _saveAlias() async {
    final text = _aliasController.text.trim();
    if (text.isNotEmpty) {
      await widget.services.updateAlias(text);
      setState(() {
        _isEditingAlias = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.services,
      builder: (context, _) {
        final colors = AirColors.of(context);
        final id = widget.services.identity;
        final trustedList = widget.services.trustStore.trustedDevices;

        return Scaffold(
          appBar: AppBar(
            title: const Text('SETTINGS'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Device Identity Card
              AirCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DEVICE IDENTITY',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isEditingAlias) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _aliasController,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(color: colors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: colors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: colors.activeFill),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          AirButton(
                            label: 'SAVE',
                            onPressed: _saveAlias,
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            id.alias.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () {
                              setState(() {
                                _isEditingAlias = true;
                              });
                            },
                            tooltip: 'Edit Alias',
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'SHA-256 FINGERPRINT',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      id.fingerprint,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Touchpad & Gestures Section
              AirCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOUCHPAD & GESTURES',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sensitivity Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Sensitivity'),
                        Text(
                          '${widget.services.sensitivity.toStringAsFixed(1)}x',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: widget.services.sensitivity,
                      min: 0.5,
                      max: 3.0,
                      divisions: 25,
                      activeColor: colors.activeFill,
                      inactiveColor: colors.border,
                      onChanged: (val) {
                        widget.services.setSensitivity(val);
                      },
                    ),
                    const SizedBox(height: 8),

                    // Natural Scroll Toggle
                    AirToggle(
                      label: 'Natural Scrolling',
                      value: widget.services.naturalScroll,
                      onChanged: (val) {
                        widget.services.setNaturalScroll(val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // 3-Finger Gestures Toggle
                    AirToggle(
                      label: '3-Finger Swipes (Workspaces & Menu)',
                      value: widget.services.threeFingerSwipes,
                      onChanged: (val) {
                        widget.services.setThreeFingerSwipes(val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Haptic Feedback Toggle
                    AirToggle(
                      label: 'Haptic Feedback',
                      value: widget.services.hapticsEnabled,
                      onChanged: (val) {
                        widget.services.setHapticsEnabled(val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Keep Screen On Toggle
                    AirToggle(
                      label: 'Keep Screen Awake',
                      value: widget.services.keepScreenOn,
                      onChanged: (val) {
                        widget.services.setKeepScreenOn(val);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Appearance Section
              AirCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'APPEARANCE',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AirToggle(
                      label: 'Dark Mode (Black & White)',
                      value: widget.services.isDark,
                      onChanged: (val) {
                        widget.services.setIsDark(val);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Trusted Desktops Section
              AirCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TRUSTED RECEIVERS',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: colors.textSecondary,
                          ),
                        ),
                        Text(
                          '${trustedList.length} PAIRED',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (trustedList.isEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'No trusted desktop receivers yet. Pair with a desktop to connect instantly.',
                          style: TextStyle(color: colors.textSecondary, fontSize: 13),
                        ),
                      ),
                    ] else ...[
                      ...trustedList.map((dev) {
                        final shortFp = dev.fingerprint.length > 16
                            ? '${dev.fingerprint.substring(0, 16)}...'
                            : dev.fingerprint;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8.0),
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(AirpadTokens.cornerRadius),
                            border: Border.all(
                              color: colors.border,
                              width: AirpadTokens.borderWidth,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dev.alias.toUpperCase(),
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      shortFp,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AirButton(
                                label: 'REVOKE',
                                variant: AirButtonVariant.outline,
                                onPressed: () async {
                                  await widget.services.trustStore.revokeDevice(dev.fingerprint);
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // About & Protocol Info
              Center(
                child: Column(
                  children: [
                    const Text(
                      'AIRPAD MOBILE — v1.0.0',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'LocalSend-style Zero-Config LAN Discovery & TLS Control',
                      style: TextStyle(fontSize: 12, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
