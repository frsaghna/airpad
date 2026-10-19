import 'package:airpad_core/airpad_core.dart';
import 'package:flutter/material.dart';
import '../theme/air_theme.dart';

/// Strictly monochrome switch toggle.
class AirToggle extends StatelessWidget {
  const AirToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final trackColor = value ? AirTheme.white : AirTheme.black;
    final thumbColor = value ? AirTheme.black : AirTheme.gray500;
    final borderColor = value ? AirTheme.white : AirTheme.gray500;

    final toggleWidget = GestureDetector(
      onTap: onChanged != null ? () => onChanged!(!value) : null,
      child: AnimatedContainer(
        duration: AirpadTokens.animFast,
        width: 44.0,
        height: 24.0,
        padding: const EdgeInsets.all(2.0),
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: borderColor, width: AirpadTokens.borderWidth),
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 18.0,
          height: 18.0,
          decoration: BoxDecoration(
            color: thumbColor,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );

    if (label != null) {
      return InkWell(
        onTap: onChanged != null ? () => onChanged!(!value) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AirpadTokens.spacing8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label!,
                style: const TextStyle(
                  color: AirTheme.white,
                  fontSize: AirpadTokens.fontBody,
                ),
              ),
              toggleWidget,
            ],
          ),
        ),
      );
    }

    return toggleWidget;
  }
}
