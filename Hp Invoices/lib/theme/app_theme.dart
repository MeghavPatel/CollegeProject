import 'package:flutter/material.dart';

class AppTheme {
  // Cohesive Light Purple Color Palette
  static const Color primaryPurple = Color(0xFF7C3AED); // Main Lavender Accent
  static const Color secondaryPurple = Color(0xFF9D4EDD); // Indigo / Soft Purple
  static const Color lightPurpleBg = Color(0xFFF5F3FF); // Lavender White Background
  static const Color cardBg = Color(0xFFFFFFFF); // Pure White Cards
  static const Color textPrimary = Color(0xFF1F2937); // Very dark gray for high legibility
  static const Color textSecondary = Color(0xFF6B7280); // Muted gray
  static const Color accentBorder = Color(0xFFE5E7EB); // Light gray borders

  // Module Accents
  static const Color accentTeal = Color(0xFF10B981); // Green/Teal (Sales Invoice)
  static const Color accentBlue = Color(0xFF3B82F6); // Blue (Cash/Bank Entry)
  static const Color accentDeepPurple = Color(0xFF6D28D9); // Deep Purple (Outstanding)
  static const Color accentIndigo = Color(0xFF4F46E5); // Indigo/Lavender (A/c Ledger)

  // Gradients
  static const Gradient primaryGradient = LinearGradient(
    colors: [primaryPurple, Color(0xFFC084FC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient dashboardBgGradient = LinearGradient(
    colors: [lightPurpleBg, Color(0xFFEDE9FE)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const Gradient lockScreenGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFFA855F7), Color(0xFFC084FC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Modern Soft Shadows
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: primaryPurple.withOpacity(0.04),
      offset: const Offset(0, 4),
      blurRadius: 16,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.02),
      offset: const Offset(0, 2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> tileShadow(Color accentColor) => [
        BoxShadow(
          color: accentColor.withOpacity(0.06),
          offset: const Offset(0, 8),
          blurRadius: 20,
          spreadRadius: -2,
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.01),
          offset: const Offset(0, 2),
          blurRadius: 6,
        ),
      ];

  // Theme Data Builder
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryPurple,
      scaffoldBackgroundColor: lightPurpleBg,
      colorScheme: ColorScheme.light(
        primary: primaryPurple,
        secondary: secondaryPurple,
        surface: lightPurpleBg,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      fontFamily: 'Roboto', // Premium fallback, clean sans-serif
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.2,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.normal,
          color: textSecondary,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: accentBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryPurple, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
