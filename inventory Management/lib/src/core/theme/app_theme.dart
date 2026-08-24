import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // InvTrack Pro Color Palette (from Khush UI Reference)
  static const Color primaryBlue = Color(0xFF004AC6);
  static const Color primaryContainer = Color(0xFF2563EB);
  static const Color primaryFixed = Color(0xFFDBE1FF);
  static const Color primaryFixedDim = Color(0xFFB4C5FF);
  
  static const Color secondary = Color(0xFF505F76);
  static const Color secondaryContainer = Color(0xFFD0E1FB);
  
  static const Color tertiaryGreen = Color(0xFF006242);
  static const Color tertiaryContainer = Color(0xFF007D55);
  static const Color tertiaryFixed = Color(0xFF6FFBBE);
  
  static const Color errorRed = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);
  
  static const Color bgColor = Color(0xFFF8F9FA);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF3F4F5);
  static const Color surfaceContainer = Color(0xFFEDEEEF);
  static const Color surfaceContainerHigh = Color(0xFFE7E8E9);
  static const Color surfaceContainerHighest = Color(0xFFE1E3E4);
  
  static const Color onSurface = Color(0xFF191C1D);
  static const Color onSurfaceVariant = Color(0xFF434655);
  static const Color outline = Color(0xFF737686);
  static const Color outlineVariant = Color(0xFFC3C6D7);
  
  // Dark mode colors
  static const Color darkBgColor = Color(0xFF121316);
  static const Color darkSurfaceColor = Color(0xFF1E2024);
  static const Color darkSurfaceContainer = Color(0xFF282B30);

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: GoogleFonts.inter().fontFamily,
    scaffoldBackgroundColor: bgColor,
    primaryColor: primaryBlue,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryBlue,
      primary: primaryBlue,
      primaryContainer: primaryContainer,
      secondary: secondary,
      secondaryContainer: secondaryContainer,
      tertiary: tertiaryGreen,
      tertiaryContainer: tertiaryContainer,
      error: errorRed,
      errorContainer: errorContainer,
      surface: surfaceColor,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      outlineVariant: outlineVariant,
      brightness: Brightness.light,
    ),
    textTheme: TextTheme(
      headlineLarge: GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: onSurface,
        letterSpacing: -0.01,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      headlineSmall: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: onSurfaceVariant,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: onSurfaceVariant,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: onSurfaceVariant,
        letterSpacing: 0.05,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: surfaceColor.withValues(alpha: 0.9),
      foregroundColor: primaryBlue,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: primaryBlue,
      ),
      iconTheme: const IconThemeData(color: primaryBlue),
    ),
    cardTheme: CardThemeData(
      color: surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: outlineVariant.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      margin: const EdgeInsets.all(8),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: primaryBlue.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: outlineVariant.withValues(alpha: 0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: outlineVariant.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryBlue, width: 2),
      ),
      hintStyle: GoogleFonts.inter(color: outline, fontSize: 14),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    fontFamily: GoogleFonts.inter().fontFamily,
    scaffoldBackgroundColor: darkBgColor,
    primaryColor: primaryContainer,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryBlue,
      primary: primaryFixedDim,
      primaryContainer: primaryBlue,
      secondary: secondaryContainer,
      tertiary: tertiaryFixed,
      error: errorRed,
      surface: darkSurfaceColor,
      onSurface: Colors.white,
      onSurfaceVariant: const Color(0xFFC3C6D7),
      outline: outline,
      outlineVariant: const Color(0xFF434655),
      brightness: Brightness.dark,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: darkSurfaceColor.withValues(alpha: 0.9),
      foregroundColor: primaryFixedDim,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: primaryFixedDim,
      ),
      iconTheme: const IconThemeData(color: primaryFixedDim),
    ),
    cardTheme: CardThemeData(
      color: darkSurfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFF434655).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      margin: const EdgeInsets.all(8),
    ),
  );
}

