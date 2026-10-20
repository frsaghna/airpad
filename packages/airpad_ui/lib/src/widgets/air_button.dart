import 'package:airpad_core/airpad_core.dart';
import 'package:flutter/material.dart';
import '../theme/air_theme.dart';

enum AirButtonVariant {
  primary,
  outline,
  ghost,
}

/// Strictly monochrome button with high contrast states and >=48dp touch targets.
class AirButton extends StatelessWidget {
  const AirButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = AirButtonVariant.primary,
    this.fullWidth = false,
    this.padding,
  });

  final String label;
  final Widget? icon;
  final VoidCallback? onPressed;
  final AirButtonVariant variant;
  final bool fullWidth;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final colors = AirColors.of(context);
    final enabled = onPressed != null;

    Color bg;
    Color fg;
    BorderSide border;

    if (!enabled) {
      bg = Colors.transparent;
      fg = colors.textSecondary;
      border = BorderSide(color: colors.border, width: AirpadTokens.borderWidth);
    } else {
      switch (variant) {
        case AirButtonVariant.primary:
          bg = colors.activeFill;
          fg = colors.onActiveFill;
          border = BorderSide.none;
          break;
        case AirButtonVariant.outline:
          bg = Colors.transparent;
          fg = colors.textPrimary;
          border = BorderSide(color: colors.textPrimary, width: AirpadTokens.borderWidth);
          break;
        case AirButtonVariant.ghost:
          bg = Colors.transparent;
          fg = colors.textPrimary;
          border = BorderSide.none;
          break;
      }
    }

    final content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          IconTheme.merge(
            data: IconThemeData(color: fg, size: 18),
            child: icon!,
          ),
          const SizedBox(width: AirpadTokens.spacing8),
        ],
        Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: AirpadTokens.fontBody,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AirpadTokens.cornerRadius),
      child: AnimatedContainer(
        duration: AirpadTokens.animFast,
        constraints: const BoxConstraints(
          minHeight: AirpadTokens.minTouchTarget,
          minWidth: AirpadTokens.minTouchTarget,
        ),
        padding: padding ??
            const EdgeInsets.symmetric(
              horizontal: AirpadTokens.spacing16,
              vertical: AirpadTokens.spacing12,
            ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AirpadTokens.cornerRadius),
          border: border == BorderSide.none ? null : Border.fromBorderSide(border),
        ),
        child: content,
      ),
    );
  }
}
