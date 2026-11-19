import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cv_portfolio_maker/core/design/templates.dart';
import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/document_models.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/export/export_fonts.dart';
import 'package:cv_portfolio_maker/core/export/export_service.dart';
import 'package:cv_portfolio_maker/core/render/contact_detail_icon.dart';
import 'package:cv_portfolio_maker/core/render/resolved_document.dart';
import 'package:cv_portfolio_maker/core/render/section_titles.dart';
import 'package:cv_portfolio_maker/core/utils/contact_links.dart';
import 'package:cv_portfolio_maker/core/widgets/contact_link_fields.dart';
import 'package:cv_portfolio_maker/data/local/local_repositories.dart';
import 'package:cv_portfolio_maker/data/local/local_store.dart';
import 'package:cv_portfolio_maker/features/cv_design/cv_design_settings_screen.dart';

import 'support/arabic_font.dart';
import 'support/pdf_text.dart';

const github = 'https://github.com/example-developer';
const linkedin = 'https://www.linkedin.com/in/example-developer';
const website = 'https://example.test/a/very/long/portfolio/path';
const profile = UserProfile(
  id: 'owner',
  details: ProfileDetails(
    fullName: 'Profile Owner',
    professionalTitle: 'Mobile Developer',
    email: 'owner@example.test',
    phone: '+20 100 123 4567',
    location: 'Cairo',
    website: website,
    links: [github, linkedin, website],
    linkLabels: {
      github: 'dev-name',
      linkedin: 'my-profile',
      website: 'Portfolio',
    },
  ),
);

CvDocument document({
  String layout = 'grid',
  bool icons = true,
  double size = 12,
  bool labels = false,
}) {
  final base = designForTemplate('minimal', DocumentType.cv);
  return CvDocument(
    id: 'cv',
    ownerId: 'owner',
    title: 'Contact header',
    design: base.copyWith(
      presentation: base.presentation.copyWith(
        headerStyle: 'left',
        identityArrangement: 'inline',
        contactArrangement: layout,
        showContactLabels: labels,
        showContactIcons: icons,
        contactIconSize: size,
      ),
    ),
  );
}

ResolvedDocument resolved(CvDocument doc, [UserProfile data = profile]) =>
    ResolvedDocument.resolve(
      document: doc,
      profile: data,
      defaultTitle: defaultTitleEn,
    );

