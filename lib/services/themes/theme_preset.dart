import 'package:flutter/material.dart';

class AppThemePreset {
  final String labelKey;
  final Color background;
  final Color font;
  final Color primary;
  final Color secondary;
  final Color surface;

  const AppThemePreset(
    this.labelKey,
    this.background,
    this.font,
    this.primary,
    this.secondary,
    this.surface,
  );

  Color get accentColor => primary;
  Color get cardColor => surface;
  Color get primaryTextColor => font;
  Color get secondaryTextColor => font.withOpacity(0.7);
  Color get mutedTextColor => font.withOpacity(0.4);
  Color get fontColor => font;
  Color get flipCardColor => surface;

  // Cores específicas para o quiz bíblico
  Color get correct => const Color(0xFF4CAF50);
  Color get incorrect => const Color(0xFFF44336);
  Color get neutral => const Color(0xFF757575);
  Color get difficultyEasy => const Color(0xFF4CAF50);
  Color get difficultyMedium => const Color(0xFFFF9800);
  Color get difficultyHard => const Color(0xFFF44336);

  ThemeData toThemeData() {
    return ThemeData(
      useMaterial3: true,
      brightness: _getBrightness(),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: _getBrightness(),
        primary: primary,
        secondary: secondary,
        surface: surface,
        background: background,
        onBackground: font,
        onSurface: font,
      ),
      scaffoldBackgroundColor: background,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: _getButtonTextColor(),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(color: font, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: font, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: font, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: font, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: font),
        bodyMedium: TextStyle(color: font),
        bodySmall: TextStyle(color: font.withOpacity(0.7)),
      ),
    );
  }

  Brightness _getBrightness() {
    return ThemeData.estimateBrightnessForColor(background);
  }

  Color _getButtonTextColor() {
    return _getBrightness() == Brightness.dark ? Colors.white : Colors.white;
  }
}
