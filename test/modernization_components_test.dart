import 'package:cv_portfolio_maker/core/design/app_icons.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cv_portfolio_maker/core/theme/app_theme.dart';
import 'package:cv_portfolio_maker/core/widgets/app_motion.dart';
import 'package:cv_portfolio_maker/core/widgets/app_navigation_shell.dart';
import 'package:cv_portfolio_maker/core/widgets/app_surfaces.dart';

const destinations = [
  NavigationDestination(icon: Icon(AppIcons.home), label: 'Home'),
  NavigationDestination(icon: Icon(AppIcons.document), label: 'Build CV'),
  NavigationDestination(icon: Icon(AppIcons.portfolio), label: 'Portfolio'),
  NavigationDestination(icon: Icon(AppIcons.settings), label: 'Settings'),
];
void main() {
  testWidgets(
    'adaptive navigation retains form state and every destination across target widths',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.physicalSize = const Size(360, 800);
      var selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => AppBackdrop(child: child!),
          home: StatefulBuilder(
            builder: (context, setState) => AppNavigationShell(
              selectedIndex: selected,
              onSelected: (value) => setState(() => selected = value),
              destinations: destinations,
              body: const Padding(
                padding: EdgeInsets.all(24),
                child: TextField(),
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Retained draft');
      for (final size in [
        const Size(412, 915),
        const Size(1440, 900),
        const Size(360, 800),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(find.text('Retained draft'), findsOneWidget);
        if (size.width >= 1100) {
          expect(
            tester
                .widget<NavigationRail>(find.byType(NavigationRail))
                .destinations
                .length,
            4,
          );
        } else {
          expect(
            tester
                .widget<NavigationBar>(find.byType(NavigationBar))
                .destinations
                .length,
            4,
          );
        }
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'glass auth layout and controls fit all approved viewports with large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final size in [
        const Size(360, 800),
        const Size(412, 915),
        const Size(1440, 900),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: AppBackdrop(child: child!),
            ),
            home: Scaffold(
              body: AppAuthLayout(
                title: 'Your work in motion',
                subtitle: 'Build and share your professional profile',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const TextField(
                      decoration: InputDecoration(labelText: 'Email address'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {},
                      child: const Text('Continue'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(FilledButton)).height,
          greaterThanOrEqualTo(48),
        );
      }
    },
  );
  testWidgets(
    'reduced-motion loading is static and all tickers disappear on unmount',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const Scaffold(body: AppLoading()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppSkeleton), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
