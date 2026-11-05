import 'package:flutter/material.dart';

/// [Palette] stores the Stitch design system colors and color schemes used 
/// in the Saffar application.
class Palette {
  // Stitch Design System Colors
  static const Color primary = Color(0xFFFF6B00); // Saffar Warm Orange
  static const Color onPrimary = Colors.white;

  static const Color primaryContainer = Color(0xFFFFE6D5);
  static const Color onPrimaryContainer = Color(0xFF6A2800);

  static const Color secondary = Color(0xFF173B67); // Saffar Deep Navy Blue
  static const Color onSecondary = Colors.white;

  static const Color secondaryContainer = Color(0xFFE5EDF7);
  static const Color onSecondaryContainer = Color(0xFF173B67);

  static const Color tertiary = Color(0xFF20A46B); // Saffar Emerald Green
  static const Color onTertiary = Colors.white;

  static const Color tertiaryContainer = Color(0xFFE2F7ED);
  static const Color onTertiaryContainer = Color(0xFF0F5A38);

  static const Color neutral = Color(0xFF172033); // Dark Slate Neutral
  static const Color neutralVariant = Color(0xFF64748B);

  static const Color background = Color(0xFFF6F8FC);
  static const Color onBackground = Color(0xFF172033);

  static const Color surface = Colors.white;
  static const Color onSurface = Color(0xFF172033);

  static const Color error = Color(0xFFDC2626);
  static const Color onError = Colors.white;

  static const Color success = Color(0xFF20A46B); // Emerald Green
  static const Color card = Colors.white; // Card Background

  static const Color outline = Color(0xFFE2E8F0);
  static const Color cardBorder = Color(0xFFE2E8F0);

  // Badges & Accents
  static const Color badgeFastest = Color(0xFFFF6B00);
  static const Color badgeValue = Color(0xFF20A46B);
  static const Color sosRed = Color(0xFFB91C1C);

  // Light color scheme
  static const ColorScheme lightColorScheme = ColorScheme(
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimaryContainer,
    secondary: secondary,
    onSecondary: onSecondary,
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: onSecondaryContainer,
    tertiary: tertiary,
    onTertiary: onTertiary,
    tertiaryContainer: tertiaryContainer,
    onTertiaryContainer: onTertiaryContainer,
    surface: surface,
    onSurface: onSurface,
    error: error,
    onError: onError,
    outline: outline,
    brightness: Brightness.light,
  );
}
