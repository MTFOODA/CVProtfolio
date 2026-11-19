/// Curated portfolio colour themes.
///
/// Themes color the page canvas and card surfaces. Each portfolio reads its associated
/// CV's saved content and keeps independent presentation and sharing settings.
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// A named portfolio theme.
class PortfolioTheme {
  const PortfolioTheme({
    required this.id,
    required this.labelKey,
    required this.heroStart,
    required this.heroEnd,
    required this.accent,
    required this.onHero,
  });

  /// Stable identifier persisted with the document design.
  final String id;

  /// Localisation key for the display name.
  final String labelKey;

  /// Gradient start colour for the hero section.
  final Color heroStart;

  /// Gradient end colour for the hero section.
  final Color heroEnd;

  /// Swatch accent retained for palette previews.
  final Color accent;

  /// Foreground colour used on top of the hero gradient.
  final Color onHero;

  LinearGradient get heroGradient => LinearGradient(
    colors: [heroStart, heroEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Every palette follows the graphite theme's stops and brightness. Matching
  /// luminance keeps text contrast stable when the surface hue changes.
  LinearGradient canvasGradient(Brightness brightness) =>
      _tintGradient(AppGradients.canvas(brightness), brightness);

  LinearGradient surfaceGradient(Brightness brightness) =>
      _tintGradient(AppGradients.hero(brightness), brightness);

  LinearGradient _tintGradient(LinearGradient source, Brightness brightness) =>
      id == 'ocean'
      ? source
      : LinearGradient(
          begin: source.begin,
          end: source.end,
          stops: source.stops,
          colors: [for (final color in source.colors) _tint(color, brightness)],
        );

  Color _tint(Color original, Brightness brightness) {
    final hue = HSLColor.fromColor(accent).hue;
    final saturation = brightness == Brightness.dark ? .34 : .58;
    final luminance = original.computeLuminance();
    if (luminance == 0 || luminance == 1) return original;
    var low = 0.0;
    var high = 1.0;
    var closest = original;
    var distance = double.infinity;
    for (var i = 0; i < 18; i++) {
      final middle = (low + high) / 2;
      final candidate = HSLColor.fromAHSL(1, hue, saturation, middle).toColor();
      final difference = (candidate.computeLuminance() - luminance).abs();
      if (difference < distance) {
        closest = candidate;
        distance = difference;
      }
      if (candidate.computeLuminance() < luminance) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return closest.withValues(alpha: original.a);
  }
}

/// Ocean: graphite and sky blue — the default brand palette.
const PortfolioTheme oceanTheme = PortfolioTheme(
  id: 'ocean',
  labelKey: 'themeOcean',
  heroStart: AppPalette.primaryDark,
  heroEnd: AppPalette.silver,
  accent: AppPalette.primary,
  onHero: Color(0xFFF8FAFC),
);

/// Forest: evergreen to moss.
const PortfolioTheme forestTheme = PortfolioTheme(
  id: 'forest',
  labelKey: 'themeForest',
  heroStart: Color(0xFF064E3B),
  heroEnd: Color(0xFF3F6212),
  accent: Color(0xFF047857),
  onHero: Color(0xFFF0FDF4),
);

/// Rose: plum to blush.
const PortfolioTheme roseTheme = PortfolioTheme(
  id: 'rose',
  labelKey: 'themeRose',
  heroStart: Color(0xFF4C1D95),
  heroEnd: Color(0xFFBE185D),
  accent: Color(0xFFBE185D),
  onHero: Color(0xFFFFF1F2),
);

const PortfolioTheme skyTheme = PortfolioTheme(
  id: 'sky',
  labelKey: 'themeSky',
  heroStart: Color(0xFF23475D),
  heroEnd: AppPalette.ice,
  accent: Color(0xFF38BDF8),
  onHero: Color(0xFFF0F9FF),
);

/// All built-in portfolio themes.
const List<PortfolioTheme> portfolioThemes = [
  oceanTheme,
  forestTheme,
  roseTheme,
  skyTheme,
];

/// Resolves a theme id, falling back to [oceanTheme].
PortfolioTheme portfolioThemeById(String? id) {
  for (final theme in portfolioThemes) {
    if (theme.id == id) return theme;
  }
  return oceanTheme;
}
