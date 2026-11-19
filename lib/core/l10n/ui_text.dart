import 'package:flutter/material.dart';

import 'app_strings.dart';
import '../theme/app_tokens.dart';

/// Localises UI copy while keeping saved profile/document content untouched.
/// Const callers remain const; locale changes rebuild through Localizations.
class UiText extends StatelessWidget {
  const UiText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.textDirection,
    this.textWidthBasis,
    this.semanticsLabel,
    this.strutStyle,
    this.locale,
    this.textScaler,
    this.selectionColor,
    this.textHeightBehavior,
  });
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final TextDirection? textDirection;
  final TextWidthBasis? textWidthBasis;
  final String? semanticsLabel;
  final StrutStyle? strutStyle;
  final Locale? locale;
  final TextScaler? textScaler;
  final Color? selectionColor;
  final TextHeightBehavior? textHeightBehavior;
  @override
  Widget build(BuildContext context) => Text(
    context.ui(data),
    style: (style ?? const TextStyle()).copyWith(
      fontFamily:
          style?.fontFamily ??
          (context.languageCode == 'ar' ? AppTypography.arabic : null),
      fontFamilyFallback: style?.fontFamilyFallback ?? AppTypography.fallback,
    ),
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: overflow,
    softWrap: softWrap,
    textDirection: textDirection,
    textWidthBasis: textWidthBasis,
    semanticsLabel: semanticsLabel == null ? null : context.ui(semanticsLabel!),
    strutStyle: strutStyle,
    locale: locale,
    textScaler: textScaler,
    selectionColor: selectionColor,
    textHeightBehavior: textHeightBehavior,
  );
}
