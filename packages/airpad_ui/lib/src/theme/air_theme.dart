import 'package:airpad_core/airpad_core.dart';
import 'package:flutter/material.dart';

/// Semantic monochrome colors that adapt cleanly between Dark and Light mode.
class AirColors {
  const AirColors({
    required this.bg,
    required this.surface,
    required this.cardBg,
    required this.border,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.activeFill,
    required this.onActiveFill,
    required this.isDark,
  });

  final Color bg;
  final Color surface;
  final Color cardBg;
  final Color border;
  final Color borderSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color activeFill;
  final Color onActiveFill;
  final bool isDark;

  static AirColors of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? dark : light;
  }

  static const dark = AirColors(
    bg: AirTheme.black,
    surface: AirTheme.gray900,
    cardBg: AirTheme.gray900,
    border: AirTheme.gray700,
    borderSubtle: Color(0xFF222222),
    textPrimary: AirTheme.white,
    textSecondary: AirTheme.gray500,
    activeFill: AirTheme.white,
    onActiveFill: AirTheme.black,
    isDark: true,
  );

  static const light = AirColors(
    bg: AirTheme.white,
    surface: Color(0xFFF4F4F6),
    cardBg: Color(0xFFF7F7F8),
    border: Color(0xFFE2E2E6),
    borderSubtle: Color(0xFFEEEEF0),
    textPrimary: AirTheme.black,
    textSecondary: Color(0xFF666666),
    activeFill: AirTheme.black,
    onActiveFill: AirTheme.white,
    isDark: false,
  );
}

/// Builds the strictly monochrome ThemeData for Airpad based on [AirpadTokens].
abstract final class AirTheme {
  static const Color black = Color(AirpadTokens.black);
  static const Color white = Color(AirpadTokens.white);
  static const Color gray900 = Color(AirpadTokens.gray900);
  static const Color gray700 = Color(AirpadTokens.gray700);
  static const Color gray500 = Color(AirpadTokens.gray500);
  static const Color gray100 = Color(AirpadTokens.gray100);

  /// Dark theme (Default): black background, white text, gray structural elements.
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: black,
      canvasColor: black,
      cardColor: gray900,
      dividerColor: gray700,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: white,
        onPrimary: black,
        secondary: gray100,
        onSecondary: black,
        surface: gray900,
        onSurface: white,
        error: white,
        onError: black,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: black,
        foregroundColor: white,
        elevation: 0.0,
        scrolledUnderElevation: 0.0,
        centerTitle: false,
        iconTheme: IconThemeData(color: white),
        titleTextStyle: TextStyle(
          color: white,
          fontSize: AirpadTokens.fontH2,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
      cardTheme: CardThemeData(
        color: gray900,
        elevation: 0.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AirpadTokens.cornerRadius),
          side: const BorderSide(color: gray700, width: AirpadTokens.borderWidth),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: gray900,
        elevation: 0.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AirpadTokens.cornerRadius),
          side: const BorderSide(color: white, width: AirpadTokens.borderWidth),
        ),
        titleTextStyle: const TextStyle(
          color: white,
          fontSize: AirpadTokens.fontH2,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          color: gray100,
          fontSize: AirpadTokens.fontBody,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: white,
          fontSize: AirpadTokens.fontDisplay,
          fontWeight: FontWeight.bold,
          letterSpacing: AirpadTokens.trackingDisplay,
        ),
        headlineMedium: TextStyle(
          color: white,
          fontSize: AirpadTokens.fontH1,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          color: white,
          fontSize: AirpadTokens.fontH2,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(
          color: white,
          fontSize: AirpadTokens.fontBody,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          color: gray500,
          fontSize: AirpadTokens.fontCaption,
        ),
        labelSmall: TextStyle(
          color: gray500,
          fontSize: AirpadTokens.fontSectionLabel,
          fontWeight: FontWeight.bold,
          letterSpacing: AirpadTokens.trackingSection,
        ),
      ),
    );
  }

  /// Refined inverted light theme: clean white background, deep black text, crisp subtle borders.
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: white,
      canvasColor: white,
      cardColor: const Color(0xFFF7F7F8),
      dividerColor: const Color(0xFFE2E2E6),
      fontFamily: 'Inter',
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: black,
        onPrimary: white,
        secondary: Color(0xFF555555),
        onSecondary: white,
        surface: Color(0xFFF7F7F8),
        onSurface: black,
        error: black,
        onError: white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: white,
        foregroundColor: black,
        elevation: 0.0,
        scrolledUnderElevation: 0.0,
        centerTitle: false,
        iconTheme: IconThemeData(color: black),
        titleTextStyle: TextStyle(
          color: black,
          fontSize: AirpadTokens.fontH2,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFF7F7F8),
        elevation: 0.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AirpadTokens.cornerRadius),
          side: const BorderSide(color: Color(0xFFE2E2E6), width: AirpadTokens.borderWidth),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: white,
        elevation: 0.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AirpadTokens.cornerRadius),
          side: const BorderSide(color: black, width: AirpadTokens.borderWidth),
        ),
        titleTextStyle: const TextStyle(
          color: black,
          fontSize: AirpadTokens.fontH2,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          color: black,
          fontSize: AirpadTokens.fontBody,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: black,
          fontSize: AirpadTokens.fontDisplay,
          fontWeight: FontWeight.bold,
          letterSpacing: AirpadTokens.trackingDisplay,
        ),
        headlineMedium: TextStyle(
          color: black,
          fontSize: AirpadTokens.fontH1,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          color: black,
          fontSize: AirpadTokens.fontH2,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(
          color: black,
          fontSize: AirpadTokens.fontBody,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          color: Color(0xFF666666),
          fontSize: AirpadTokens.fontCaption,
        ),
        labelSmall: TextStyle(
          color: Color(0xFF666666),
          fontSize: AirpadTokens.fontSectionLabel,
          fontWeight: FontWeight.bold,
          letterSpacing: AirpadTokens.trackingSection,
        ),
      ),
    );
  }
}
