/// Builds the shared Material 3 [ThemeData] for light and dark modes.
library;

import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Application theme factory.
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final border = isDark ? AppPalette.darkBorder : AppPalette.lightBorder;
    final textPrimary = isDark
        ? AppPalette.darkTextPrimary
        : AppPalette.lightTextPrimary;
    final textSecondary = isDark
        ? AppPalette.darkTextSecondary
        : AppPalette.lightTextSecondary;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppPalette.primary,
          brightness: brightness,
        ).copyWith(
          primary: AppPalette.primary,
          secondary: AppPalette.accent,
          error: AppPalette.danger,
          surface: isDark ? AppPalette.darkSurface : AppPalette.lightSurface,
        );

    final textTheme = _textTheme(textPrimary, textSecondary);
    RoundedRectangleBorder round(double r) =>
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? AppPalette.darkBackground
          : AppPalette.lightBackground,
      textTheme: textTheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: isDark
            ? AppPalette.darkSurface
            : AppPalette.lightSurface,
        foregroundColor: textPrimary,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? AppPalette.darkSurface : AppPalette.lightSurface,
        shape: round(AppRadii.lg).copyWith(side: BorderSide(color: border)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1B2434) : const Color(0xFFF3F4F6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppPalette.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppPalette.danger),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md - 2,
          ),
          shape: round(AppRadii.md),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md - 2,
          ),
          shape: round(AppRadii.md),
          side: BorderSide(color: isDark ? border : const Color(0xFFD1D5DB)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: round(AppRadii.md)),
      ),
      chipTheme: ChipThemeData(
        shape: round(AppRadii.sm),
        side: BorderSide.none,
        labelStyle: textTheme.labelMedium,
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: round(AppRadii.md),
      ),
      dialogTheme: DialogThemeData(shape: round(AppRadii.lg)),
      bottomSheetTheme: BottomSheetThemeData(
        shape: round(AppRadii.xl).copyWith(side: BorderSide(color: border)),
        backgroundColor: isDark
            ? AppPalette.darkSurface
            : AppPalette.lightSurface,
      ),
      listTileTheme: ListTileThemeData(
        shape: round(AppRadii.md),
        iconColor: textSecondary,
      ),
    );
  }

  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      displaySmall: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: primary,
        height: 1.15,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: primary,
        height: 1.2,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: primary, height: 1.5),
      bodyMedium: TextStyle(fontSize: 14, color: primary, height: 1.5),
      bodySmall: TextStyle(fontSize: 12.5, color: secondary, height: 1.45),
      labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
      labelSmall: TextStyle(fontSize: 11, color: secondary),
    );
  }
}
