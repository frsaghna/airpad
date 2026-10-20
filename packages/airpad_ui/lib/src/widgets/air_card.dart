import 'package:airpad_core/airpad_core.dart';
import 'package:flutter/material.dart';
import '../theme/air_theme.dart';

/// Strictly monochrome raised surface card with 1px border.
class AirCard extends StatelessWidget {
  const AirCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(AirpadTokens.spacing16),
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = AirColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(AirpadTokens.cornerRadius),
        border: Border.all(
          color: colors.border,
          width: AirpadTokens.borderWidth,
        ),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title!.toUpperCase(),
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: AirpadTokens.fontSectionLabel,
                    fontWeight: FontWeight.bold,
                    letterSpacing: AirpadTokens.trackingSection,
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: AirpadTokens.spacing12),
          ],
          child,
        ],
      ),
    );
  }
}
