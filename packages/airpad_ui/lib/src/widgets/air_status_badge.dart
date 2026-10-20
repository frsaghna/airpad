import 'package:airpad_core/airpad_core.dart';
import 'package:flutter/material.dart';
import '../theme/air_theme.dart';

enum AirStatusType {
  connected,
  advertising,
  idle,
  error,
}

/// Compact status pill that communicates connection status without color.
class AirStatusBadge extends StatelessWidget {
  const AirStatusBadge({
    super.key,
    required this.type,
    this.customLabel,
  });

  final AirStatusType type;
  final String? customLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AirColors.of(context);
    Color bg;
    Color fg;
    Border? border;
    String symbol;
    String defaultText;

    switch (type) {
      case AirStatusType.connected:
        bg = colors.activeFill;
        fg = colors.onActiveFill;
        border = null;
        symbol = '●';
        defaultText = 'CONNECTED';
        break;
      case AirStatusType.advertising:
        bg = Colors.transparent;
        fg = colors.textPrimary;
        border = Border.all(color: colors.textPrimary, width: AirpadTokens.borderWidth);
        symbol = '○';
        defaultText = 'ADVERTISING';
        break;
      case AirStatusType.idle:
        bg = Colors.transparent;
        fg = colors.textSecondary;
        border = Border.all(color: colors.border, width: AirpadTokens.borderWidth);
        symbol = '─';
        defaultText = 'IDLE';
        break;
      case AirStatusType.error:
        bg = colors.activeFill;
        fg = colors.onActiveFill;
        border = null;
        symbol = '✕';
        defaultText = 'ERROR';
        break;
    }

    final text = customLabel ?? defaultText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12.0),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            symbol,
            style: TextStyle(
              color: fg,
              fontSize: 10.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6.0),
          Text(
            text.toUpperCase(),
            style: TextStyle(
              color: fg,
              fontSize: 11.0,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
