/// Lightweight localisation for the application UI.
///
/// English (`en`) and Arabic (`ar`, RTL) are supported. Strings resolve from
/// static tables so localisation is testable without code generation.
library;

import 'package:flutter/material.dart';

import 'strings_ar.dart';
import 'strings_en.dart';

/// Supported application locales.
const List<Locale> supportedLocales = [Locale('en'), Locale('ar')];

/// Human readable names for the locale picker.
const Map<String, String> localeDisplayNames = {
  'en': 'English',
  'ar': 'العربية',
};

/// Resolves localised strings.
abstract final class AppStrings {
  /// Strings for [languageCode], falling back to English.
  static Map<String, String> of(String languageCode) =>
      languageCode == 'ar' ? arStrings : enStrings;

  /// Resolves a single key, applying optional `{placeholder}` arguments.
  static String t(
    String languageCode,
    String key, {
    Map<String, String>? args,
  }) {
    final table = of(languageCode);
    var value = table[key] ?? enStrings[key] ?? key;
    if (args != null) {
      args.forEach((name, replacement) {
        value = value.replaceAll('{$name}', replacement);
      });
    }
    return value;
  }

  /// `true` when [languageCode] is right-to-left.
  static bool isRtl(String languageCode) => languageCode == 'ar';
}

/// Convenience accessor bound to the current [BuildContext] locale.
extension AppStringsContext on BuildContext {
  /// Current locale language code.
  String get languageCode => Localizations.localeOf(this).languageCode;

  /// Resolves a localised string.
  String tr(String key, {Map<String, String>? args}) =>
      AppStrings.t(languageCode, key, args: args);
}
