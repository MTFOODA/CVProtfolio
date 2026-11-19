/// Design tokens for the application chrome.
library;

import 'package:flutter/material.dart';

/// Brand colour palette used by the app chrome (not user documents).
abstract final class AppPalette {
  static const Color primary = Color(0xFF286D96);
  static const Color primaryDark = Color(0xFF202329);
  static const Color accent = Color(0xFF6CABDD);
  static const Color ice = Color(0xFFA9DDF5);
  static const Color silver = Color(0xFF777D86);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  static const Color lightBackground = Color(0xFFF1F7FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF17212C);
  static const Color lightTextSecondary = Color(0xFF506879);

  static const Color darkBackground = Color(0xFF343A40);
  static const Color darkSurface = Color(0xFF49515A);
  static const Color darkTextPrimary = Color(0xFFF3F4F6);
  static const Color darkTextSecondary = Color(0xFFE0E9EF);

  static const Color darkBorder = Color(0xFF71808B);
  static const Color lightBorder = Color(0xFFD5E5EF);
}

abstract final class AppBreakpoints {
  static const double compact = 600;
  static const double desktop = 1100;
  static const double railWidth = 248;
}

abstract final class AppTypography {
  static const english = 'inter';
  static const arabic = 'tajawal';
  static const fallback = [arabic, 'notoNaskhArabic'];
  static const regular = FontWeight.w400;
  static const medium = FontWeight.w500;
  static const semibold = FontWeight.w600;
}

abstract final class AppGradients {
  static const signature = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppPalette.primaryDark,
      AppPalette.silver,
      AppPalette.ice,
      AppPalette.accent,
    ],
    stops: [0, .36, .72, 1],
  );
  static LinearGradient canvas(Brightness brightness) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: brightness == Brightness.dark
        ? const [
                Color(0xFF343A40),
                Color(0xFF49515A),
                Color(0xFF626C76),
                Color(0xFF87929D),
              ]
              .map((color) => Color.alphaBlend(const Color(0xC0343A40), color))
              .toList()
        : const [
                Color(0xFFFFFFFF),
                Color(0xFFEDF7FB),
                Color(0xFFD9EDF7),
                AppPalette.ice,
                AppPalette.accent,
              ]
              .map((color) => Color.alphaBlend(const Color(0xD9FFFFFF), color))
              .toList(),
    stops: brightness == Brightness.dark
        ? const [0, .44, .72, 1]
        : const [0, .38, .62, .82, 1],
  );
  static LinearGradient hero(Brightness brightness) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: brightness == Brightness.dark
        ? const [
            Color(0xFF343A40),
            Color(0xFF49515A),
            Color(0xFF56616C),
            Color(0xFF456079),
          ]
        : const [
            Colors.white,
            Color(0xFFE7F4FA),
            AppPalette.ice,
            Color(0xFF9ED3EF),
          ],
    stops: const [0, .38, .78, 1],
  );
}

abstract final class AppShadows {
  static List<BoxShadow> surface(Brightness brightness) => [
    BoxShadow(
      color:
          (brightness == Brightness.dark
                  ? Colors.black
                  : const Color(0xFF4586AB))
              .withValues(alpha: .10),
      blurRadius: 28,
      offset: const Offset(0, 10),
    ),
  ];
}

/// Standard spacing scale, in logical pixels.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double compact = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double contentWidth = 1120;
  static const double formWidth = 760;

  static EdgeInsets pagePadding(BuildContext context) => EdgeInsets.all(
    MediaQuery.sizeOf(context).width < AppBreakpoints.compact ? md : xl,
  );
}

/// Standard corner radii.
abstract final class AppRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 22;
  static const double xl = 28;
}

/// Semantic status colours resolved for a brightness.
extension AppStatusColors on BuildContext {
  Color get statusSuccess => Theme.of(this).brightness == Brightness.dark
      ? AppPalette.success
      : const Color(0xFF059669);

  Color get statusWarning => Theme.of(this).brightness == Brightness.dark
      ? AppPalette.warning
      : const Color(0xFFD97706);

  Color get statusDanger => Theme.of(this).colorScheme.error;
}
