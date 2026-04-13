import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ---------------------------------------------------------------------------
// Raw palette constants — used internally and as static fallbacks.
// These are light-mode values; dark-mode values live in OutalmaColors.dark.
// ---------------------------------------------------------------------------

abstract final class AppColors {
  // Brand
  static const primary = Color(0xFF1B3A4B);
  static const primaryLight = Color(0xFF2A5570);
  static const accent = Color(0xFF6FE8CC);
  static const accentLight = Color(0xFFB8F5E8);

  // Text
  static const primaryText = Color(0xFF0D1F2D);
  static const secondaryText = Color(0xFF5C7A8A);

  // Surfaces
  static const background = Color(0xFFF4F7F9);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFEDF2F5);

  // UI elements
  static const border = Color(0xFFCDD8DE);
  static const inputFill = Color(0xFFF4F7F9);

  // Card surface — warm white in light mode, distinct from grey background
  static const cardSurface = Color(0xFFFFFFFF);

  // Semantic
  static const success = Color(0xFF00A678);
  static const successAccent = Color(0x1A00A678);
  static const warning = Color(0xFFE8900A);
  static const error = Color(0xFFE03D3A);
  static const icons = Color(0xFF8AAAB8);
  static const shadow = Color(0x0D1B3A4B);
}

// ---------------------------------------------------------------------------
// ThemeExtension — injected by both light and dark ThemeData
// ---------------------------------------------------------------------------

class OutalmaColors extends ThemeExtension<OutalmaColors> {
  const OutalmaColors({
    required this.primary,
    required this.primaryLight,
    required this.accent,
    required this.accentLight,
    required this.primaryText,
    required this.secondaryText,
    required this.background,
    required this.surface,
    required this.cardSurface,
    required this.surfaceVariant,
    required this.border,
    required this.inputFill,
    required this.success,
    required this.successAccent,
    required this.warning,
    required this.error,
    required this.icons,
    required this.shadow,
  });

  final Color primary;
  final Color primaryLight;
  final Color accent;
  final Color accentLight;
  final Color primaryText;
  final Color secondaryText;
  final Color background;
  final Color surface;
  /// Slightly tinted surface for cards/containers in light mode.
  /// Use this instead of [surface] for card-like containers to ensure
  /// they visually separate from the scaffold background.
  final Color cardSurface;
  final Color surfaceVariant;
  final Color border;
  final Color inputFill;
  final Color success;
  final Color successAccent;
  final Color warning;
  final Color error;
  final Color icons;
  final Color shadow;

