import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/document_models.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/export/document_text.dart';
import 'package:cv_portfolio_maker/core/export/docx_builder.dart';
import 'package:cv_portfolio_maker/core/render/document_view.dart';
import 'package:cv_portfolio_maker/core/render/resolved_document.dart';
import 'package:cv_portfolio_maker/core/render/section_titles.dart';
import 'package:cv_portfolio_maker/core/widgets/description_items_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'export_test.dart' show offlineExporter, extractPdfText;

const items = [
  DescriptionItem(
    label: 'Architecture',
    text: 'Clean architecture with BLoC Cubit',
  ),
  DescriptionItem(text: 'Delivered the app'),
];

void main() {
  test('old descriptions remain readable and structured descriptions survive JSON and copies', () {
    expect(
      ProjectEntry.fromJson({'id': 'p', 'description': 'First\nSecond'})
          .resolvedDescriptions
          .map((e) => e.formatted),
      ['First', 'Second'],
    );
    expect(
      ExperienceEntry.fromJson({
        'id': 'e',
        'descriptions': ['Old achievement'],
      }).resolvedDescriptions.single.formatted,
      'Old achievement',
    );
    final profile = UserProfile.fromJson(
      jsonDecode(
        jsonEncode(
          const UserProfile(
            id: 'owner',
            projects: [ProjectEntry(id: 'p', descriptionItems: items)],
            experiences: [ExperienceEntry(id: 'e', descriptionItems: items)],
          ).toJson(),
        ),
      ),
    );
    expect(
      profile.projects.single
          .copyWith(title: 'Changed')
          .resolvedDescriptions
          .first
          .label,
      'Architecture',
    );
    expect(
      profile.experiences.single
          .copyWith(company: 'Changed')
          .resolvedDescriptions
          .last
          .label,
      '',
    );
    expect(
      profile.projects.single
          .copyWith(descriptionItems: [])
          .resolvedDescriptions,
      isEmpty,
    );
    expect(
      profile.projects.single
          .copyWith(description: 'Replacement')
          .resolvedDescriptions
          .single
          .text,
      'Replacement',
    );
  });

  testWidgets(
    'items can be added with or without a heading, edited, removed and pending text saved',
    (tester) async {
      var value = <DescriptionItem>[];
      final key = GlobalKey<DescriptionItemsEditorState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: DescriptionItemsEditor(
                  key: key,
                  items: value,
                  onChanged: (items) => setState(() => value = items),
                ),
              ),
            ),
          ),
        ),
      );
      final heading = find.descendant(
        of: find.byKey(const ValueKey('description-heading')),
        matching: find.byType(TextField),
      );
      await tester.tap(heading);
      await tester.enterText(heading, 'Architecture');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Architecture').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        'Clean architecture with BLoC Cubit',
      );
      await tester.tap(find.text('Add item'));
      await tester.pumpAndSettle();
      expect(value.single.label, 'Architecture');
      await tester.enterText(find.byType(TextField).last, 'Delivered the app');
      await tester.tap(find.text('Add item'));
      await tester.pumpAndSettle();
      expect(value.last.label, '');
      await tester.tap(find.byTooltip('Edit item').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        'Updated architecture',
      );
      await tester.tap(find.text('Update item'));
      await tester.pumpAndSettle();
      expect(value.first.text, 'Updated architecture');
      await tester.tap(find.byTooltip('Remove item').last);
      await tester.pumpAndSettle();
      expect(value.length, 1);
      await tester.enterText(find.byType(TextField).last, 'Pending item');
      expect(key.currentState!.commitPending(), isTrue);
      await tester.pumpAndSettle();
      expect(value.last.text, 'Pending item');
      await tester.tap(find.text('Add item'));
      await tester.pumpAndSettle();
      expect(value.length, 2);
    },
  );

  testWidgets(
    'custom headings can be typed directly, reopened, reused and cleared',
    (tester) async {
      var value = <DescriptionItem>[];
      final key = GlobalKey<DescriptionItemsEditorState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: DescriptionItemsEditor(
                  key: key,
                  items: value,
                  onChanged: (items) => setState(() => value = items),
                ),
              ),
            ),
          ),
        ),
      );
      final heading = find.descendant(
        of: find.byKey(const ValueKey('description-heading')),
        matching: find.byType(TextField),
      );
      await tester.enterText(heading, 'Cloud cost optimization');
      await tester.enterText(
        find.widgetWithText(TextField, 'Entry text'),
        'Reduced monthly hosting costs',
      );
      expect(key.currentState!.commitPending(), isTrue);
      await tester.pumpAndSettle();
      expect(value.single.label, 'Cloud cost optimization');
      expect(
        DescriptionItem.fromJson(jsonDecode(jsonEncode(value.single.toJson())))
            .label,
        'Cloud cost optimization',
      );

      await tester.tap(find.byTooltip('Edit item'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(heading).controller!.text,
        'Cloud cost optimization',
      );
      await tester.enterText(heading, 'التكامل مع الأنظمة');
      await tester.tap(find.text('Update item'));
      await tester.pumpAndSettle();
      expect(value.single.label, 'التكامل مع الأنظمة');

      await tester.tap(heading);
      await tester.enterText(heading, 'التكامل');
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(MenuItemButton, 'التكامل مع الأنظمة'),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(heading).controller!.text,
        'التكامل مع الأنظمة',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Entry text'),
        'A second item',
      );
      expect(key.currentState!.commitPending(), isTrue);
      await tester.pumpAndSettle();
      expect(value.last.label, 'التكامل مع الأنظمة');

      await tester.tap(heading);
      await tester.enterText(heading, 'Risk');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'Risk management'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(heading).controller!.text,
        'Risk management',
      );
      await tester.enterText(heading, '');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'No heading'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Entry text'),
        'Text without a heading',
      );
      expect(key.currentState!.commitPending(), isTrue);
      await tester.pumpAndSettle();
      expect(value.last.label, '');
      expect(tester.takeException(), isNull);
    },
  );

  final document = const CvDocument(
    id: 'd',
    ownerId: 'owner',
    title: 'CV',
    design: DocumentDesign(
      sections: [
        SectionConfig(id: 'experience', kind: SectionKind.experience),
        SectionConfig(id: 'projects', kind: SectionKind.projects),
      ],
    ),
  );
  final profile = const UserProfile(
    id: 'owner',
    details: ProfileDetails(fullName: 'Test Person'),
    experiences: [
      ExperienceEntry(
        id: 'e',
        position: 'Engineer',
        company: 'Company',
        descriptionItems: items,
      ),
    ],
    projects: [ProjectEntry(id: 'p', title: 'App', descriptionItems: items)],
  );
  final resolved = ResolvedDocument.resolve(
    document: document,
    profile: profile,
    defaultTitle: defaultTitleEn,
  );

  test('CV, PDF, ATS and Word preserve bullets, optional labels and bold heading runs', () async {
    final bullets = flattenDocument(resolved)
        .where((line) => line.isBullet)
        .toList();
    expect(bullets.map((line) => line.text), [
      for (var i = 0; i < 2; i++) ...items.map((e) => e.formatted),
    ]);
    expect(bullets.first.boldPrefix, 'Architecture: ');
    expect(bullets[1].boldPrefix, isNull);
    final zip = ZipDecoder().decodeBytes(
      const DocxDocumentBuilder().build(DocxBuildRequest(resolved: resolved)),
    );
    final xml = utf8.decode(zip.findFile('word/document.xml')!.content);
    expect(
      RegExp(
        r'<w:b/><w:bCs/></w:rPr><w:t xml:space="preserve">Architecture: </w:t>',
      ).allMatches(xml).length,
      2,
    );
    for (final ats in [false, true]) {
      final result = await offlineExporter().export(
        document: document,
        profile: profile,
        mode: ats ? ExportMode.atsFriendly : ExportMode.designed,
      );
      final text = extractPdfText(result.bytes);
      expect(
        text,
        contains('Architecture: Clean architecture with BLoC Cubit'),
      );
      expect(text, contains('Delivered the app'));
    }
  });

  testWidgets(
    'CV renders labelled descriptions in flat, card and gallery styles',
    (tester) async {
      for (final style in ['flat', 'card', 'gallery']) {
        final styled = document.copyWith(
          design: document.design.copyWith(
            presentation: document.design.presentation.copyWith(
              projectCardStyle: style,
            ),
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DocumentView(
                  resolved: ResolvedDocument.resolve(
                    document: styled,
                    profile: profile,
                    defaultTitle: defaultTitleEn,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.byType(DescriptionItemText), findsNWidgets(4));
        expect(tester.takeException(), isNull);
      }
    },
  );
}
