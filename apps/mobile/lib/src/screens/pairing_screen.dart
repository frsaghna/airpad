import 'package:airpad_core/airpad_core.dart';
import 'package:airpad_ui/airpad_ui.dart';
import 'package:flutter/material.dart';
import '../services/mobile_services.dart';

/// Pairing screen displaying the 6-digit verification code while waiting for desktop confirmation.
class PairingScreen extends StatelessWidget {
  const PairingScreen({
    super.key,
    required this.services,
    required this.code,
    required this.desktopAlias,
    required this.desktopFingerprint,
    required this.onConnected,
  });

  final MobileServices services;
  final String code;
  final String desktopAlias;
  final String desktopFingerprint;
  final VoidCallback onConnected;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: services,
      builder: (context, _) {
        final state = services.sessionState;
        if (state is SessionConnected) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onConnected();
          });
        }

        final colors = AirColors.of(context);
        final isRejected = state is SessionRejected;

        return Scaffold(
          appBar: AppBar(
            title: const Text('PAIRING REQUEST'),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () async {
                  await services.disconnect();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                tooltip: 'Cancel',
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),

                  // Desktop Target Card
                  AirCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DESKTOP RECEIVER',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          desktopAlias.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'FP: ${desktopFingerprint.length > 20 ? '${desktopFingerprint.substring(0, 20)}...' : desktopFingerprint}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  if (isRejected) ...[
                    AirCard(
                      child: Column(
                        children: [
                          Icon(Icons.block_outlined, size: 40, color: colors.textPrimary),
                          const SizedBox(height: 12),
                          const Text(
                            'PAIRING REJECTED',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            state.reason,
                            style: TextStyle(color: colors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // 6-digit Code Box
                    AirCodeBox(code: code),

                    const SizedBox(height: 24),

                    const Text(
                      'COMPARE THIS CODE ON YOUR PC',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A pairing dialog has appeared on your desktop receiver. Verify that the 6-digit code matches and click "Confirm" to grant input control.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Center(
                      child: AirStatusBadge(
                        type: AirStatusType.idle,
                        customLabel: 'WAITING FOR DESKTOP...',
                      ),
                    ),
                  ],

                  const Spacer(),

                  AirButton(
                    label: isRejected ? 'DISMISS' : 'CANCEL PAIRING',
                    variant: AirButtonVariant.outline,
                    onPressed: () async {
                      await services.disconnect();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