  /// Light palette — mirrors AppColors static values.
  static const light = OutalmaColors(
    primary: Color(0xFF1B3A4B),
    primaryLight: Color(0xFF2A5570),
    accent: Color(0xFF6FE8CC),
    accentLight: Color(0xFFB8F5E8),
    primaryText: Color(0xFF0D1F2D),
    secondaryText: Color(0xFF5C7A8A),
    background: Color(0xFFF4F7F9),
    surface: Color(0xFFFFFFFF),
    cardSurface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFEDF2F5),
    border: Color(0xFFCDD8DE),
    inputFill: Color(0xFFF4F7F9),
    success: Color(0xFF00A678),
    successAccent: Color(0x1A00A678),
    warning: Color(0xFFE8900A),
    error: Color(0xFFE03D3A),
    icons: Color(0xFF8AAAB8),
    shadow: Color(0x0D1B3A4B),
  );

  /// Dark palette — mint inverts with navy.
  static const dark = OutalmaColors(
    primary: Color(0xFF6FE8CC),
    primaryLight: Color(0xFF9FF2DF),
    accent: Color(0xFF1B3A4B),
    accentLight: Color(0xFF2A5570),
    primaryText: Color(0xFFE2EEF4),
    secondaryText: Color(0xFF7AA3B5),
    background: Color(0xFF0A1A24),
    surface: Color(0xFF122230),
    cardSurface: Color(0xFF162838),
    surfaceVariant: Color(0xFF1A3040),
    border: Color(0xFF2A4555),
    inputFill: Color(0xFF0F1E28),
    success: Color(0xFF2DD17A),
    successAccent: Color(0x1A2DD17A),
    warning: Color(0xFFFFBB33),
    error: Color(0xFFFF6B68),
    icons: Color(0xFF5A8090),
    shadow: Color(0x1A000000),
  );

  @override
  OutalmaColors copyWith({
    Color? primary,
    Color? primaryLight,
    Color? accent,
    Color? accentLight,
    Color? primaryText,
    Color? secondaryText,
    Color? background,
    Color? surface,
    Color? cardSurface,
    Color? surfaceVariant,
    Color? border,
    Color? inputFill,
    Color? success,
    Color? successAccent,
    Color? warning,
    Color? error,
    Color? icons,
    Color? shadow,
  }) {
    return OutalmaColors(
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      accent: accent ?? this.accent,
      accentLight: accentLight ?? this.accentLight,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      cardSurface: cardSurface ?? this.cardSurface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      border: border ?? this.border,
      inputFill: inputFill ?? this.inputFill,
      success: success ?? this.success,
      successAccent: successAccent ?? this.successAccent,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      icons: icons ?? this.icons,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  OutalmaColors lerp(OutalmaColors? other, double t) {
    if (other == null) return this;
    return OutalmaColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentLight: Color.lerp(accentLight, other.accentLight, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      border: Color.lerp(border, other.border, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      success: Color.lerp(success, other.success, t)!,
      successAccent: Color.lerp(successAccent, other.successAccent, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      icons: Color.lerp(icons, other.icons, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

// ---------------------------------------------------------------------------
// BuildContext convenience extension
// ---------------------------------------------------------------------------

extension OutalmaThemeX on BuildContext {
  OutalmaColors get oc => Theme.of(this).extension<OutalmaColors>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

// ---------------------------------------------------------------------------
// AppTheme factory
// ---------------------------------------------------------------------------

abstract final class AppTheme {
  static ThemeData light() {
    const oc = OutalmaColors.light;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.surface,
      secondary: AppColors.accent,
      onSecondary: AppColors.primaryText,
      surface: AppColors.surface,
      onSurface: AppColors.primaryText,
      error: AppColors.error,
      onError: AppColors.surface,
    );

    final textTheme = _buildTextTheme(oc);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      extensions: const [OutalmaColors.light],
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
        color: AppColors.cardSurface,
        elevation: 2,
        shadowColor: AppColors.shadow,
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
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.icons,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.secondaryText,
        indicatorColor: AppColors.primary,
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  static ThemeData dark() {
    const oc = OutalmaColors.dark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6FE8CC),
      brightness: Brightness.dark,
      primary: oc.primary,
      onPrimary: oc.background,
      secondary: oc.accent,
      onSecondary: oc.primaryText,
      surface: oc.surface,
      onSurface: oc.primaryText,
      error: oc.error,
      onError: oc.background,
    );

    final textTheme = _buildTextTheme(oc);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      extensions: const [OutalmaColors.dark],
      scaffoldBackgroundColor: oc.background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: oc.surface,
        foregroundColor: oc.primaryText,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          color: oc.primaryText,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: oc.primaryText),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: oc.inputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.inter(
          color: oc.secondaryText,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: oc.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: oc.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: oc.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: oc.error, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: oc.primary,
          foregroundColor: oc.background,
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
          foregroundColor: oc.primary,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: oc.primary),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: oc.primary,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: oc.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: oc.border),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: oc.border,
        thickness: 1,
        space: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: oc.surfaceVariant,
        contentTextStyle: GoogleFonts.inter(
          color: oc.primaryText,
          fontSize: 14,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: oc.surface,
        selectedItemColor: oc.primary,
        unselectedItemColor: oc.icons,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: oc.primary,
        unselectedLabelColor: oc.secondaryText,
        indicatorColor: oc.primary,
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme(OutalmaColors oc) {
    return TextTheme(
      displayLarge: GoogleFonts.inter(
          fontSize: 64, fontWeight: FontWeight.w600, color: oc.primaryText),
      displayMedium: GoogleFonts.inter(
          fontSize: 44, fontWeight: FontWeight.w600, color: oc.primaryText),
      displaySmall: GoogleFonts.inter(
          fontSize: 36, fontWeight: FontWeight.w600, color: oc.primaryText),
      headlineLarge: GoogleFonts.inter(
          fontSize: 28, fontWeight: FontWeight.bold, color: oc.primaryText),
      headlineMedium: GoogleFonts.inter(
          fontSize: 24, fontWeight: FontWeight.bold, color: oc.primaryText),
      headlineSmall: GoogleFonts.inter(
          fontSize: 20, fontWeight: FontWeight.bold, color: oc.primaryText),
      titleLarge: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.bold, color: oc.primaryText),
      titleMedium: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w500, color: oc.primaryText),
      titleSmall: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w500, color: oc.primaryText),
      labelLarge: GoogleFonts.inter(
          fontSize: 15, fontWeight: FontWeight.w500, color: oc.secondaryText),
      labelMedium: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w500, color: oc.secondaryText),
      labelSmall: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w500, color: oc.secondaryText),
      bodyLarge: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w400, color: oc.primaryText),
      bodyMedium: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w400, color: oc.primaryText),
      bodySmall: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w400, color: oc.secondaryText),
    );
  }
}
