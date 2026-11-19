/// Lightweight localisation for the application UI.
///
/// English (`en`) and Arabic (`ar`, RTL) are supported. Strings resolve from
/// static tables so localisation is testable without code generation.
library;

import 'package:flutter/material.dart';

import 'strings_ar.dart';
import 'strings_en.dart';
import 'ui_strings_ar.dart';

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

  static final _uiArabic = <String, String>{
    for (final entry in enStrings.entries)
      if (arStrings.containsKey(entry.key)) entry.value: arStrings[entry.key]!,
    ...uiArabicStrings,
  };

  static String ui(String languageCode, String text) {
    if (languageCode != 'ar') return text;
    if (text.endsWith(' (existing font)')) {
      return '${text.substring(0, text.length - 16)} (${ui(languageCode, 'existing font')})';
    }
    if (RegExp(r'^[0-9.+ -]+ ?pt$').hasMatch(text)) {
      return text.replaceFirst(RegExp(r' ?pt$'), ' \u0646\u0642\u0637\u0629');
    }
    if (RegExp(r'^[0-9.+ -]+ ?mm$').hasMatch(text)) {
      return text.replaceFirst(RegExp(r' ?mm$'), ' \u0645\u0645');
    }
    final translated = _uiArabic[text];
    if (translated != null) return translated;
    for (final prefix in ['Icon: ', 'Decrease ', 'Increase ']) {
      if (text.startsWith(prefix)) {
        return '${_uiArabic[prefix] ?? prefix}${ui(languageCode, text.substring(prefix.length))}';
      }
    }
    return text;
  }

  /// `true` when [languageCode] is right-to-left.
  static bool isRtl(String languageCode) => languageCode == 'ar';
}

/// Convenience accessor bound to the current [BuildContext] locale.
extension AppStringsContext on BuildContext {
  /// Current locale language code.
  String get languageCode => Localizations.localeOf(this).languageCode;

  String ui(String text) => AppStrings.ui(languageCode, text);

  /// Resolves a localised string.
  String tr(String key, {Map<String, String>? args}) =>
      AppStrings.t(languageCode, key, args: args);
}
