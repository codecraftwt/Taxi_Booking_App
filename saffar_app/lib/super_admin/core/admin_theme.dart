import 'package:flutter/material.dart';

class AdminTheme {
  AdminTheme._();

  // Saffar Brand Colors
  static const Color primaryOrange = Color(0xFFFF6B00);
  static const Color secondaryBlue = Color(0xFF173B67);
  static const Color background = Color(0xFFF6F8FB);
  static const Color bgLight = Color(0xFFF6F8FB);
  static const Color sidebarDark = Color(0xFF0F172A);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF172033);
  static const Color textSecondary = Color(0xFF7B8492);
  static const Color textMuted = Color(0xFFA0AAB8);
  static const Color border = Color(0xFFE5E9F0);
  static const Color borderSubtle = Color(0xFFE5E9F0);
  
  // Status Colors
  static const Color success = Color(0xFF20A46B);
  static const Color successGreen = Color(0xFF20A46B);
  static const Color successBg = Color(0xFFE8F7F0);
  static const Color warning = Color(0xFFF59E0B);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFE54848);
  static const Color errorRed = Color(0xFFE54848);
  static const Color errorBg = Color(0xFFFDE8E8);
  static const Color info = Color(0xFF2563EB);
  static const Color infoBg = Color(0xFFEFF6FF);

  // Typography helpers
  static const TextStyle headingLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontSize: 13,
    color: textSecondary,
  );

  // Card Decorations
  static BoxDecoration cardDecoration = BoxDecoration(
    color: cardBg,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: border, width: 1),
    boxShadow: const [
      BoxShadow(
        color: Color.fromRGBO(23, 32, 51, 0.04),
        blurRadius: 10,
        offset: Offset(0, 4),
      ),
    ],
  );

  static BoxDecoration elevatedCardDecoration = BoxDecoration(
    color: cardBg,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: border, width: 1),
    boxShadow: const [
      BoxShadow(
        color: Color.fromRGBO(23, 32, 51, 0.06),
        blurRadius: 14,
        offset: Offset(0, 4),
      ),
    ],
  );

  static ThemeData themeData = ThemeData(
    useMaterial3: true,
    fontFamily: 'Nunito',
    scaffoldBackgroundColor: background,
    primaryColor: primaryOrange,
    colorScheme: const ColorScheme.light(
      primary: primaryOrange,
      secondary: secondaryBlue,
      surface: cardBg,
      error: error,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: cardBg,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: textPrimary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryOrange, width: 1.5),
      ),
      labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
      hintStyle: const TextStyle(color: textMuted, fontSize: 13),
    ),
  );
}
