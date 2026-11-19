import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cv_portfolio_maker/core/design/cv_design_options.dart';
import 'package:cv_portfolio_maker/core/design/templates.dart';
import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/document_models.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/export/export_fonts.dart';
import 'package:cv_portfolio_maker/core/export/export_service.dart';
import 'package:cv_portfolio_maker/core/render/document_view.dart';
import 'package:cv_portfolio_maker/core/render/resolved_document.dart';
import 'package:cv_portfolio_maker/core/render/section_titles.dart';
import 'package:cv_portfolio_maker/data/local/local_repositories.dart';
import 'package:cv_portfolio_maker/data/local/local_store.dart';
import 'package:cv_portfolio_maker/features/cv_design/cv_design_settings_screen.dart';
import 'package:cv_portfolio_maker/features/cv_design/design_controls.dart';

import 'support/arabic_font.dart';
import 'support/pdf_text.dart';

CvDocument fixtureDocument({
  String id = 'one',
  bool arabic = false,
  bool styled = false,
}) {
  final basic = designForTemplate('minimal', DocumentType.cv);
  return CvDocument(
    id: id,
    ownerId: 'owner',
    title: 'Design regression',
    design: styled
        ? basic.copyWith(
            isRtl: arabic,
            typography: basic.typography.copyWith(
              bodyFont: 'lora',
              nameFont: 'roboto',
              bodyFontSize: 12,
              headingFontSize: 28,
              professionalTitleFontSize: 16,
              sectionTitleFontSize: 18,
              entryHeaderFontSize: 14,
              bodyLineHeight: 1.5,
              headingLetterSpacing: 1,
            ),
            spacing: basic.spacing.copyWith(
              horizontalMargin: 18 * pointsPerMm,
              verticalMargin: 20 * pointsPerMm,
              itemSpacing: 12,
              paragraphSpacing: 9,
              sectionSpacing: 24,
            ),
            presentation: basic.presentation.copyWith(
              headerStyle: 'center',
              contactArrangement: 'grid',
              contactIconStyle: 'rounded',
              dateLocationPosition: 'right',
            ),
          )
        : basic.copyWith(isRtl: arabic),
  );
}

UserProfile fixtureProfile({bool arabic = false, bool long = false}) =>
    UserProfile(
      id: 'owner',
      details: ProfileDetails(
        fullName: arabic ? 'سارة أحمد' : 'Alex Morgan',
        professionalTitle: arabic ? 'مهندسة برمجيات' : 'Software Engineer',
        email: 'alex@example.test',
        phone: '+20 100 123 4567',
        location: arabic ? 'القاهرة مصر' : 'Cairo, Egypt',
        summary: arabic
            ? 'أعمل على تطوير تطبيقات موثوقة تساعد الفرق على تقديم تجربة استخدام واضحة وسهلة.'
            : 'I build reliable applications and clear user experiences for teams solving complex problems.',
      ),
      experiences: [
        for (var i = 0; i < (long ? 16 : 2); i++)
          ExperienceEntry(
            id: 'e$i',
            position: arabic ? 'مهندسة تطبيقات $i' : 'Application Engineer $i',
            company: arabic ? 'فريق المنتجات الرقمية' : 'Digital Products Team',
            location: arabic ? 'القاهرة' : 'Cairo',
            dateRange: const DateRange(
              startIso: '2020-01-01',
              endIso: '2024-01-01',
            ),
            descriptions: [
              for (var j = 0; j < 3; j++)
                arabic
                    ? 'طورت تطبيقات متعددة المنصات مع تحسين الأداء وإمكانية الوصول ودعم اللغة العربية.'
                    : 'Built accessible applications with reliable data synchronization, clear documentation, and measurable improvements in performance across devices.',
            ],
          ),
      ],
      education: [
        EducationEntry(
          id: 'edu',
          qualification: arabic ? 'بكالوريوس هندسة' : 'BSc Engineering',
          institution: arabic ? 'جامعة القاهرة' : 'Cairo University',
          dateRange: const DateRange(endIso: '2019-01-01'),
        ),
      ],
      skills: const [SkillEntry(id: 'skill', name: 'Flutter')],
    );
ResolvedDocument resolve(CvDocument document, UserProfile profile) =>
    ResolvedDocument.resolve(
      document: document,
      profile: profile,
      defaultTitle: defaultTitleResolver(document.design.isRtl ? 'ar' : 'en'),
    );
