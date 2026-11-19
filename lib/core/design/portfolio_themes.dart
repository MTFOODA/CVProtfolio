/// Curated portfolio colour themes.
///
/// These are *presentation* palettes only: switching a theme changes colours,
/// never content. The underlying data always comes from the same [UserProfile]
/// the CV builder writes to, so a CV edit is immediately reflected in the
/// portfolio.
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

  /// Accent colour used for chips, links and section headings.
  final Color accent;

  /// Foreground colour used on top of the hero gradient.
  final Color onHero;

  LinearGradient get heroGradient => LinearGradient(
    colors: [heroStart, heroEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
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

/// All built-in portfolio themes.
const List<PortfolioTheme> portfolioThemes = [
  oceanTheme,
  forestTheme,
  roseTheme,
];

/// Resolves a theme id, falling back to [oceanTheme].
PortfolioTheme portfolioThemeById(String? id) {
  for (final theme in portfolioThemes) {
    if (theme.id == id) return theme;
  }
  return oceanTheme;
}
