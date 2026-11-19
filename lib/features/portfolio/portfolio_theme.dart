import 'package:flutter/material.dart';

import '../../core/design/portfolio_themes.dart';

/// Palette selection changes the page canvas only. Content, controls and cards
/// keep the application's accessible foreground and surface colors.
ThemeData portfolioUiTheme(ThemeData base, PortfolioTheme palette) => base;

class PortfolioBackdrop extends StatelessWidget {
  const PortfolioBackdrop({
    super.key,
    required this.palette,
    required this.child,
  });
  final PortfolioTheme palette;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surface;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      key: ValueKey('portfolio-background:${palette.id}'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(base, palette.heroStart, dark ? .55 : .14)!,
            Color.lerp(base, palette.heroEnd, dark ? .40 : .10)!,
          ],
        ),
      ),
      child: SizedBox.expand(child: child),
    );
  }
}
