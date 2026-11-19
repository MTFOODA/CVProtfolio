import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cv_portfolio_maker/app/router.dart';
import 'package:cv_portfolio_maker/core/branding/app_branding.dart';
import 'package:cv_portfolio_maker/core/l10n/app_strings.dart';
import 'package:cv_portfolio_maker/core/theme/app_theme.dart';
import 'package:cv_portfolio_maker/features/about/about_app_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final cache = File(Platform.resolvedExecutable).parent.parent.parent;
    final material = File(
      '${cache.path}/material_fonts/materialicons-regular.otf',
    );
    if (material.existsSync()) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(material.readAsBytes().then(ByteData.sublistView))).load();
    }
    for (final font in {
      'inter': 'Inter-Regular.ttf',
      'tajawal': 'Tajawal-Regular.ttf',
      'CvBrandIcons': 'ContactBrands-Regular.ttf',
    }.entries) {
      await (FontLoader(
        font.key,
      )..addFont(rootBundle.load('assets/google_fonts/${font.value}'))).load();
    }
  });

  testWidgets('About deep link is public and accepts the portfolio palette', (
    tester,
  ) async {
    final signedIn = ValueNotifier(false);
    final router = buildRouter(isSignedIn: signedIn, currentUserId: () => '');
    addTearDown(router.dispose);
    addTearDown(signedIn.dispose);
    router.go('/about?theme=forest');
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AboutAppScreen), findsOneWidget);
    expect(
      tester
          .widget<AboutAppScreen>(find.byType(AboutAppScreen))
          .portfolioThemeId,
      'forest',
    );
    expect(find.text(kDeveloperName), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(router.routeInformationProvider.value.uri.path, '/about');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final width in [320.0, 1440.0]) {
    for (final language in ['en', 'ar']) {
      for (final dark in [false, true]) {
        testWidgets('About links and layout $width $language $dark', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final opened = <String>[];
          var succeeds = true;
          final key = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: dark ? AppTheme.dark() : AppTheme.light(),
                locale: Locale(language),
                supportedLocales: const [Locale('en'), Locale('ar')],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: AboutAppScreen(
                  onOpen: (uri) async {
                    opened.add(uri.toString());
                    return succeeds;
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(kDeveloperName), findsOneWidget);
          for (final action in {
            'about-linkedin': kDeveloperLinkedInUrl,
            'about-github': kDeveloperGitHubUrl,
            'about-android-download': kAndroidAppDownloadUrl,
            'about-web-app': kOfficialWebAppUrl,
          }.entries) {
            final button = find.byKey(ValueKey(action.key));
            await tester.ensureVisible(button);
            await tester.pumpAndSettle();
            await tester.tap(button);
            await tester.pumpAndSettle();
            expect(opened.last, action.value);
          }
          expect(opened.length, 4);
          final linkedIn = tester.widget<Icon>(
            find.descendant(
              of: find.byKey(const ValueKey('about-linkedin')),
              matching: find.byType(Icon),
            ),
          );
          expect(linkedIn.icon!.fontFamily, 'CvBrandIcons');
          expect(linkedIn.icon!.codePoint, 0xf08c);
          succeeds = false;
          await tester.tap(find.byKey(const ValueKey('about-web-app')));
          await tester.pumpAndSettle();
          expect(
            find.text(AppStrings.t(language, 'aboutOpenFailed')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          ScaffoldMessenger.of(tester.element(find.byType(AboutAppScreen)))
              .hideCurrentSnackBar();
          await tester.ensureVisible(find.text(kAppDisplayName));
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final picture = await boundary.toImage();
            final bytes = await picture.toByteData(format: ImageByteFormat.png);
            final file = File(
              'build/about-audit/${width.toInt()}-$language-${dark ? 'dark' : 'light'}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            picture.dispose();
          });
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        });
      }
    }
  }
}
