import 'package:flutter/material.dart';

/// Optional surface decoration; foreground colors remain owned by ThemeData.
class SurfaceGradients extends ThemeExtension<SurfaceGradients> {
  const SurfaceGradients({required this.card, required this.hero});
  final LinearGradient card;
  final LinearGradient hero;

  @override
  SurfaceGradients copyWith({LinearGradient? card, LinearGradient? hero}) =>
      SurfaceGradients(card: card ?? this.card, hero: hero ?? this.hero);

  @override
  SurfaceGradients lerp(covariant SurfaceGradients? other, double t) =>
      other == null
      ? this
      : SurfaceGradients(
          card: LinearGradient.lerp(card, other.card, t)!,
          hero: LinearGradient.lerp(hero, other.hero, t)!,
        );
}
