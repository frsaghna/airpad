import 'package:airpad_core/airpad_core.dart';
import 'package:flutter/material.dart';

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

  /// Optional inverted light theme: white background, black text.
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: white,
      canvasColor: white,
      cardColor: gray100,
      dividerColor: gray700,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: black,
        onPrimary: white,
        secondary: gray900,
        onSecondary: white,
        surface: gray100,
        onSurface: black,
        error: black,
        onError: white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: white,
        foregroundColor: black,
        elevation: 0.0,
        scrolledUnderElevation: 0.0,
        titleTextStyle: TextStyle(
          color: black,
          fontSize: AirpadTokens.fontH2,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
      cardTheme: CardThemeData(
        color: gray100,
        elevation: 0.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AirpadTokens.cornerRadius),
          side: const BorderSide(color: gray700, width: AirpadTokens.borderWidth),
        ),
      ),
    );
  }
}
