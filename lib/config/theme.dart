import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─── Brand Colors ──────────────────────────────────────
  static const Color primaryGreen = Color(0xFF059669);      // emerald-600
  static const Color primaryGreenDark = Color(0xFF047857);   // emerald-700
  static const Color primaryGreenLight = Color(0xFFD1FAE5);  // emerald-100
  static const Color emerald50 = Color(0xFFECFDF5);
  static const Color emerald400 = Color(0xFF34D399);
  
  static const Color accentOrange = Color(0xFFF97316);
  static const Color accentYellow = Color(0xFFFBBF24);
  static const Color amber500 = Color(0xFFF59E0B);
  static const Color amber600 = Color(0xFFD97706);
  
  static const Color backgroundLight = Color(0xFFFDFCF8);   // warm cream (matches website)
  static const Color surfaceWhite = Color(0xFFFFFFFE);       // barely warm white
  
  static const Color textPrimary = Color(0xFF0F172A);        // slate-900
  static const Color textSecondary = Color(0xFF475569);      // slate-600
  static const Color textMuted = Color(0xFF94A3B8);          // slate-400
  static const Color textHint = Color(0xFFCBD5E1);           // slate-300
  
  static const Color errorRed = Color(0xFFEF4444);
  static const Color successGreen = Color(0xFF22C55E);
  static const Color warningYellow = Color(0xFFF59E0B);
  
  static const Color divider = Color(0xFFF3F1ED);           // warm cream divider
  static const Color border = Color(0xFFE8E5DF);            // warm cream border

  // ─── Gradients ─────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryGreen, emerald400],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient heroGradient = LinearGradient(
    colors: [emerald50, Color(0xFFFEF3C7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient cardShimmer = LinearGradient(
    colors: [Color(0xFFFDFCF8), Color(0xFFE8E5DF), Color(0xFFFDFCF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient buttonGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cartHeaderGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // ─── Shadows ───────────────────────────────────────────
  static List<BoxShadow> get shadowSm => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> get shadowMd => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> get shadowLg => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> get shadowGreen => [
    BoxShadow(
      color: primaryGreen.withValues(alpha: 0.25),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get shadowSoft => [
    BoxShadow(
      color: const Color(0xFF8B7E6A).withValues(alpha: 0.08),
      blurRadius: 20,
      spreadRadius: -2,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get shadowCard => [
    BoxShadow(
      color: const Color(0xFF8B7E6A).withValues(alpha: 0.06),
      blurRadius: 16,
      spreadRadius: 0,
      offset: const Offset(0, 2),
    ),
  ];

  // ─── Border Radius ─────────────────────────────────────
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXL = 20.0;
  static const double radius2XL = 24.0;
  static const double radius3XL = 32.0;

  // ─── Light Theme ───────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryGreen,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        brightness: Brightness.light,
        primary: primaryGreen,
        secondary: accentOrange,
        surface: surfaceWhite,
        error: errorRed,
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32, fontWeight: FontWeight.w800, color: textPrimary, height: 1.2,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 28, fontWeight: FontWeight.w700, color: textPrimary, height: 1.2,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary, height: 1.3,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary, height: 1.3,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary,
        ),
        titleSmall: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w600, color: textSecondary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.normal, color: textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.normal, color: textSecondary,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.normal, color: textMuted,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: 0.5,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 10, fontWeight: FontWeight.w700, color: textMuted, letterSpacing: 1.2,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: const StadiumBorder(),
          elevation: 0,
          textStyle: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: const StadiumBorder(),
          side: const BorderSide(color: primaryGreen, width: 1.5),
          textStyle: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusXL),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusXL),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusXL),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusXL),
          borderSide: const BorderSide(color: errorRed),
        ),
        hintStyle: GoogleFonts.inter(color: textHint, fontSize: 15),
      ),
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius3XL),
          side: BorderSide(color: border.withValues(alpha: 0.4)),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceWhite,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.grey.shade50,
        selectedColor: primaryGreenLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
        side: BorderSide(color: border),
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}
