import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme_extension.dart';
import 'app_theme_variant.dart';

abstract final class AppThemes {
  static ThemeData forVariant(AppThemeVariant variant) {
    return switch (variant) {
      AppThemeVariant.classicDark => _classicDark(),
      AppThemeVariant.classicLight => _classicLight(),
      AppThemeVariant.sunset => _sunset(),
      AppThemeVariant.ocean => _ocean(),
    };
  }

  static ThemeData _classicDark() {
    const decor = AppDecor(
      backgroundGradientStart: Color(0xFF1A1A2E),
      backgroundGradientEnd: Color(0xFF16213E),
      cardColor: Color(0xFF1F2940),
      cardBorderColor: Color(0xFF3D4F6F),
      cardBorderWidth: 1,
      cardBorderRadius: 20,
      accentColor: Color(0xFFF0A500),
      accentSecondary: Color(0xFFE94560),
      glowColor: Color(0x40F0A500),
      navBarColor: Color(0xCC1A1A2E),
      navBarBorderColor: Color(0xFF3D4F6F),
      buttonStyle: AppButtonStyle.soft,
      buttonBorderRadius: 14,
      subtleTextColor: Color(0xFF9BA4B5),
      orbColor1: Color(0x30F0A500),
      orbColor2: Color(0x20E94560),
      cardHoverGlow: Color(0x50F0A500),
    );

    final textTheme = GoogleFonts.nunitoTextTheme(_baseTextTheme(Colors.white));
    return _buildTheme(
      decor: decor,
      brightness: Brightness.dark,
      textTheme: textTheme,
      primary: decor.accentColor,
      surface: const Color(0xFF1F2940),
    );
  }

  static ThemeData _classicLight() {
    const decor = AppDecor(
      backgroundGradientStart: Color(0xFFF8F9FC),
      backgroundGradientEnd: Color(0xFFEEF2F7),
      cardColor: Color(0xFFFFFFFF),
      cardBorderColor: Color(0xFFE2E8F0),
      cardBorderWidth: 1,
      cardBorderRadius: 18,
      accentColor: Color(0xFF6366F1),
      accentSecondary: Color(0xFF8B5CF6),
      glowColor: Color(0x306366F1),
      navBarColor: Color(0xE6FFFFFF),
      navBarBorderColor: Color(0xFFE2E8F0),
      buttonStyle: AppButtonStyle.filled,
      buttonBorderRadius: 12,
      subtleTextColor: Color(0xFF64748B),
      orbColor1: Color(0x206366F1),
      orbColor2: Color(0x158B5CF6),
      cardHoverGlow: Color(0x406366F1),
    );

    final textTheme =
        GoogleFonts.interTextTheme(_baseTextTheme(const Color(0xFF1E293B)));
    return _buildTheme(
      decor: decor,
      brightness: Brightness.light,
      textTheme: textTheme,
      primary: decor.accentColor,
      surface: Colors.white,
    );
  }

  static ThemeData _sunset() {
    const decor = AppDecor(
      backgroundGradientStart: Color(0xFF2D1B4E),
      backgroundGradientEnd: Color(0xFF1A0A2E),
      cardColor: Color(0xFF3D2659),
      cardBorderColor: Color(0xFF6B4080),
      cardBorderWidth: 1.5,
      cardBorderRadius: 22,
      accentColor: Color(0xFFFF6B6B),
      accentSecondary: Color(0xFFFFB347),
      glowColor: Color(0x40FF6B6B),
      navBarColor: Color(0xCC2D1B4E),
      navBarBorderColor: Color(0xFF6B4080),
      buttonStyle: AppButtonStyle.outlined,
      buttonBorderRadius: 16,
      subtleTextColor: Color(0xFFC4A8D8),
      orbColor1: Color(0x35FF6B6B),
      orbColor2: Color(0x25FFB347),
      cardHoverGlow: Color(0x50FF6B6B),
    );

    final base = _baseTextTheme(const Color(0xFFFFF5F0));
    final textTheme = GoogleFonts.quicksandTextTheme(base).copyWith(
      headlineLarge: GoogleFonts.playfairDisplay(
        textStyle: base.headlineLarge,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: GoogleFonts.playfairDisplay(
        textStyle: base.headlineMedium,
        fontWeight: FontWeight.w600,
      ),
    );

    return _buildTheme(
      decor: decor,
      brightness: Brightness.dark,
      textTheme: textTheme,
      primary: decor.accentColor,
      surface: decor.cardColor,
    );
  }

  static ThemeData _ocean() {
    const decor = AppDecor(
      backgroundGradientStart: Color(0xFF0A1628),
      backgroundGradientEnd: Color(0xFF0D2137),
      cardColor: Color(0xFF132D4A),
      cardBorderColor: Color(0xFF1E4D6B),
      cardBorderWidth: 1,
      cardBorderRadius: 20,
      accentColor: Color(0xFF00D4AA),
      accentSecondary: Color(0xFF4FC3F7),
      glowColor: Color(0x4000D4AA),
      navBarColor: Color(0xCC0A1628),
      navBarBorderColor: Color(0xFF1E4D6B),
      buttonStyle: AppButtonStyle.soft,
      buttonBorderRadius: 14,
      subtleTextColor: Color(0xFF7EB8C9),
      orbColor1: Color(0x3000D4AA),
      orbColor2: Color(0x204FC3F7),
      cardHoverGlow: Color(0x5000D4AA),
    );

    final textTheme =
        GoogleFonts.quicksandTextTheme(_baseTextTheme(Colors.white));
    return _buildTheme(
      decor: decor,
      brightness: Brightness.dark,
      textTheme: textTheme,
      primary: decor.accentColor,
      surface: decor.cardColor,
    );
  }

  static TextTheme _baseTextTheme(Color primaryText) {
    return TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: primaryText,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: primaryText,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: primaryText,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
    );
  }

  static ThemeData _buildTheme({
    required AppDecor decor,
    required Brightness brightness,
    required TextTheme textTheme,
    required Color primary,
    required Color surface,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: decor.backgroundGradientStart,
      extensions: [decor],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textTheme.titleLarge?.color,
      ),
      iconTheme: IconThemeData(color: textTheme.bodyLarge?.color),
    );
  }
}
