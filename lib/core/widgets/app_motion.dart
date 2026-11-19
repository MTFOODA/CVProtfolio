/// Shared, finite motion. Content and actions remain usable with reduced motion.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/physics.dart';

import 'dart:async';

import '../l10n/app_strings.dart';

abstract final class AppMotion {
  static const quick = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 280);
  static const entrance = Duration(milliseconds: 420);
  static const curve = Curves.easeOutCubic;
  static const spring = SpringDescription(mass: 1, stiffness: 420, damping: 34);
  static const sheet = Duration(milliseconds: 360);
  static const lighting = Duration(milliseconds: 900);
  static const stagger = Duration(milliseconds: 35);
  static AnimationStyle sheetStyle(BuildContext context) => AnimationStyle(
    duration: reduced(context) ? Duration.zero : sheet,
    reverseDuration: reduced(context) ? Duration.zero : quick,
  );

  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);

  static Widget button(
    BuildContext context,
    Set<WidgetState> states,
    Widget? child,
  ) => AppSpringScale(
    scale: states.contains(WidgetState.pressed) ? .96 : 1,
    child: child,
  );
}

/// The same lightweight route motion on desktop, web and mobile.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reduced(context)) return child;
    final curved = animation.drive(CurveTween(curve: AppMotion.curve));
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, .018),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// Animates retained tab/form state without rebuilding an outgoing form tree.
class AppContentTransition extends StatefulWidget {
  const AppContentTransition({
    super.key,
    required this.child,
    required this.identity,
  });
  final Widget child;
  final Object identity;
  @override
  State<AppContentTransition> createState() => _AppContentTransitionState();
}

class _AppContentTransitionState extends State<AppContentTransition>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: AppMotion.standard,
  );
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.curve,
  );
  late final _offset = Tween(
    begin: const Offset(0, .018),
    end: Offset.zero,
  ).animate(_curve);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(AppContentTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.identity != oldWidget.identity) {
      if (AppMotion.reduced(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _curve,
    alwaysIncludeSemantics: true,
    child: SlideTransition(position: _offset, child: widget.child),
  );
}

/// Reveals a section once it enters its scroll viewport; no ongoing animation.
class AppReveal extends StatefulWidget {
  const AppReveal({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;
  @override
  State<AppReveal> createState() => _AppRevealState();
}

class _AppRevealState extends State<AppReveal> {
  ScrollPosition? _position;
  bool _shown = false;
  bool _scheduled = false;
  bool _triggered = false;
  Timer? _delay;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (_position != position) {
      _position?.removeListener(_schedule);
      _position = position;
      _position?.addListener(_schedule);
    }
    if (AppMotion.reduced(context)) {
      _delay?.cancel();
      _shown = true;
    }
    _schedule();
  }

  void _schedule() {
    if (_shown || _scheduled || _triggered) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || _shown || !TickerMode.valuesOf(context).enabled) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final viewport = RenderAbstractViewport.maybeOf(box);
      final visible =
          viewport == null ||
          MatrixUtils.transformRect(
            box.getTransformTo(viewport),
            Offset.zero & box.size,
          ).overlaps(viewport.paintBounds);
      if (visible) {
        _triggered = true;
        _position?.removeListener(_schedule);
        final delay = AppMotion.stagger * widget.index.clamp(0, 6);
        if (delay == Duration.zero || AppMotion.reduced(context)) {
          setState(() => _shown = true);
        } else {
          _delay = Timer(delay, () {
            if (mounted) setState(() => _shown = true);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _position?.removeListener(_schedule);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSlide(
    offset: _shown ? Offset.zero : const Offset(0, .035),
    duration: AppMotion.reduced(context) ? Duration.zero : AppMotion.entrance,
    curve: AppMotion.curve,
    child: AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      alwaysIncludeSemantics: true,
      duration: AppMotion.reduced(context) ? Duration.zero : AppMotion.entrance,
      curve: AppMotion.curve,
      child: widget.child,
    ),
  );
}

/// Adds hover and press feedback around an existing action without owning taps.
class AppInteractive extends StatefulWidget {
  const AppInteractive({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;
  @override
  State<AppInteractive> createState() => _AppInteractiveState();
}

class _AppInteractiveState extends State<AppInteractive> {
  bool _hover = false;
  bool _pressed = false;
  Offset _tilt = Offset.zero;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onHover: (event) {
      if (!widget.enabled || AppMotion.reduced(context)) return;
      final box = context.findRenderObject();
      if (box is RenderBox && box.hasSize) {
        setState(
          () => _tilt = Offset(
            ((event.localPosition.dx / box.size.width) - .5).clamp(-.5, .5),
            ((event.localPosition.dy / box.size.height) - .5).clamp(-.5, .5),
          ),
        );
      }
    },
    onExit: (_) => setState(() {
      _hover = false;
      _pressed = false;
      _tilt = Offset.zero;
    }),
    child: Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AppSpringScale(
        scale: !widget.enabled ? 1 : (_pressed ? .97 : (_hover ? 1.015 : 1)),
        child: AnimatedContainer(
          duration: AppMotion.reduced(context)
              ? Duration.zero
              : AppMotion.quick,
          transformAlignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, .001)
            ..rotateX(-_tilt.dy * .055)
            ..rotateY(_tilt.dx * .055),
          child: widget.child,
        ),
      ),
    ),
  );
}

/// A damped physical spring, shared by every button and interactive card.
class AppSpringScale extends StatefulWidget {
  const AppSpringScale({super.key, required this.scale, required this.child});
  final double scale;
  final Widget? child;
  @override
  State<AppSpringScale> createState() => _AppSpringScaleState();
}

class _AppSpringScaleState extends State<AppSpringScale>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController.unbounded(
    vsync: this,
    value: widget.scale,
  );
  @override
  void didUpdateWidget(AppSpringScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scale == widget.scale) return;
    if (AppMotion.reduced(context)) {
      _controller.stop();
      _controller.value = widget.scale;
    } else {
      _controller.animateWith(
        SpringSimulation(
          AppMotion.spring,
          _controller.value,
          widget.scale,
          _controller.velocity,
        ),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _controller.stop();
      _controller.value = widget.scale;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) =>
        Transform.scale(scale: _controller.value, child: child),
  );
}

/// Loading-only shimmer; no ticker survives once real content is available.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({super.key, this.rows = 3});
  final int rows;
  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context) || !TickerMode.valuesOf(context).enabled) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.tr('loadingContent'),
    child: ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.rows; i++)
              Container(
                height: i == 0 ? 74 : 48,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment(-2 + _controller.value * 4, 0),
                    end: Alignment(0 + _controller.value * 4, 0),
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer
                          .withValues(alpha: .4),
                      Theme.of(context).colorScheme.surface
                          .withValues(alpha: .8),
                      Theme.of(context).colorScheme.primaryContainer
                          .withValues(alpha: .4),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
