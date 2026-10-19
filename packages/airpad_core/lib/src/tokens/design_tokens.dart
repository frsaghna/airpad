/// Design tokens for the strictly monochrome AIRPAD design system.
///
/// Contains pure Dart primitives so that it can be used across mobile, desktop,
/// and backend/CLI tools without requiring Flutter dependencies.
abstract final class AirpadTokens {
  // Colors (ARGB 32-bit integers)
  static const int black = 0xFF000000;
  static const int white = 0xFFFFFFFF;
  static const int gray900 = 0xFF111111;
  static const int gray700 = 0xFF2A2A2A;
  static const int gray500 = 0xFF777777;
  static const int gray100 = 0xFFEDEDED;

  // Geometry & Spacing
  static const double gridBase = 8.0;
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing48 = 48.0;

  static const double borderWidth = 1.0;
  static const double cornerRadius = 4.0;
  static const double minTouchTarget = 48.0;

  // Typography font sizes
  static const double fontDisplay = 32.0;
  static const double fontH1 = 20.0;
  static const double fontH2 = 16.0;
  static const double fontBody = 14.0;
  static const double fontCaption = 12.0;
  static const double fontSectionLabel = 11.0;

  // Typography letter spacing
  static const double trackingDisplay = 2.0;
  static const double trackingSection = 1.5;

  // Animation Durations (<= 150ms per design doc)
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animTapFlash = Duration(milliseconds: 40);
}
