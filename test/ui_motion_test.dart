import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cv_portfolio_maker/core/widgets/app_motion.dart';
import 'package:cv_portfolio_maker/core/theme/app_theme.dart';

void main() {
  testWidgets('tab motion preserves a partially edited form', (tester) async {
    var tab = 0;
    late StateSetter change;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              change = setState;
              return AppContentTransition(
                identity: tab,
                child: const TextField(),
              );
            },
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextField),
      'Unfinished professional story',
    );
    change(() => tab = 1);
    await tester.pumpAndSettle();
    expect(find.text('Unfinished professional story'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reduced motion exposes content immediately and keeps actions active',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: AppContentTransition(
                identity: 0,
                child: AppReveal(
                  child: FilledButton(
                    onPressed: () => taps++,
                    child: const Text('Continue'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<FadeTransition>(find.byType(FadeTransition).first)
            .opacity
            .value,
        1,
      );
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1,
      );
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'scroll reveal waits for viewport and never hides a revealed section',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  AppReveal(
                    child: SizedBox(height: 120, child: Text('First section')),
                  ),
                  SizedBox(height: 800),
                  AppReveal(
                    key: ValueKey('last'),
                    child: SizedBox(height: 160, child: Text('Last section')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final last = find.descendant(
        of: find.byKey(const ValueKey('last')),
        matching: find.byType(AnimatedOpacity),
      );
      expect(tester.widget<AnimatedOpacity>(last).opacity, 0);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -850),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedOpacity>(last).opacity, 1);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, 850),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedOpacity>(last).opacity, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
