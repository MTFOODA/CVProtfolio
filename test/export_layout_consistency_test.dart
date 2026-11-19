import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cv_portfolio_maker/core/design/cv_design_options.dart';
import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/document_models.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/export/document_text.dart';
import 'package:cv_portfolio_maker/core/export/export_fonts.dart';
import 'package:cv_portfolio_maker/core/export/export_service.dart';
import 'package:cv_portfolio_maker/core/render/document_view.dart';
import 'package:cv_portfolio_maker/core/render/resolved_document.dart';
import 'package:cv_portfolio_maker/core/render/section_titles.dart';
import 'package:cv_portfolio_maker/features/export/export_sheet.dart';
import 'package:cv_portfolio_maker/core/utils/project_links.dart';

import 'support/arabic_font.dart';
import 'support/pdf_text.dart';

const portfolioUrl = 'https://example.test/p/long-private-looking-path';
const sourceUrl = 'https://github.com/example/project-with-long-name';
const date = DateRange(startIso: '2019-10-01', endIso: '2024-10-01');

CvDocument sampleDocument({
  String organization = 'belowTitle',
  String datePosition = 'right',
  String projectStyle = 'flat',
  bool arabic = false,
  bool sectionIcons = false,
  DividerStyle divider = DividerStyle.thin,
}) => CvDocument(
  id: 'layout',
  ownerId: 'owner',
  title: 'Layout consistency',
  isRtl: arabic,
  design: DocumentDesign(
    isRtl: arabic,
    typography: const TypographyConfig(
      bodyFontSize: 10.5,
      headingFontSize: 23,
      professionalTitleFontSize: 12,
      entryHeaderFontSize: 11,
      dateFontSize: 9,
      sectionTitleFontSize: 13,
      uppercaseSectionTitles: true,
      bodyLineHeight: 1.2,
    ),
    colors: const ColorConfig(headingText: 0xff111827, accent: 0xff111827),
    presentation: PresentationConfig(
      headerStyle: 'left',
      identityArrangement: 'inline',
      contactArrangement: 'grid',
      dateLocationPosition: datePosition,
      organizationPosition: organization,
      projectCardStyle: projectStyle,
      showSectionIcons: sectionIcons,
      dividerStyle: divider,
    ),
    sections: const [
      SectionConfig(id: 'profile', kind: SectionKind.profile),
      SectionConfig(id: 'experience', kind: SectionKind.experience),
      SectionConfig(id: 'education', kind: SectionKind.education),
      SectionConfig(id: 'projects', kind: SectionKind.projects),
    ],
  ),
);

