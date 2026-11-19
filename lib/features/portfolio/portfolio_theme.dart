import 'package:flutter/material.dart';

import '../../core/design/portfolio_themes.dart';
import '../../core/theme/app_tokens.dart';

ThemeData portfolioUiTheme(ThemeData base, PortfolioTheme palette) {
  final accent = base.brightness == Brightness.dark
      ? Color.lerp(palette.accent, Colors.white, .70)!
      : palette.accent;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: accent,
        brightness: base.brightness,
      ).copyWith(
        primary: accent,
        surface: base.colorScheme.surface,
        onSurface: base.colorScheme.onSurface,
      );
  return base.copyWith(
    colorScheme: scheme,
    navigationBarTheme: base.navigationBarTheme.copyWith(
      indicatorColor: scheme.primaryContainer,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? accent
              : base.colorScheme.onSurfaceVariant,
          size: 23,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? accent
              : base.colorScheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
        ),
      ),
    ),
    scaffoldBackgroundColor: base.scaffoldBackgroundColor,
    textTheme: base.textTheme.apply(
      bodyColor: base.colorScheme.onSurface,
      displayColor: base.colorScheme.onSurface,
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: base.colorScheme.surface.withValues(alpha: .88),
      foregroundColor: base.colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: base.filledButtonTheme.style?.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? null
              : (palette.id == 'ocean' ? AppPalette.accent : accent),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? null
              : (base.brightness == Brightness.dark || palette.id == 'ocean'
                    ? const Color(0xFF17232B)
                    : Colors.white),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: base.outlinedButtonTheme.style?.copyWith(
        foregroundColor: WidgetStatePropertyAll(base.colorScheme.onSurface),
        side: WidgetStatePropertyAll(
          BorderSide(color: base.colorScheme.outlineVariant),
        ),
      ),
    ),
  );
}
