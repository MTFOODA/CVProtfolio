import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/surface_gradients.dart';
import 'app_motion.dart';

/// Shared geometric canvas. Decorative layers never receive input or semantics.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: AppMotion.reduced(context) ? Duration.zero : AppMotion.lighting,
    decoration: BoxDecoration(
      gradient: AppGradients.canvas(Theme.of(context).brightness),
    ),
    child: CustomPaint(
      painter: _GeometryPainter(Theme.of(context).brightness),
      child: child,
    ),
  );
}

class AppLoading extends StatelessWidget {
  const AppLoading({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppSpacing.formWidth),
      child: Padding(
        padding: AppSpacing.pagePadding(context),
        child: const AppSkeleton(),
      ),
    ),
  );
}

class _GeometryPainter extends CustomPainter {
  const _GeometryPainter(this.brightness);
  final Brightness brightness;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      size.width * .58,
      -size.height * .18,
      size.width * .64,
      size.height * .70,
    );
    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.rotate(-.20);
    final shape = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: rect.width,
        height: rect.height,
      ),
      const Radius.circular(90),
    );
    canvas.drawRRect(
      shape,
      Paint()
        ..color = AppPalette.ice.withValues(
          alpha: brightness == Brightness.dark ? .045 : .14,
        ),
    );
    canvas.drawRRect(
      shape,
      Paint()
        ..color = Colors.white.withValues(alpha: .16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.restore();
    canvas.drawCircle(
      Offset(size.width * .12, size.height * .94),
      size.width * .26,
      Paint()..color = AppPalette.silver.withValues(alpha: .035),
    );
  }

  @override
  bool shouldRepaint(_GeometryPainter oldDelegate) =>
      oldDelegate.brightness != brightness;
}

/// Reuses the Material Card contract so menus, semantics and gestures survive.
class AppGlassCard extends StatelessWidget {
  const AppGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin = EdgeInsets.zero,
    this.blur = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final bool blur;
  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    final gradient = Theme.of(context).extension<SurfaceGradients>()?.card;
    final surface = gradient == null
        ? content
        : DecoratedBox(
            decoration: BoxDecoration(gradient: gradient),
            child: content,
          );
    return Card(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      child: blur && !AppMotion.reduced(context)
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: surface,
            )
          : surface,
    );
  }
}

/// Scroll-linked decoration moves, while text and hit targets remain stable.
class AppHeroSurface extends StatefulWidget {
  const AppHeroSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  State<AppHeroSurface> createState() => _AppHeroSurfaceState();
}

class _AppHeroSurfaceState extends State<AppHeroSurface> {
  ScrollPosition? _scroll;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scroll = Scrollable.maybeOf(context)?.position;
    if (scroll != _scroll) {
      _scroll?.removeListener(_change);
      _scroll = scroll;
      _scroll?.addListener(_change);
    }
  }

  void _change() {
    if (mounted && !AppMotion.reduced(context)) setState(() {});
  }

  @override
  void dispose() {
    _scroll?.removeListener(_change);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppRadii.xl),
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient:
            Theme.of(context).extension<SurfaceGradients>()?.hero ??
            AppGradients.hero(Theme.of(context).brightness),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: Transform.translate(
                  offset: Offset(
                    0,
                    AppMotion.reduced(context)
                        ? 0
                        : ((_scroll?.hasPixels ?? false)
                                  ? _scroll!.pixels * .10
                                  : 0)
                              .clamp(-24, 24)
                              .toDouble(),
                  ),
                  child: CustomPaint(
                    painter: _GeometryPainter(Theme.of(context).brightness),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: widget.padding,
            child: Builder(
              builder: (context) {
                final base = Theme.of(context);
                final foreground = base.colorScheme.onSurface;
                return Theme(
                  data: base.copyWith(
                    colorScheme: base.colorScheme.copyWith(
                      onSurfaceVariant: foreground,
                    ),
                    textTheme: base.textTheme.apply(
                      bodyColor: foreground,
                      displayColor: foreground,
                    ),
                    outlinedButtonTheme: OutlinedButtonThemeData(
                      style: base.outlinedButtonTheme.style?.copyWith(
                        foregroundColor: WidgetStatePropertyAll(foreground),
                      ),
                    ),
                  ),
                  child: widget.child,
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

/// Shared responsive auth composition; the existing form is supplied unchanged.
class AppAuthLayout extends StatelessWidget {
  const AppAuthLayout({
    super.key,
    required this.child,
    required this.title,
    required this.subtitle,
  });
  final Widget child;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= AppBreakpoints.desktop;
      final form = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: AppGlassCard(
            blur: true,
            padding: EdgeInsets.all(wide ? AppSpacing.xl : AppSpacing.lg),
            child: child,
          ),
        ),
      );
      return SingleChildScrollView(
        padding: AppSpacing.pagePadding(context),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - (wide ? 64 : 32)).clamp(
              0,
              double.infinity,
            ),
          ),
          child: wide
              ? Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xxl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 64,
                              height: 5,
                              decoration: BoxDecoration(
                                gradient: AppGradients.signature,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            Text(
                              title,
                              style: Theme.of(context).textTheme.displaySmall
                                  ?.copyWith(fontSize: 58, height: 1.06),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              subtitle,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(child: form),
                  ],
                )
              : form,
        ),
      );
    },
  );
}