String part(List<int> data, String name) => utf8.decode(
  ZipDecoder().decodeBytes(data).findFile(name)!.content as List<int>,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'legacy JSON preserves ATS template defaults and new settings round-trip',
    () {
      final legacy = DocumentDesign.fromJson({
        'typography': {'bodyFontSize': 10.5, 'headingFont': 'inter'},
        'spacing': {'pageMargin': 40},
        'presentation': {'contactInline': true},
      });
      expect(legacy.typography.resolvedNameFont, 'inter');
      expect(legacy.typography.resolvedProfessionalTitleFontSize, 11.5);
      expect(legacy.typography.resolvedEntryHeaderFontSize, 10.5);
      expect(legacy.spacing.resolvedHorizontalMargin, 40);
      expect(legacy.spacing.resolvedVerticalMargin, 40);
      expect(legacy.presentation.resolvedContactArrangement, 'compact');
      expect(legacy.presentation.dateLocationPosition, 'belowTitle');
      final styled = fixtureDocument(styled: true).design;
      expect(
        DocumentDesign.fromJson(styled.toJson()).toJson(),
        styled.toJson(),
      );
    },
  );
  test('all numeric controls clamp lower and upper boundaries', () {
    for (final setting in CvDesignValue.values) {
      final design = fixtureDocument().design;
      expect(
        setting.read(setting.apply(design, -999)),
        closeTo(setting.min, .0001),
      );
      expect(
        setting.read(setting.apply(design, 999)),
        closeTo(setting.max, .0001),
      );
      expect(setting.read(setting.apply(design, double.nan)).isFinite, isTrue);
    }
  });
  test(
    'separate documents persist independent designs without touching CV data',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'cv_design_persistence',
      );
      try {
        final backend = LocalBackend(LocalStore.forDirectory(dir));
        await backend.saveProfile(fixtureProfile());
        await backend.saveDocument(fixtureDocument(styled: true));
        await backend.saveDocument(fixtureDocument(id: 'two'));
        final reopened = LocalBackend(LocalStore.forDirectory(dir));
        final one = (await reopened.loadDocument('one', 'owner'))!;
        final two = (await reopened.loadDocument('two', 'owner'))!;
        expect(one.design.typography.bodyFontSize, 12);
        expect(two.design.typography.bodyFontSize, 10.5);
        expect(one.design.presentation.dateLocationPosition, 'right');
        expect(two.design.presentation.dateLocationPosition, 'belowTitle');
        expect((await reopened.loadProfile('owner'))!.experiences.length, 2);
        expect(await reopened.loadDocument('one', 'intruder'), isNull);
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );
  testWidgets(
    'all controls update the same draft and preview; narrow layout scrolls',
    (tester) async {
      final doc = fixtureDocument();
      final draft = ValueNotifier(doc.design);
      addTearDown(draft.dispose);
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: CvDesignSettingsScreen(
            document: doc,
            profile: fixtureProfile(),
            design: draft,
            onSave: () async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DocumentView), findsOneWidget);
      await tester.tap(find.text('Right'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DocumentView>(find.byType(DocumentView))
            .resolved
            .design
            .presentation
            .dateLocationPosition,
        'right',
      );
      final bodyDropdown = find.descendant(
        of: find.widgetWithText(DesignFontDropdown, 'Body Font'),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      await tester.ensureVisible(bodyDropdown);
      await tester.tap(bodyDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lora').last);
      await tester.pumpAndSettle();
      expect(draft.value.typography.bodyFont, 'lora');
      expect(draft.value.typography.resolvedNameFont, 'lora');
      for (final label in ['Center', 'Grid', 'No Icons', 'Show Icons']) {
        final target = find.text(label);
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }
      expect(draft.value.presentation.headerStyle, 'center');
      expect(draft.value.presentation.resolvedContactArrangement, 'grid');
      expect(draft.value.presentation.showContactIcons, isTrue);
      final circle = find.byTooltip('circle contact icons');
      await tester.ensureVisible(circle);
      await tester.tap(circle);
      await tester.pumpAndSettle();
      expect(draft.value.presentation.contactIconStyle, 'circle');
      for (final setting in CvDesignValue.values) {
        final action = find.byTooltip('Increase ${setting.label}');
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        final before = setting.read(draft.value);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(setting.read(draft.value), closeTo(before + setting.step, .001));
        expect(
          tester
              .widget<DocumentView>(find.byType(DocumentView))
              .resolved
              .design,
          same(draft.value),
        );
      }
      draft.value = fixtureDocument(styled: true).design;
      await tester.pumpAndSettle();
      final view = tester.widget<DocumentView>(find.byType(DocumentView));
      expect(view.resolved.design.typography.resolvedNameFont, 'roboto');
      expect(
        view.resolved.design.presentation.resolvedContactArrangement,
        'grid',
      );
      final name = tester.widget<Text>(
        find.descendant(
          of: find.byType(DocumentView),
          matching: find.text('Alex Morgan'),
        ),
      );
      expect(name.style!.fontSize, 28);
      expect(name.style!.fontFamily, 'roboto');
      final title = tester.widget<Text>(
        find.descendant(
          of: find.byType(DocumentView),
          matching: find.text('Software Engineer'),
        ),
      );
      expect(title.style!.fontSize, 16);
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Preview CV'));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentView), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('back guards unsaved changes and failed saves retain the draft', (
    tester,
  ) async {
    final draft = ValueNotifier(fixtureDocument().design);
    addTearDown(draft.dispose);
    final nav = GlobalKey<NavigatorState>();
    var saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        home: const Scaffold(body: Text('Editor')),
      ),
    );
    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => CvDesignSettingsScreen(
          document: fixtureDocument(),
          profile: fixtureProfile(),
          design: draft,
          onSave: () async {
            saves++;
            return false;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Right'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Save design changes?'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(draft.value.presentation.dateLocationPosition, 'right');
    expect(find.byType(CvDesignSettingsScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(draft.value.presentation.dateLocationPosition, 'belowTitle');
    expect(find.text('Editor'), findsOneWidget);
  });
  test('one long entry spans PDF pages without dropping its tail', () async {
    final profile = fixtureProfile().copyWith(
      experiences: [
        ExperienceEntry(
          id: 'long',
          position: 'Engineer',
          descriptions: [
            '${List.filled(100, 'Long project delivery with reliable systems and accessible interfaces.').join(' ')} FINAL_ENTRY_MARKER',
          ],
        ),
      ],
    );
    final result =
        await DocumentExporter(
          fonts: GoogleFontSource(assetBundle: DiskAssetBundle()),
        ).export(
          document: fixtureDocument(styled: true),
          profile: profile,
          mode: ExportMode.designed,
        );
    expect(result.pageCount, greaterThan(1));
    expect(
      extractNormalisedPdfText(result.bytes),
      contains('FINAL_ENTRY_MARKER'),
    );
    await Directory('build/cv_design_samples').create(recursive: true);
    await File('build/cv_design_samples/long-entry.pdf')
        .writeAsBytes(result.bytes);
  });

  test('actual PDF and DOCX files apply settings for English Arabic and multipage data', () async {
    final exporter = DocumentExporter(
      fonts: GoogleFontSource(
        assetBundle: DiskAssetBundle(),
        arabicCandidates: const [],
      ),
    );
    final output = Directory('build/cv_design_samples');
    await output.create(recursive: true);
    for (final arabic in [false, true]) {
      for (final styled in [false, true]) {
        final doc = fixtureDocument(arabic: arabic, styled: styled);
        final profile = fixtureProfile(arabic: arabic, long: true);
        final stem = '${arabic ? 'ar' : 'en'}-${styled ? 'custom' : 'default'}';
        final pdf = await exporter.export(
          document: doc,
          profile: profile,
          mode: ExportMode.designed,
          languageCode: arabic ? 'ar' : 'en',
        );
        expect(pdf.pageCount, greaterThan(1));
        expect(pdf.fonts.isFallback, isFalse);
        await File('${output.path}/$stem.pdf').writeAsBytes(pdf.bytes);
        final word = await exporter.exportDocx(
          document: doc,
          profile: profile,
          languageCode: arabic ? 'ar' : 'en',
        );
        await File('${output.path}/$stem.docx').writeAsBytes(word.bytes);
        final xml = part(word.bytes, 'word/document.xml');
        final styles = part(word.bytes, 'word/styles.xml');
        expect(xml, contains(arabic ? 'سارة أحمد' : 'Alex Morgan'));
        expect(xml, isNot(contains('\uFE8D')));
        expect(
          styles,
          contains(styled ? 'w:sz w:val="56"' : 'w:sz w:val="36"'),
        );
        expect(styles, contains(styled ? 'w:line="360"' : 'w:line="324"'));
        expect(styles, contains(styled ? 'w:ascii="Lora"' : 'w:ascii="Inter"'));
        expect(xml, contains(styled ? 'w:right="1020"' : 'w:right="800"'));
        expect(xml, contains(styled ? 'w:top="1134"' : 'w:top="800"'));
        if (styled) {
          expect(xml, contains('<w:tbl>'));
          expect(xml, contains('w:val="center"'));
        }
        if (arabic) {
          expect(xml, contains('<w:bidi/>'));
          expect(xml, contains('<w:rtl/>'));
        }
        final archive = ZipDecoder().decodeBytes(word.bytes);
        expect(
          archive.files.where((f) => f.name.endsWith('.odttf')),
          isNotEmpty,
        );
        expect(
          part(word.bytes, 'word/fontTable.xml'),
          contains('w:embedRegular'),
        );
      }
    }
  });
}
