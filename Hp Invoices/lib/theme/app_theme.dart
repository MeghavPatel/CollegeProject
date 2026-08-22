import 'package:flutter/material.dart';

class AppTheme {
  // --- Stitch UI: Emerald Ledger Color Tokens ---
  static const Color primaryEmerald = Color(0xFF006948); // Deep Emerald Main Accent
  static const Color primaryDark = Color(0xFF005137);
  static const Color primaryLight = Color(0xFF85F8C4); // Mint Highlight
  static const Color primaryContainer = Color(0xFF00855D); // Emerald Container
  static const Color onPrimaryContainer = Color(0xFFF5FFF7);

  static const Color secondarySlate = Color(0xFF555F70); // Secondary Slate Gray
  static const Color secondaryContainer = Color(0xFFD6E0F4); // Soft Blue-Gray Container
  static const Color onSecondaryContainer = Color(0xFF3D4757);

  static const Color tertiaryMint = Color(0xFF10B981); // Bright Mint Accent
  static const Color tertiaryContainer = Color(0xFF00855B);
  static const Color onTertiaryContainer = Color(0xFFF5FFF6);

  static const Color surface = Color(0xFFF8F9FA); // Off-white Clean Canvas
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF); // Pure White Cards
  static const Color surfaceContainerLow = Color(0xFFF3F4F5); // Light Tonal Surface
  static const Color surfaceContainer = Color(0xFFEDEEEF);
  static const Color surfaceContainerHigh = Color(0xFFE7E8E9);
  static const Color surfaceContainerHighest = Color(0xFFE1E3E4);

  static const Color textPrimary = Color(0xFF191C1D); // High legibility dark text
  static const Color textSecondary = Color(0xFF3D4A42); // Muted gray-green variant
  static const Color textMuted = Color(0xFF6D7A72); // Outline / Subtle Muted text
  static const Color outline = Color(0xFF6D7A72);
  static const Color outlineVariant = Color(0xFFBCCAC0); // Delicate subtle border
  static const Color accentBorder = Color(0xFFE1E3E4);

  // Semantic Colors
  static const Color errorRed = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);
  static const Color successGreen = Color(0xFF006948);
  static const Color successContainer = Color(0xFFD1FAE5);

  // Compatibility aliases
  static const Color primaryPurple = primaryEmerald;
  static const Color secondaryPurple = primaryContainer;
  static const Color lightPurpleBg = surface;
  static const Color cardBg = surfaceContainerLowest;
  static const Color accentTeal = tertiaryMint;
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentDeepPurple = Color(0xFF005137);
  static const Color accentIndigo = Color(0xFF4F46E5);

  // Gradients
  static const Gradient primaryGradient = LinearGradient(
    colors: [primaryEmerald, primaryContainer],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient heroCardGradient = LinearGradient(
    colors: [Color(0xFF006948), Color(0xFF004D34)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient dashboardBgGradient = LinearGradient(
    colors: [Color(0xFFF8F9FA), Color(0xFFEDEEEF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const Gradient lockScreenGradient = LinearGradient(
    colors: [Color(0xFF004D34), Color(0xFF006948), Color(0xFF00855D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Modern Soft Shadows
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      offset: const Offset(0, 4),
      blurRadius: 16,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: primaryEmerald.withValues(alpha: 0.04),
      offset: const Offset(0, 2),
      blurRadius: 6,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> tileShadow(Color accentColor) => [
    BoxShadow(
      color: accentColor.withValues(alpha: 0.08),
      offset: const Offset(0, 6),
      blurRadius: 16,
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.02),
      offset: const Offset(0, 2),
      blurRadius: 4,
    ),
  ];

  // Theme Data Builder
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryEmerald,
      scaffoldBackgroundColor: surface,
      colorScheme: const ColorScheme.light(
        primary: primaryEmerald,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondarySlate,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        tertiary: tertiaryMint,
        tertiaryContainer: tertiaryContainer,
        onTertiaryContainer: onTertiaryContainer,
        surface: surface,
        onSurface: textPrimary,
        error: errorRed,
        errorContainer: errorContainer,
        onErrorContainer: onErrorContainer,
        outline: outline,
        outlineVariant: outlineVariant,
      ),
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.8,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.4,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
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
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: outlineVariant, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: primaryEmerald),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: primaryEmerald,
          letterSpacing: -0.3,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outlineVariant, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outlineVariant, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryEmerald, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryEmerald,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryEmerald,
          side: const BorderSide(color: outlineVariant, width: 1.2),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceContainerLowest,
        side: const BorderSide(color: outlineVariant, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: const TextStyle(
          color: primaryEmerald,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
