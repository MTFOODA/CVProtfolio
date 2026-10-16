import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/document_models.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/export/docx_builder.dart';
import 'package:cv_portfolio_maker/core/render/resolved_document.dart';
import 'package:cv_portfolio_maker/core/render/section_titles.dart';

ResolvedDocument buildResolved({
  List<SectionConfig>? sections,
  List<ExperienceEntry> experiences = const [],
  List<ProjectEntry> projects = const [],
  String? fullName = 'Ada Lovelace',
}) {
  final document = CvDocument(
    id: 'd1',
    ownerId: 'u1',
    title: 'CV',
    design: DocumentDesign(
      sections:
          sections ??
          const [
            SectionConfig(id: 'experience', kind: SectionKind.experience),
            SectionConfig(id: 'skills', kind: SectionKind.skills),
          ],
    ),
  );
  final profile = UserProfile(
    id: 'u1',
    details: ProfileDetails(
      fullName: fullName,
      professionalTitle: 'Mathematician',
      email: 'ada@example.com',
    ),
    experiences: experiences,
    skills: const [SkillEntry(id: 's1', name: 'Mathematics')],
    projects: projects,
  );
  return ResolvedDocument.resolve(
    document: document,
    profile: profile,
    defaultTitle: defaultTitleEn,
  );
}

/// Opens the generated package as a ZIP archive.
Archive openPackage(Uint8List bytes) => ZipDecoder().decodeBytes(bytes);

String readPart(Archive archive, String name) {
  final file = archive.files.firstWhere(
    (f) => f.name == name,
    orElse: () => throw StateError('missing part $name'),
  );
  return utf8.decode(file.content as List<int>);
}

