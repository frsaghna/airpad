import 'package:airpad_core/airpad_core.dart';
import 'package:flutter/material.dart';
import '../theme/air_theme.dart';

/// Monochrome list tile supporting inversion on selection.
class AirTile extends StatelessWidget {
  const AirTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = AirColors.of(context);
    final bg = selected ? colors.activeFill : Colors.transparent;
    final fgTitle = selected ? colors.onActiveFill : colors.textPrimary;
    final fgSub = selected ? colors.onActiveFill.withOpacity(0.7) : colors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AirpadTokens.cornerRadius),
      child: AnimatedContainer(
        duration: AirpadTokens.animFast,
        constraints: const BoxConstraints(minHeight: AirpadTokens.minTouchTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: AirpadTokens.spacing16,
          vertical: AirpadTokens.spacing12,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AirpadTokens.cornerRadius),
          border: selected
              ? null
              : Border(
                  bottom: BorderSide(color: colors.border, width: AirpadTokens.borderWidth),
                ),
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AirpadTokens.spacing12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: fgTitle,
                      fontSize: AirpadTokens.fontBody,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AirpadTokens.spacing4),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: fgSub,
                        fontSize: AirpadTokens.fontCaption,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
