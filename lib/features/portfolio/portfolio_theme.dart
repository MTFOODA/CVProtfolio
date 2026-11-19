import 'package:flutter/material.dart';

import '../../core/design/portfolio_themes.dart';
import '../../core/theme/surface_gradients.dart';

/// Only surface decoration changes; text and controls keep their foregrounds.
ThemeData portfolioUiTheme(ThemeData base, PortfolioTheme palette) =>
    base.copyWith(
      extensions: [
        ...base.extensions.values.where(
          (extension) => extension is! SurfaceGradients,
        ),
        SurfaceGradients(
          card: palette.surfaceGradient(base.brightness),
          hero: palette.surfaceGradient(base.brightness),
        ),
      ],
    );

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
    return DecoratedBox(
      key: ValueKey('portfolio-background:${palette.id}'),
      decoration: BoxDecoration(
        gradient: palette.canvasGradient(Theme.of(context).brightness),
      ),
      child: SizedBox.expand(child: child),
    );
  }
}
