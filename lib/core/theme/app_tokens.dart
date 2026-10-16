/// Design tokens for the application chrome.
library;

import 'package:flutter/material.dart';

/// Brand colour palette used by the app chrome (not user documents).
abstract final class AppPalette {
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryDark = Color(0xFF3730A3);
  static const Color accent = Color(0xFF06B6D4);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  static const Color lightBackground = Color(0xFFF6F7FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF111827);
  static const Color lightTextSecondary = Color(0xFF4B5563);

  static const Color darkBackground = Color(0xFF0B1120);
  static const Color darkSurface = Color(0xFF151C2C);
  static const Color darkTextPrimary = Color(0xFFF3F4F6);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);

  static const Color darkBorder = Color(0xFF233047);
  static const Color lightBorder = Color(0xFFE5E7EB);
}

/// Standard spacing scale, in logical pixels.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Standard corner radii.
abstract final class AppRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 18;
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