void main() {
  const builder = DocxDocumentBuilder();

  group('DOCX package', () {
    test('is a real ZIP containing the required OOXML parts', () {
      final bytes = builder.build(
        DocxBuildRequest(
          resolved: buildResolved(
            experiences: const [ExperienceEntry(id: 'e1')],
          ),
        ),
      );

      // ZIP local file header magic.
      expect(bytes.sublist(0, 2), orderedEquals(<int>[0x50, 0x4B]));

      final archive = openPackage(bytes);
      final names = archive.files.map((f) => f.name).toSet();
      expect(names, contains('[Content_Types].xml'));
      expect(names, contains('_rels/.rels'));
      expect(names, contains('word/document.xml'));
      expect(names, contains('word/styles.xml'));
      expect(names, contains('word/numbering.xml'));
      expect(names, contains('word/_rels/document.xml.rels'));
    });

    test('the main part is well-formed WordprocessingML', () {
      final bytes = builder.build(
        DocxBuildRequest(
          resolved: buildResolved(
            experiences: const [ExperienceEntry(id: 'e1')],
          ),
        ),
      );
      final xml = readPart(openPackage(bytes), 'word/document.xml');

      expect(xml, startsWith('<?xml version="1.0" encoding="UTF-8"'));
      expect(xml, contains('<w:document'));
      expect(xml, contains('<w:body>'));
      expect(xml, contains('</w:body>'));
      expect(xml, contains('</w:document>'));
      // Balanced paragraph tags: no truncated or unterminated content.
      expect('<w:p>'.allMatches(xml).length, '</w:p>'.allMatches(xml).length);
    });

    test('contains the document text as editable runs', () {
      final bytes = builder.build(
        DocxBuildRequest(
          resolved: buildResolved(
            experiences: const [
              ExperienceEntry(
                id: 'e1',
                company: 'Analytical Engines Ltd',
                position: 'Lead Analyst',
                descriptions: ['Designed the first algorithm.'],
              ),
            ],
          ),
        ),
      );
      final xml = readPart(openPackage(bytes), 'word/document.xml');

      expect(xml, contains('Ada Lovelace'));
      expect(xml, contains('Mathematician'));
      expect(xml, contains('Professional Experience'));
      expect(xml, contains('Lead Analyst'));
      expect(xml, contains('Analytical Engines Ltd'));
      expect(xml, contains('Designed the first algorithm.'));
      expect(xml, contains('Skills'));
      expect(xml, contains('Mathematics'));
      // Text lives inside text runs, which is what makes it editable.
      expect(xml, contains('<w:t xml:space="preserve">'));
    });

    test('description lines become real list items', () {
      final bytes = builder.build(
        DocxBuildRequest(
          resolved: buildResolved(
            experiences: const [
              ExperienceEntry(id: 'e1', descriptions: ['A bullet']),
            ],
          ),
        ),
      );
      final xml = readPart(openPackage(bytes), 'word/document.xml');
      expect(xml, contains('<w:numPr>'));
      expect(xml, contains('<w:numId w:val="1"/>'));
    });

    test('uses A4 page settings and the design margins', () {
      final bytes = builder.build(
        DocxBuildRequest(
          resolved: buildResolved(
            experiences: const [ExperienceEntry(id: 'e1')],
          ),
        ),
      );
      final xml = readPart(openPackage(bytes), 'word/document.xml');
      expect(xml, contains('<w:pgSz w:w="11906" w:h="16838"/>'));
      // Default page margin is 40pt => 800 twips.
      expect(xml, contains('w:top="800"'));
    });

    test('hidden sections are absent from the package', () {
      final bytes = builder.build(
        DocxBuildRequest(
          resolved: buildResolved(
            sections: const [
              SectionConfig(
                id: 'experience',
                kind: SectionKind.experience,
                visible: false,
              ),
              SectionConfig(id: 'skills', kind: SectionKind.skills),
            ],
            experiences: const [
              ExperienceEntry(id: 'e1', company: 'Secret Corp'),
            ],
          ),
        ),
      );
      final xml = readPart(openPackage(bytes), 'word/document.xml');
      expect(xml, isNot(contains('Secret Corp')));
      expect(xml, contains('Mathematics'));
    });

    test('escapes user content so the XML stays valid', () {
      final bytes = builder.build(
        DocxBuildRequest(
          resolved: buildResolved(
            fullName: 'A & B <script>',
            experiences: const [ExperienceEntry(id: 'e1')],
          ),
        ),
      );
      final xml = readPart(openPackage(bytes), 'word/document.xml');
      expect(xml, contains('A &amp; B &lt;script&gt;'));
      expect(xml, isNot(contains('<script>')));
    });

    test('project URLs become external hyperlink relationships', () {
      final bytes = builder.build(
        DocxBuildRequest(
          resolved: buildResolved(
            sections: const [
              SectionConfig(id: 'projects', kind: SectionKind.projects),
            ],
            projects: const [
              ProjectEntry(
                id: 'p1',
                title: 'Engine',
                demoUrl: 'https://x.test/d',
              ),
            ],
          ),
        ),
      );
      final archive = openPackage(bytes);
      final xml = readPart(archive, 'word/document.xml');
      final rels = readPart(archive, 'word/_rels/document.xml.rels');

      expect(xml, contains('<w:hyperlink r:id="rIdLink1">'));
      expect(rels, contains('Target="https://x.test/d"'));
      expect(rels, contains('TargetMode="External"'));
    });

    test('dangerous URLs are never written as relationships', () {
      final bytes = builder.build(
        DocxBuildRequest(
          resolved: buildResolved(
            sections: const [
              SectionConfig(id: 'projects', kind: SectionKind.projects),
            ],
            projects: const [
              ProjectEntry(
                id: 'p1',
                title: 'Engine',
                demoUrl: 'javascript:alert(1)',
              ),
            ],
          ),
        ),
      );
      final rels = readPart(openPackage(bytes), 'word/_rels/document.xml.rels');
      expect(rels, isNot(contains('javascript:')));
    });

    test('right-to-left documents are marked as bidirectional', () {
      final document = CvDocument(
        id: 'd1',
        ownerId: 'u1',
        title: 'CV',
        isRtl: true,
        design: const DocumentDesign(
          isRtl: true,
          sections: [SectionConfig(id: 'skills', kind: SectionKind.skills)],
        ),
      );
      final resolved = ResolvedDocument.resolve(
        document: document,
        profile: const UserProfile(
          id: 'u1',
          details: ProfileDetails(fullName: 'أحمد'),
          skills: [SkillEntry(id: 's1', name: 'الرياضيات')],
        ),
        defaultTitle: defaultTitleAr,
      );

      final xml = readPart(
        openPackage(builder.build(DocxBuildRequest(resolved: resolved))),
        'word/document.xml',
      );
      expect(xml, contains('<w:bidi/>'));
      expect(xml, contains('<w:rtl/>'));
      // Arabic is stored as plain Unicode: Word performs the shaping.
      expect(xml, contains('أحمد'));
    });

    test('stores Arabic logically, never as shaped presentation forms', () {
      // Pre-shaping DOCX text would make Word shape already-shaped text and
      // render it incorrectly, so the logical code points must survive intact.
      final document = CvDocument(
        id: 'd1',
        ownerId: 'u1',
        title: 'CV',
        isRtl: true,
        design: const DocumentDesign(
          isRtl: true,
          sections: [
            SectionConfig(id: 'experience', kind: SectionKind.experience),
          ],
        ),
      );
      final resolved = ResolvedDocument.resolve(
        document: document,
        profile: const UserProfile(
          id: 'u1',
          details: ProfileDetails(fullName: 'أحمد بن علي'),
          experiences: [
            ExperienceEntry(
              id: 'e1',
              company: 'Cairo Software',
              position: 'مهندس برمجيات',
              descriptions: ['بناء منصة الجوال'],
            ),
          ],
        ),
        defaultTitle: defaultTitleAr,
      );

      final xml = readPart(
        openPackage(builder.build(DocxBuildRequest(resolved: resolved))),
        'word/document.xml',
      );

      expect(xml, contains('أحمد بن علي'));
      expect(xml, contains('مهندس برمجيات'));
      expect(xml, contains('بناء منصة الجوال'));
      expect(xml, contains('Cairo Software'));
      final shaped = xml.codeUnits.where((c) => c >= 0xFB50 && c <= 0xFEFF);
      expect(
        shaped,
        isEmpty,
        reason: 'DOCX must stay logical; Word applies the joining itself',
      );
    });

    test('a long document keeps every entry and stays well formed', () {
      final bytes = builder.build(
        DocxBuildRequest(
          resolved: buildResolved(
            experiences: [
              for (var i = 0; i < 120; i++)
                ExperienceEntry(
                  id: 'e$i',
                  company: 'Company $i',
                  position: 'Position $i',
                  descriptions: ['Did a great many things at $i ' * 4],
                ),
            ],
          ),
        ),
      );
      final xml = readPart(openPackage(bytes), 'word/document.xml');

      expect(xml, contains('Position 0'));
      expect(xml, contains('Position 119'));
      expect('<w:p>'.allMatches(xml).length, '</w:p>'.allMatches(xml).length);
      expect(xml, contains('</w:body></w:document>'));
    });

    test('every internal relationship target exists in the package', () {
      final archive = openPackage(
        builder.build(
          DocxBuildRequest(
            resolved: buildResolved(
              sections: const [
                SectionConfig(id: 'projects', kind: SectionKind.projects),
              ],
              projects: const [
                ProjectEntry(id: 'p1', title: 'A', demoUrl: 'https://x.test/1'),
                ProjectEntry(id: 'p2', title: 'B', demoUrl: 'https://x.test/2'),
              ],
            ),
          ),
        ),
      );
      final names = archive.files.map((f) => f.name).toSet();
      final rels = readPart(archive, 'word/_rels/document.xml.rels');

      for (final match in RegExp(
        r'Target="([^"]+)"(?![^>]*TargetMode="External")',
      ).allMatches(rels)) {
        final target = match.group(1)!;
        expect(
          names,
          contains('word/$target'),
          reason: 'relationship target $target is missing',
        );
      }
      // Two distinct links, two distinct relationship ids.
      final ids = RegExp(r'Id="(rIdLink\d+)"')
          .allMatches(rels)
          .map((m) => m.group(1))
          .toSet();
      expect(ids.length, 2);
    });

    test('namespaces and content types are declared for every part', () {
      final archive = openPackage(
        builder.build(
          DocxBuildRequest(
            resolved: buildResolved(
              experiences: const [ExperienceEntry(id: 'e1')],
            ),
          ),
        ),
      );
      final contentTypes = readPart(archive, '[Content_Types].xml');
      for (final part in [
        '/word/document.xml',
        '/word/styles.xml',
        '/word/numbering.xml',
      ]) {
        expect(contentTypes, contains('PartName="$part"'));
      }
      expect(contentTypes, contains('<Default Extension="rels"'));

      final rootRels = readPart(archive, '_rels/.rels');
      expect(rootRels, contains('Target="word/document.xml"'));
    });
  });
}