String xml(List<int> bytes, String path) => utf8.decode(
  ZipDecoder().decodeBytes(bytes).findFile(path)!.content as List<int>,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'legacy data, labeled URLs and bounded icon sizes survive reopening',
    () async {
      expect(ProfileDetails.fromJson({}).linkLabels, isEmpty);
      expect(
        ProfileDetails.fromJson(profile.details.toJson()).linkLabels,
        profile.details.linkLabels,
      );
      expect(PresentationConfig.fromJson({}).identityArrangement, 'stacked');
      for (final pair in [(-100.0, 8.0), (100.0, 24.0), (double.nan, 12.0)]) {
        expect(
          PresentationConfig(contactIconSize: pair.$1)
              .resolvedContactIconSize(11),
          pair.$2,
        );
      }
      final dir = await Directory.systemTemp.createTemp('cv_contact_labels');
      try {
        final store = LocalBackend(LocalStore.forDirectory(dir));
        await store.saveProfile(profile);
        await store.saveDocument(document(layout: 'twoRows', size: 19));
        await store.saveDocument(document().copyWith(id: 'other'));
        final reopened = LocalBackend(LocalStore.forDirectory(dir));
        expect(
          (await reopened.loadProfile('owner'))!.details.linkLabels[github],
          'dev-name',
        );
        final saved = (await reopened.loadDocument(
          'cv',
          'owner',
        ))!.design.presentation;
        expect(saved.resolvedContactArrangement, 'twoRows');
        expect(saved.contactIconSize, 19);
        expect(saved.showContactLabels, isFalse);
        expect(
          (await reopened.loadDocument(
            'other',
            'owner',
          ))!.design.presentation.contactIconSize,
          12,
        );
      } finally {
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'links resolve to brand logos and separate text and destinations safely',
    () {
      final contacts = resolved(document()).contacts;
      expect(contacts.where((c) => c.value == website), hasLength(1));
      final git = contacts.singleWhere((c) => c.label == 'GitHub');
      expect(git.text(), 'dev-name');
      expect(git.url, github);
      expect(contactLinkKind('https://github.com.evil.test/profile'), 'Link');
      for (final url in [
        'javascript:alert(1)',
        'data:text/html,x',
        'https://',
        'invalid url',
      ]) {
        expect(contactWebUrl(url), isNull);
      }
      expect(contactWebUrl('github.com/example-developer'), github);
      final invalid = resolved(
        document(),
        profile.copyWith(
          details: profile.details.copyWith(links: ['javascript:alert(1)']),
        ),
      );
      expect(invalid.contacts.last.url, isNull);
      final ats = ResolvedDocument.resolve(
        document: document(),
        profile: profile,
        defaultTitle: defaultTitleEn,
        atsFriendly: true,
      );
      expect(
        ats.contacts.singleWhere((c) => c.label == 'GitHub').displayValue,
        github,
      );
    },
  );

  testWidgets(
    'display-name fields validate destinations without replacing the URL',
    (tester) async {
      final url = TextEditingController();
      final name = TextEditingController();
      addTearDown(url.dispose);
      addTearDown(name.dispose);
      final form = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: form,
              child: ContactLinkFields(
                label: 'GitHub',
                url: url,
                displayName: name,
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField).last, 'dev-name');
      expect(form.currentState!.validate(), isFalse);
      await tester.enterText(find.byType(TextFormField).first, github);
      expect(form.currentState!.validate(), isTrue);
      expect(url.text, github);
      expect(name.text, 'dev-name');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'compact header, logos, row controls and icon size update the live preview',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final doc = document(labels: true);
      final draft = ValueNotifier(doc.design);
      addTearDown(draft.dispose);
      final launched = <String>[];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'launch') {
          launched.add((call.arguments as Map)['url'] as String);
          return true;
        }
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CvDesignSettingsScreen(
            document: doc,
            profile: profile,
            design: draft,
            onSave: () async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final value in [
        'owner@example.test',
        '+20 100 123 4567',
        'Cairo',
        'dev-name',
        'my-profile',
      ]) {
        expect(find.text(value), findsOneWidget);
      }
      for (final label in [
        'Email',
        'Phone',
        'Location',
        'Website',
        'GitHub',
        'LinkedIn',
      ]) {
        expect(find.textContaining('$label:'), findsNothing);
      }
      await tester.ensureVisible(find.text('Use compact header'));
      await tester.tap(find.text('Use compact header'));
      await tester.pumpAndSettle();
      expect(draft.value.presentation.identityArrangement, 'inline');
      expect(draft.value.presentation.showContactLabels, isFalse);
      final logo = tester.widget<ContactDetailIcon>(
        find.byWidgetPredicate(
          (w) => w is ContactDetailIcon && w.label == 'GitHub',
        ),
      );
      expect(logo.size, 11);
      expect(
        find.byIcon(const IconData(0xf09b, fontFamily: 'CvBrandIcons')),
        findsOneWidget,
      );
      for (final choice in ['One row', 'Two rows', 'Grid']) {
        await tester.ensureVisible(find.text(choice));
        await tester.tap(find.text(choice));
        await tester.pumpAndSettle();
      }
      final plus = find.byTooltip('Increase contact icon size');
      await tester.ensureVisible(plus);
      await tester.tap(plus);
      await tester.pumpAndSettle();
      expect(draft.value.presentation.contactIconSize, 12);
      await tester.tap(find.text('dev-name'));
      await tester.pumpAndSettle();
      expect(launched, [github]);
      await tester.ensureVisible(find.text('No Icons'));
      await tester.tap(find.text('No Icons'));
      await tester.pumpAndSettle();
      expect(find.byType(ContactDetailIcon), findsNothing);
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Preview CV'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'actual PDF and Word retain clickable labels in all contact arrangements',
    () async {
      final exporter = DocumentExporter(
        fonts: GoogleFontSource(assetBundle: DiskAssetBundle()),
      );
      final dir = Directory('build/contact_header_samples');
      await dir.create(recursive: true);
      for (final layout in ['oneRow', 'twoRows', 'grid']) {
        for (final icons in [true, false]) {
          // Saved CVs may still have the legacy label setting enabled.
          final doc = document(
            layout: layout,
            icons: icons,
            size: 18,
            labels: true,
          );
          final pdf = await exporter.export(
            document: doc,
            profile: profile,
            mode: ExportMode.designed,
          );
          final text = extractNormalisedPdfText(pdf.bytes);
          expect(text, contains('dev-name'));
          expect(text, contains('my-profile'));
          for (final label in [
            'Email',
            'Phone',
            'Location',
            'Website',
            'GitHub',
            'LinkedIn',
          ]) {
            expect(text, isNot(contains('$label:')));
          }
          expect(text, isNot(contains('github.com/example-developer')));
          final raw = latin1.decode(pdf.bytes);
          expect(raw, contains(github));
          expect(raw, contains(linkedin));
          final word = await exporter.exportDocx(
            document: doc,
            profile: profile,
          );
          final body = xml(word.bytes, 'word/document.xml');
          for (final label in [
            'Email',
            'Phone',
            'Location',
            'Website',
            'GitHub',
            'LinkedIn',
          ]) {
            expect(body, isNot(contains('$label:')));
          }
          expect(body, contains('dev-name'));
          expect(body, isNot(contains(github)));
          expect(
            xml(word.bytes, 'word/_rels/document.xml.rels'),
            contains(github),
          );
          expect(body, contains('<w:hyperlink r:id='));
          expect(body.contains('w:ascii="$contactBrandFontFamily"'), icons);
          if (icons) expect(body, contains('w:sz w:val="36"'));
          final stem = '$layout-${icons ? 'icons' : 'text'}';
          await File('${dir.path}/$stem.pdf').writeAsBytes(pdf.bytes);
          await File('${dir.path}/$stem.docx').writeAsBytes(word.bytes);
        }
      }
      final arabicDoc = document(size: 14)
          .copyWith(design: document(size: 14).design.copyWith(isRtl: true));
      final arabicProfile = profile.copyWith(
        details: profile.details.copyWith(
          fullName: 'سارة أحمد',
          professionalTitle: 'مطورة تطبيقات',
          linkLabels: {
            ...profile.details.linkLabels,
            github: 'حساب البرمجة',
            linkedin: List.filled(
              8,
              'A long professional display name',
            ).join(' '),
          },
        ),
      );
      final arabicPdf = await exporter.export(
        document: arabicDoc,
        profile: arabicProfile,
        mode: ExportMode.designed,
        languageCode: 'ar',
      );
      expect(
        extractNormalisedPdfText(arabicPdf.bytes),
        contains('+20 100 123 4567'),
      );
      final arabicWord = await exporter.exportDocx(
        document: arabicDoc,
        profile: arabicProfile,
        languageCode: 'ar',
      );
      expect(xml(arabicWord.bytes, 'word/document.xml'), contains('سارة أحمد'));
      expect(
        xml(arabicWord.bytes, 'word/document.xml'),
        contains('w:cs="$contactBrandFontFamily"'),
      );
      await File('${dir.path}/grid-arabic.pdf').writeAsBytes(arabicPdf.bytes);
      await File('${dir.path}/grid-arabic.docx').writeAsBytes(arabicWord.bytes);
    },
  );
}
