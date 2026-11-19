/// Builds the shared Material 3 [ThemeData] for light and dark modes.
library;

import 'package:flutter/material.dart';

import 'app_tokens.dart';
import '../widgets/app_motion.dart';

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
          primary: isDark ? AppPalette.ice : AppPalette.primary,
          onPrimary: isDark ? AppPalette.primaryDark : Colors.white,
          primaryContainer: isDark
              ? const Color(0xFF3A424B)
              : const Color(0xFFE1F0F8),
          onPrimaryContainer: isDark ? AppPalette.ice : AppPalette.primary,
          secondary: isDark ? const Color(0xFF7DD3FC) : AppPalette.primaryDark,
          onSecondary: isDark ? const Color(0xFF082B3C) : Colors.white,
          onSurface: textPrimary,
          onSurfaceVariant: textSecondary,
          outline: isDark ? const Color(0xFF98A7B4) : const Color(0xFF6B8292),
          outlineVariant: border,
          surfaceContainerHighest: isDark
              ? const Color(0xFF626C76)
              : const Color(0xFFE7F1F7),
          error: isDark ? const Color(0xFFFFB4AB) : const Color(0xFFB91C1C),
          onError: isDark ? const Color(0xFF690005) : Colors.white,
          surface: isDark ? AppPalette.darkSurface : AppPalette.lightSurface,
        );

    final textTheme = _textTheme(textPrimary, textSecondary).apply(
      fontFamily: AppTypography.english,
      fontFamilyFallback: AppTypography.fallback,
    );
    RoundedRectangleBorder round(double r) =>
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTypography.english,
      fontFamilyFallback: AppTypography.fallback,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: isDark
          ? AppPalette.darkBackground
          : AppPalette.lightBackground,
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: AppPageTransitionsBuilder(),
          TargetPlatform.iOS: AppPageTransitionsBuilder(),
          TargetPlatform.macOS: AppPageTransitionsBuilder(),
          TargetPlatform.windows: AppPageTransitionsBuilder(),
          TargetPlatform.linux: AppPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        titleSpacing: AppSpacing.lg,
        surfaceTintColor: Colors.transparent,
        backgroundColor: scheme.surface.withValues(alpha: .88),
        foregroundColor: textPrimary,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shadowColor: const Color(0xFF4586AB).withValues(alpha: .12),
        color: scheme.surface.withValues(alpha: .88),
        shape: round(AppRadii.lg).copyWith(
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: .16)
                : Colors.white.withValues(alpha: .9),
          ),
        ),
        margin: const EdgeInsets.only(bottom: AppSpacing.compact),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        errorMaxLines: 3,
        helperMaxLines: 3,
        filled: true,
        fillColor: isDark
            ? const Color(0xFF515C66)
            : Colors.white.withValues(alpha: .75),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppPalette.danger),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.accent,
          foregroundColor: AppPalette.primaryDark,
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md - 2,
          ),
          shape: round(AppRadii.md),
          textStyle: textTheme.labelLarge,
          animationDuration: AppMotion.quick,
        ).copyWith(foregroundBuilder: AppMotion.button),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md - 2,
          ),
          shape: round(AppRadii.md),
          side: BorderSide(color: border),
          animationDuration: AppMotion.quick,
        ).copyWith(foregroundBuilder: AppMotion.button),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.compact,
          ),
          shape: round(AppRadii.md),
          animationDuration: AppMotion.quick,
        ).copyWith(foregroundBuilder: AppMotion.button),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: round(AppRadii.md),
          animationDuration: AppMotion.quick,
        ).copyWith(foregroundBuilder: AppMotion.button),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: round(AppRadii.md),
        ).copyWith(foregroundBuilder: AppMotion.button),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        elevation: 0,
        backgroundColor: scheme.surface.withValues(alpha: .94),
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppPalette.accent,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppPalette.primaryDark
                : textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: AppTypography.english,
            fontSize: 12,
            height: 1.4,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? (isDark ? AppPalette.ice : AppPalette.primaryDark)
                : textSecondary,
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppPalette.accent,
        linearTrackColor: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(8),
        thickness: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered) ? 8 : 5,
        ),
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
      dialogTheme: DialogThemeData(
        shape: round(AppRadii.xl),
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: round(AppRadii.xl).copyWith(side: BorderSide(color: border)),
        backgroundColor: isDark
            ? AppPalette.darkSurface
            : AppPalette.lightSurface,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        minVerticalPadding: AppSpacing.compact,
        shape: round(AppRadii.md),
        iconColor: textSecondary,
      ),
    );
  }

  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      displaySmall: TextStyle(
        fontSize: 32,
        fontWeight: AppTypography.semibold,
        color: primary,
        height: 1.15,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: AppTypography.semibold,
        color: primary,
        height: 1.2,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: AppTypography.semibold,
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
