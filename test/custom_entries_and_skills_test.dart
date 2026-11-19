import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as im;
import 'package:flutter_test/flutter_test.dart';
import 'package:cv_portfolio_maker/core/design/skill_icons.dart';
import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/document_models.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/export/document_text.dart';
import 'package:cv_portfolio_maker/core/export/docx_builder.dart';
import 'package:cv_portfolio_maker/core/render/resolved_document.dart';
import 'package:cv_portfolio_maker/core/render/section_titles.dart';
import 'package:cv_portfolio_maker/data/repositories.dart';

void main() {
  const entry = CustomEntry(
    id: 'credential',
    title: 'Cloud certification',
    issuer: 'Learning institute',
    credentialId: 'CERT-42',
    dateRange: DateRange(startIso: '2024-01-01', isCurrent: true),
    content: 'Architecture and delivery',
    url: 'https://example.test/verify',
    imageUrl: 'owner/certificate.png',
  );
  const profile = UserProfile(
    id: 'owner',
    customSections: [
      CustomSection(id: 'training', title: 'My training', entries: [entry]),
    ],
  );
  test('old JSON is readable and extended entries/projects retain dates and optional fields', () {
    expect(
      CustomEntry.fromJson({'id': 'old', 'title': 'Old', 'content': 'Kept'})
          .visible,
      isTrue,
    );
    final restored = UserProfile.fromJson(profile.toJson())
        .customSections
        .single
        .entries
        .single;
    expect(restored.toJson(), entry.toJson());
    const project = ProjectEntry(
      id: 'p',
      dateRange: DateRange(startIso: '2020-01', endIso: '2022-03'),
    );
    expect(
      ProjectEntry.fromJson(project.toJson()).dateRange.toJson(),
      project.dateRange.toJson(),
    );
    expect(ProjectEntry.fromJson({'id': 'old'}).dateRange.isEmpty, isTrue);
  });
  test('old Review drafts migrate while new additional-entry drafts retain their step', () {
    expect(
      CvBuilderDraft.fromJson({'profile': profile.toJson(), 'step': 6}).step,
      7,
    );
    expect(
      CvBuilderDraft.fromJson(
        CvBuilderDraft(profile: profile, step: 6).toJson(),
      ).step,
      6,
    );
    expect(
      CvBuilderDraft.fromJson(
        CvBuilderDraft(profile: profile, step: 7).toJson(),
      ).step,
      7,
    );
  });
  test('custom sections join resolution and preserve visibility, order and structured output', () {
    const document = CvDocument(id: 'cv', ownerId: 'owner', title: 'CV');
    final resolved = ResolvedDocument.resolve(
      document: document,
      profile: profile,
      defaultTitle: defaultTitleResolver('en'),
    );
    expect(
      resolved.sections.expand((section) => section.customEntries).single.id,
      entry.id,
    );
    expect(plainText(resolved), contains('CERT-42'));
    expect(plainText(resolved), contains('https://example.test/verify'));
    final renamed = ResolvedDocument.resolve(
      document: document.copyWith(design: resolved.design),
      profile: profile.copyWith(
        customSections: [
          profile.customSections.single.copyWith(title: 'Renamed training'),
        ],
      ),
      defaultTitle: defaultTitleResolver('en'),
    );
    expect(renamed.sections.single.title, 'Renamed training');
    final overridden = ResolvedDocument.resolve(
      document: document.copyWith(
        design: resolved.design.copyWith(
          sections: [
            resolved.design.sections.single.copyWith(
              customTitle: () => 'CV heading',
            ),
          ],
        ),
      ),
      profile: profile,
      defaultTitle: defaultTitleResolver('en'),
    );
    expect(overridden.sections.single.title, 'CV heading');
    const hidden = CvDocument(
      id: 'hidden',
      ownerId: 'owner',
      title: 'CV',
      design: DocumentDesign(
        sections: [
          SectionConfig(
            id: 'section',
            kind: SectionKind.custom,
            customSectionId: 'training',
            visible: false,
          ),
        ],
      ),
    );
    final denied = ResolvedDocument.resolve(
      document: hidden,
      profile: profile,
      defaultTitle: defaultTitleResolver('en'),
    );
    expect(denied.sections.expand((section) => section.customEntries), isEmpty);
  });
  test(
    'DOCX embeds a visible entry image and omits unused/hidden media bytes',
    () {
      final image = Uint8List.fromList(
        im.encodePng(im.Image(width: 4, height: 3)),
      );
      final resolved = ResolvedDocument.resolve(
        document: const CvDocument(id: 'cv', ownerId: 'owner', title: 'CV'),
        profile: profile,
        defaultTitle: defaultTitleResolver('en'),
      );
      final bytes = const DocxDocumentBuilder().build(
        DocxBuildRequest(
          resolved: resolved,
          images: {
            'owner/certificate.png': image,
            'owner/not-selected.png': image,
          },
        ),
      );
      final zip = ZipDecoder().decodeBytes(bytes);
      expect(
        zip.files.where((file) => file.name.startsWith('word/media/')).length,
        1,
      );
      final xml = utf8.decode(zip.findFile('word/document.xml')!.content);
      expect(xml, contains('<w:drawing>'));
      expect(xml, contains('CERT-42'));
      expect(
        utf8.decode(zip.findFile('word/_rels/document.xml.rels')!.content),
        contains('relationships/image'),
      );
    },
  );
  test('technology catalogue supports exact names, aliases and keeps legacy choices', () {
    expect(skillIcons.length, greaterThan(130));
    expect(skillIcons.map((icon) => icon.id).toSet().length, skillIcons.length);
    for (final query in [
      'React',
      'react.js',
      'Python',
      'TypeScript',
      'C++',
      'C#',
      'K8s',
      'Postgres',
      'SQLAlchemy',
      'Supabase',
      'فلاتر',
    ]) {
      expect(exactSkillIcon(query), isNotNull, reason: query);
      expect(matchingSkillIcons(query), isNotEmpty, reason: query);
    }
    expect(skillIcon('flutter').icon.fontFamily, 'CvBrandIcons');
    expect(skillIcon('general').id, 'general');
    expect(skillIcon('unknown-saved-id').id, 'general');
  });
}
