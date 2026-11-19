import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cv_portfolio_maker/core/design/portfolio_themes.dart';
import 'package:cv_portfolio_maker/core/theme/app_theme.dart';
import 'package:cv_portfolio_maker/core/theme/app_tokens.dart';
import 'package:cv_portfolio_maker/core/theme/surface_gradients.dart';
import 'package:cv_portfolio_maker/core/widgets/app_surfaces.dart';
import 'package:cv_portfolio_maker/features/portfolio/portfolio_theme.dart';

void main() {
  for (final dark in [false, true]) {
    final base = dark ? AppTheme.dark() : AppTheme.light();
    test(
      'all palettes keep graphite gradient stops and contrast, dark=$dark',
      () {
        for (final palette in portfolioThemes) {
          final themed = portfolioUiTheme(base, palette);
          expect(themed.colorScheme, base.colorScheme);
          expect(themed.textTheme, base.textTheme);
          final surfaces = themed.extension<SurfaceGradients>()!;
          expect(surfaces.hero, palette.surfaceGradient(base.brightness));
          expect(surfaces.card, surfaces.hero);
          for (final pair in [
            (
              palette.canvasGradient(base.brightness),
              AppGradients.canvas(base.brightness),
            ),
            (surfaces.hero, AppGradients.hero(base.brightness)),
          ]) {
            expect(pair.$1.stops, pair.$2.stops);
            for (var i = 0; i < pair.$1.colors.length; i++) {
              expect(
                pair.$1.colors[i].computeLuminance(),
                closeTo(pair.$2.colors[i].computeLuminance(), .004),
                reason: '${palette.id} stop $i must preserve text contrast',
              );
            }
          }
          if (palette != oceanTheme) {
            expect(
              surfaces.hero.colors,
              isNot(AppGradients.hero(base.brightness).colors),
            );
          }
        }
      },
    );

    testWidgets('cards and hero use each selected palette, dark=$dark', (
      tester,
    ) async {
      for (final palette in portfolioThemes) {
        final theme = portfolioUiTheme(base, palette);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Column(
                children: const [
                  AppGlassCard(child: Text('Project card')),
                  AppHeroSurface(child: Text('Profile card')),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final type in [AppGlassCard, AppHeroSurface]) {
          final decorations = tester
              .widgetList<DecoratedBox>(
                find.descendant(
                  of: find.byType(type),
                  matching: find.byType(DecoratedBox),
                ),
              )
              .map((box) => box.decoration)
              .whereType<BoxDecoration>();
          expect(
            decorations.any(
              (box) => box.gradient == palette.surfaceGradient(base.brightness),
            ),
            isTrue,
            reason: '${palette.id} must color $type',
          );
        }
        expect(tester.takeException(), isNull);
      }
    });
  }

  test('sky blue has its own stable palette identifier', () {
    expect(portfolioThemeById('sky'), skyTheme);
    expect(portfolioThemes.map((theme) => theme.id).toSet().length, 4);
  });
}