UserProfile sampleProfile({bool arabic = false, bool long = false}) =>
    UserProfile(
      id: 'owner',
      details: ProfileDetails(
        fullName: arabic ? 'أحمد محمد' : 'Alex Morgan',
        professionalTitle: arabic
            ? 'مهندس تطبيقات'
            : 'Mobile Application Developer',
        email: 'alex@example.test',
        phone: '+20 100 123 4567',
        location: 'Cairo, Egypt',
        website: portfolioUrl,
        links: const ['https://github.com/example-developer'],
        linkLabels: const {
          portfolioUrl: 'Portfolio',
          'https://github.com/example-developer': 'ExampleDeveloper',
        },
        summary: arabic
            ? 'أطور تطبيقات موثوقة وسهلة الاستخدام مع الاهتمام بالأداء وجودة الخدمة.'
            : 'Application engineer building reliable applications and accessible user experiences. '
                  'Experienced in system integration, production support and cross-functional collaboration.',
      ),
      experiences: [
        ExperienceEntry(
          id: 'work',
          position: arabic
              ? 'مهندس دعم التطبيقات'
              : 'Application Support Engineer',
          company: arabic ? 'شركة المنتجات الرقمية' : 'Digital Products Team',
          dateRange: const DateRange(startIso: '2025-04-01', isCurrent: true),
          location: 'Cairo',
          descriptionItems: [
            for (var i = 0; i < (long ? 8 : 2); i++)
              DescriptionItem(
                label: arabic ? 'المسؤوليات' : 'Application support',
                text: arabic
                    ? 'تطوير خدمات موثوقة وتحسين الأداء ومتابعة جودة الأنظمة والتعاون مع فريق العمل.'
                    : 'Maintain reliable production services, investigate incidents and improve operational '
                          'workflows while coordinating with product teams and documenting measurable results.',
              ),
          ],
        ),
      ],
      education: [
        EducationEntry(
          id: 'education',
          qualification: arabic ? 'بكالوريوس' : 'Bachelor',
          fieldOfStudy: arabic
              ? 'علوم الحاسب والمعلومات'
              : 'Computer and Information Science',
          institution: arabic ? 'جامعة عين شمس' : 'Ain Shams University',
          dateRange: date,
          grade: arabic ? 'جيد' : 'Good',
          description: arabic
              ? 'مشروع التخرج في معالجة الصور'
              : 'Graduation project in image processing.',
        ),
      ],
      projects: [
        for (var i = 0; i < (long ? 4 : 1); i++)
          ProjectEntry(
            id: 'project$i',
            title: arabic
                ? 'نظام إدارة المطاعم $i'
                : 'Restaurant Management System $i',
            dateRange: const DateRange(
              startIso: '2026-09-01',
              endIso: '2026-10-01',
            ),
            sourceUrl: sourceUrl,
            demoUrl: 'https://example.test/demo',
            descriptionItems: [
              for (var j = 0; j < 3; j++)
                DescriptionItem(
                  label: arabic
                      ? 'المميزات'
                      : [
                          'Architecture & Technology',
                          'Core features',
                          'Security',
                        ][j],
                  text: arabic
                      ? 'واجهة متجاوبة ودعم اللغات وإدارة آمنة للبيانات مع اختبارات موثوقة.'
                      : 'Built a responsive application with clear architecture, multilingual workflows, '
                            'secure data access and reliable automated tests.',
                ),
            ],
            technologies: const ['Flutter', 'Dart'],
          ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('title links keep valid destinations, avoid duplicate actions and reject unsafe schemes', () {
    final links = projectHeadingLinks(
      const ProjectEntry(
        id: 'links',
        demoUrl: ' https://example.test/demo ',
        sourceUrl: 'https://github.com/example/project',
        websiteUrl: 'https://example.test/demo',
      ),
    );
    expect(links.map((link) => link.label), ['Demo', 'Source']);
    expect(links.first.url, 'https://example.test/demo');
    expect(links.last.brand, isTrue);
    expect(
      projectHeadingLinks(
        const ProjectEntry(
          id: 'unsafe',
          demoUrl: 'javascript:alert(1)',
          sourceUrl: 'file:///private',
          websiteUrl: 'ftp://example.test',
        ),
      ),
      isEmpty,
    );
    expect(projectHeadingLinks(const ProjectEntry(id: 'empty')), isEmpty);
  });
  ResolvedDocument resolve(CvDocument document, UserProfile profile) =>
      ResolvedDocument.resolve(
        document: document,
        profile: profile,
        defaultTitle: defaultTitleResolver(document.isRtl ? 'ar' : 'en'),
      );

  test('date font and organization placement survive JSON; profile title honors custom titles and visibility', () {
    final document = sampleDocument();
    final reopened = CvDocument.fromJson(
      jsonDecode(jsonEncode(document.toJson())),
    );
    expect(reopened.design.typography.resolvedDateFontSize, 9);
    expect(reopened.design.presentation.organizationPosition, 'belowTitle');
    expect(
      CvDesignValue.date
          .apply(document.design, 12)
          .typography
          .resolvedDateFontSize,
      12,
    );
    for (final position in ['belowTitle', 'besideTitle', 'withDate']) {
      final configured = document.copyWith(
        design: document.design.copyWith(
          presentation: document.design.presentation.copyWith(
            organizationPosition: position,
          ),
        ),
      );
      final lines = flattenDocument(resolve(configured, sampleProfile()));
      final institution = lines.singleWhere(
        (line) => line.text.contains('Ain Shams University'),
      );
      expect(
        institution.role,
        position == 'belowTitle'
            ? 'entryOrganization'
            : position == 'withDate'
            ? 'entryMeta'
            : null,
      );
      expect(institution.level, position == 'besideTitle' ? 2 : 3);
      if (position == 'belowTitle') {
        expect(institution.text, 'Ain Shams University');
      }
    }
    final sections = [...document.design.sections];
    sections[0] = sections[0].copyWith(customTitle: () => 'About me');
    final renamed = document.copyWith(
      design: document.design.copyWith(sections: sections),
    );
    expect(
      flattenDocument(resolve(renamed, sampleProfile()))
          .where((line) => line.text == 'About me'),
      hasLength(1),
    );
    sections[0] = sections[0].copyWith(visible: false);
    final hidden = document.copyWith(
      design: document.design.copyWith(sections: sections),
    );
    expect(resolve(hidden, sampleProfile()).summary, isEmpty);
    expect(
      flattenDocument(resolve(hidden, sampleProfile()))
          .any((line) => line.text == 'About me'),
      isFalse,
    );
  });

  test('PDF and Word keep compact hyperlink labels, complete dates and school below; write visual fixtures', () async {
    final exporter = DocumentExporter(
      fonts: GoogleFontSource(assetBundle: DiskAssetBundle()),
    );
    final output = Directory('build/export_layout_samples')
      ..createSync(recursive: true);
    for (final spec in [
      ('right', sampleDocument(), sampleProfile()),
      ('below', sampleDocument(datePosition: 'belowTitle'), sampleProfile()),
      ('beside', sampleDocument(organization: 'besideTitle'), sampleProfile()),
      ('with-date', sampleDocument(organization: 'withDate'), sampleProfile()),
      ('multipage', sampleDocument(), sampleProfile(long: true)),
      ('arabic', sampleDocument(arabic: true), sampleProfile(arabic: true)),
      ('card', sampleDocument(projectStyle: 'card'), sampleProfile()),
      ('gallery', sampleDocument(projectStyle: 'gallery'), sampleProfile()),
      ('icons', sampleDocument(sectionIcons: true), sampleProfile()),
      ('dotted', sampleDocument(divider: DividerStyle.dotted), sampleProfile()),
      (
        'gradient',
        sampleDocument(divider: DividerStyle.gradient),
        sampleProfile(),
      ),
    ]) {
      final pdf = await exporter.export(
        document: spec.$2,
        profile: spec.$3,
        mode: ExportMode.designed,
        languageCode: spec.$2.isRtl ? 'ar' : 'en',
      );
      File('${output.path}/${spec.$1}.pdf').writeAsBytesSync(pdf.bytes);
      final text = extractPdfText(pdf.bytes).replaceAll(RegExp(r'\s+'), ' ');
      expect(text, isNot(contains(portfolioUrl)));
      expect(text, isNot(contains(sourceUrl)));
      expect(latin1.decode(pdf.bytes), contains(sourceUrl));
      expect(text, isNot(contains('Source')));
      expect(text, isNot(contains('Demo')));
      if (!spec.$2.isRtl) {
        expect(text, contains('PROFILE'));
        expect(text, contains('Ain Shams University'));
        expect(text, contains('Oct 2019 - Oct 2024'));
        expect(text, contains('Sep 2026 - Oct 2026'));
      }
      if (spec.$1 == 'multipage') expect(pdf.pageCount, greaterThan(1));
    }
    final word = await exporter.exportDocx(
      document: sampleDocument(),
      profile: sampleProfile(),
    );
    final zip = ZipDecoder().decodeBytes(word.bytes);
    final xml = utf8.decode(zip.findFile('word/document.xml')!.content);
    expect(xml, contains('PROFILE'));
    expect(xml, isNot(contains(sourceUrl)));
    expect(xml, contains('<w:sz w:val="18"/>'));
    expect(xml, contains('Ain Shams University'));
    File('${output.path}/right.docx').writeAsBytesSync(word.bytes);
  });

  testWidgets(
    'all project styles honor right dates and font size; school remains below and links stay compact',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final style in ['flat', 'card', 'gallery']) {
        final document = sampleDocument(projectStyle: style);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 595.28,
                  child: DocumentView(
                    resolved: resolve(document, sampleProfile()),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('PROFILE'), findsOneWidget);
        expect(find.text(sourceUrl), findsNothing);
        expect(find.text('Source'), findsNothing);
        expect(find.text('Demo'), findsNothing);
        expect(find.byTooltip('Demo'), findsOneWidget);
        final projectHeading = find.textContaining(
          'Restaurant Management System 0',
          findRichText: true,
        );
        final demoIcon = find.byTooltip('Demo');
        expect(
          tester.getTopLeft(demoIcon).dy,
          greaterThanOrEqualTo(tester.getTopLeft(projectHeading).dy - 2),
        );
        expect(
          tester.getBottomRight(demoIcon).dy,
          lessThanOrEqualTo(tester.getBottomRight(projectHeading).dy + 2),
        );
        final institution = find.text('Ain Shams University');
        final schoolTitle = find.text(
          'Bachelor · Computer and Information Science',
        );
        expect(
          tester.getTopLeft(institution).dy,
          greaterThan(tester.getTopLeft(schoolTitle).dy),
        );
        for (final date in ['Oct 2019 - Oct 2024', 'Sep 2026 - Oct 2026']) {
          final label = tester.widget<Text>(find.text(date));
          expect(label.style!.fontSize, 9);
          expect(label.maxLines, 1);
        }
        if (style != 'gallery') {
          final title = find.textContaining(
            'Restaurant Management System 0',
            findRichText: true,
          );
          final projectDate = find.text('Sep 2026 - Oct 2026');
          expect(
            tester.getTopLeft(projectDate).dx,
            greaterThan(tester.getTopLeft(title).dx),
          );
          expect(
            (tester.getTopLeft(projectDate).dy - tester.getTopLeft(title).dy)
                .abs(),
            lessThan(6),
          );
        }
        expect(tester.takeException(), isNull, reason: style);
      }
    },
  );

  testWidgets(
    'export sheet offers one saved-design PDF without ATS selection',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showExportSheet(
                    context,
                    document: sampleDocument(),
                    profile: sampleProfile(),
                  ),
                  child: const Text('Export test'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Export test'));
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedButton<ExportMode>), findsNothing);
      expect(find.text('ATS-friendly'), findsNothing);
      expect(find.text('Preview PDF'), findsOneWidget);
      expect(find.text('Save or share'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
