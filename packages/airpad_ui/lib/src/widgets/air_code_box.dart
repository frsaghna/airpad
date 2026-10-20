import 'package:airpad_core/airpad_core.dart';
import 'package:flutter/material.dart';
import '../theme/air_theme.dart';

/// Large monospace display box for the 6-digit verification pairing code.
class AirCodeBox extends StatelessWidget {
  const AirCodeBox({
    super.key,
    required this.code,
    this.label = 'VERIFICATION CODE',
  });

  final String code;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AirColors.of(context);
    // Format "123 456" for readability if 6 digits
    final displayCode = code.length == 6
        ? '${code.substring(0, 3)} ${code.substring(3, 6)}'
        : code;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AirpadTokens.spacing24,
        vertical: AirpadTokens.spacing16,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AirpadTokens.cornerRadius),
        border: Border.all(color: colors.activeFill, width: AirpadTokens.borderWidth),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: AirpadTokens.fontSectionLabel,
              letterSpacing: AirpadTokens.trackingSection,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AirpadTokens.spacing8),
          Text(
            displayCode,
            style: TextStyle(
              color: colors.textPrimary,
              fontFamily: 'monospace',
              fontSize: AirpadTokens.fontDisplay,
              fontWeight: FontWeight.bold,
              letterSpacing: AirpadTokens.trackingDisplay,
            ),
          ),
        ],
      ),
    );
  }
}
