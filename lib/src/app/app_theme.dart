import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Outalma design tokens — extracted from FlutterFlow reference.
abstract final class AppColors {
  static const primary = Color(0xFF368EFF);
  static const primaryText = Color(0xFF242424);
  static const secondaryText = Color(0xFF808284);
  static const background = Color(0xFFF8F8F8);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFDEDEDE);
  static const inputFill = Color(0xFFF8F8F8);
  static const success = Color(0xFF00A556);
  static const successAccent = Color(0x1E00A556);
  static const warning = Color(0xFFFFA600);
  static const error = Color(0xFFF04542);
  static const icons = Color(0xFFAAADB0);
  static const shadow = Color(0x0B000000);
}

abstract final class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.surface,
      secondary: const Color(0xFFEFEFEF),
      onSecondary: AppColors.primaryText,
      surface: AppColors.surface,
      onSurface: AppColors.primaryText,
      error: AppColors.error,
      onError: AppColors.surface,
    );

    final textTheme = _buildTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.primaryText,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: AppColors.primaryText),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.inter(
          color: AppColors.secondaryText,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: AppColors.primary),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: AppColors.primaryText,
        contentTextStyle: GoogleFonts.inter(
          color: AppColors.surface,
          fontSize: 14,
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme() {
    return TextTheme(
      // Display
      displayLarge: GoogleFonts.inter(
          fontSize: 64, fontWeight: FontWeight.w600, color: AppColors.primaryText),
      displayMedium: GoogleFonts.inter(
          fontSize: 44, fontWeight: FontWeight.w600, color: AppColors.primaryText),
      displaySmall: GoogleFonts.inter(
          fontSize: 36, fontWeight: FontWeight.w600, color: AppColors.primaryText),
      // Headline
      headlineLarge: GoogleFonts.inter(
          fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryText),
      headlineMedium: GoogleFonts.inter(
          fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryText),
      headlineSmall: GoogleFonts.inter(
          fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryText),
      // Title
      titleLarge: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryText),
      titleMedium: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.primaryText),
      titleSmall: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.primaryText),
      // Label
      labelLarge: GoogleFonts.inter(
          fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.secondaryText),
      labelMedium: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.secondaryText),
      labelSmall: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.secondaryText),
      // Body
      bodyLarge: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.primaryText),
      bodyMedium: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.primaryText),
      bodySmall: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.secondaryText),
    );
  }
}
