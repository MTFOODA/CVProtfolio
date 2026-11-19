import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cv_portfolio_maker/core/design/portfolio_themes.dart';
import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/document_models.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/render/resolved_document.dart';
import 'package:cv_portfolio_maker/core/render/section_titles.dart';
import 'package:cv_portfolio_maker/core/theme/app_theme.dart';
import 'package:cv_portfolio_maker/features/portfolio/portfolio_navigation.dart';
import 'package:cv_portfolio_maker/features/portfolio/portfolio_tabs.dart';
import 'package:cv_portfolio_maker/features/portfolio/portfolio_theme.dart';
import 'package:cv_portfolio_maker/features/portfolio/portfolio_widgets.dart';
import 'package:cv_portfolio_maker/features/portfolio/public_portfolio_view.dart';

void main() {
  setUpAll(() async {
    for (final entry in {
      'inter': 'Inter-Regular.ttf',
      'tajawal': 'Tajawal-Regular.ttf',
      'Roboto': 'Roboto-Regular.ttf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load('assets/google_fonts/${entry.value}'))).load();
    }
  });

  for (final viewport in [
    (320.0, true, 'ar'),
    (1440.0, true, 'en'),
    (390.0, false, 'en'),
    (1440.0, false, 'ar'),
  ]) {
    for (final visitor in [false, true]) {
      testWidgets(
        'experience points are separate full-width boxes ${viewport.$1} ${viewport.$3} visitor=$visitor',
        (tester) async {
          tester.view.physicalSize = Size(viewport.$1, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final arabic = viewport.$3 == 'ar';
          final profile = UserProfile(
            id: 'owner',
            experiences: [
              ExperienceEntry(
                id: 'job',
                position: arabic
                    ? 'مهندس دعم التطبيقات'
                    : 'Application Support Engineer',
                company: 'Bank',
                descriptionItems: [
                  DescriptionItem(
                    label: arabic
                        ? 'تهيئة الأنظمة'
                        : 'ATM Onboarding & Configuration',
                    text: arabic
                        ? 'إدارة دورة تهيئة الأنظمة وضبط الموارد ومتابعة الأداء لضمان استقرار الخدمات.'
                        : 'Manage the full lifecycle of deployment by\nconfiguring and provisioning resources across application servers, network layers, and operational parameters. Coordinate production changes with technical teams and validate service availability throughout the deployment process.',
                  ),
                  DescriptionItem(
                    text: arabic
                        ? 'دعم التطبيقات وتحليل المشكلات اليومية والتعاون مع فريق العمل.'
                        : 'Resolve incidents, investigate application logs, and coordinate reliable daily operations.',
                  ),
                  DescriptionItem(
                    label: arabic ? 'تحسين الأداء' : 'Performance',
                    text: 'Monitor services and maintain clear operational documentation.',
                  ),
                ],
              ),
              const ExperienceEntry(
                id: 'legacy',
                position: 'Previous role',
                descriptions: ['Legacy responsibility'],
              ),
            ],
          );
          const document = CvDocument(
            id: 'portfolio',
            ownerId: 'owner',
            title: 'Portfolio',
            type: DocumentType.portfolio,
            design: DocumentDesign(
              templateId: 'sky',
              sections: [
                SectionConfig(id: 'work', kind: SectionKind.experience),
              ],
            ),
          );
          final resolved = ResolvedDocument.resolve(
            document: document,
            profile: profile,
            defaultTitle: defaultTitleResolver(viewport.$3),
          );
          final theme = portfolioUiTheme(
            viewport.$2 ? AppTheme.dark() : AppTheme.light(),
            skyTheme,
          );
          final boundaryKey = GlobalKey();
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: theme,
                locale: Locale(viewport.$3),
                supportedLocales: const [Locale('en'), Locale('ar')],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: RepaintBoundary(
                  key: boundaryKey,
                  child: visitor
                      ? PublicPortfolioView(
                          document: document,
                          profile: profile,
                          resolved: resolved,
                          onOpen: (_) {},
                          onDownload: () {},
                        )
                      : Scaffold(
                          body: PortfolioBackdrop(
                            palette: skyTheme,
                            child: PortfolioPageView(
                              page: PortfolioPage.experience,
                              content: PortfolioContent(resolved, profile),
                              onWork: () {},
                              onOpen: (_) {},
                              onEdit: () {},
                              onDownload: () {},
                            ),
                          ),
                        ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (visitor) {
            await tester.tap(find.byType(NavigationDestination).last);
            await tester.pumpAndSettle();
          }
          final boxes = find.byType(PortfolioDescriptionBox);
          expect(boxes, findsNWidgets(4));
          if (!arabic) {
            expect(
              find.textContaining('by configuring and provisioning'),
              findsOneWidget,
            );
            // Reflow is presentation-only; saved CV text keeps its original wraps.
            expect(
              profile.experiences.first.descriptionItems!.first.text,
              contains('by\nconfiguring'),
            );
          }
          final rects = [
            for (var i = 0; i < 4; i++) tester.getRect(boxes.at(i)),
          ];
          for (var i = 0; i < 3; i++) {
            expect(rects[i].left, closeTo(rects.first.left, .1));
            expect(rects[i].width, closeTo(rects.first.width, .1));
            expect(rects[i].right, lessThanOrEqualTo(viewport.$1));
            expect(rects[i + 1].top, greaterThan(rects[i].bottom));
          }
          expect(find.text('Legacy responsibility'), findsOneWidget);
          expect(find.textContaining('•'), findsNothing);
          expect(
            Directionality.of(tester.element(boxes.first)),
            arabic ? TextDirection.rtl : TextDirection.ltr,
          );
          expect(tester.takeException(), isNull);
          if (visitor && viewport.$2) {
            await tester.runAsync(() async {
              final boundary =
                  boundaryKey.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final screenshot = await boundary.toImage();
              final bytes = await screenshot.toByteData(
                format: ImageByteFormat.png,
              );
              final file = File(
                'build/portfolio-review/experience-boxes-${viewport.$3}.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              screenshot.dispose();
            });
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
