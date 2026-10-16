import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/document_models.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/export/document_text.dart';
import 'package:cv_portfolio_maker/core/export/export_delivery.dart';
import 'package:cv_portfolio_maker/core/export/export_fonts.dart';
import 'package:cv_portfolio_maker/core/export/export_service.dart';
import 'package:cv_portfolio_maker/core/export/export_validation.dart';
import 'package:cv_portfolio_maker/core/export/pdf_sections.dart';
import 'package:cv_portfolio_maker/features/export/export_sheet.dart';

import 'support/pdf_text.dart' as raw_pdf;

/// Extracts the real text from generated PDF bytes.
///
/// The underlying parser reads actual content streams and `/ToUnicode` CMaps;
/// only whitespace runs are collapsed here, so assertions about content and
/// reading order are unaffected by how the PDF engine positioned each word.
String extractPdfText(Uint8List bytes) =>
    raw_pdf.extractPdfText(bytes).replaceAll(RegExp(r'\s+'), ' ').trim();

/// An exporter that never touches the network, so these tests are hermetic.
DocumentExporter offlineExporter() =>
    DocumentExporter(fonts: const BaseFontSource());

/// The default section set used by most tests.
///
/// `profile` is present so the professional summary is part of the document;
/// the resolver renders it in the header rather than as its own section.
const List<SectionConfig> testSections = [
  SectionConfig(id: 'profile', kind: SectionKind.profile),
  SectionConfig(id: 'experience', kind: SectionKind.experience),
  SectionConfig(id: 'education', kind: SectionKind.education),
  SectionConfig(id: 'skills', kind: SectionKind.skills),
];

CvDocument buildDocument({
  DocumentDesign? design,
  String title = 'Ada CV',
  String ownerId = 'user-1',
  DocumentType type = DocumentType.cv,
  bool isRtl = false,
}) => CvDocument(
  id: 'doc-1',
  ownerId: ownerId,
  title: title,
  type: type,
  isRtl: isRtl,
  design: design ?? const DocumentDesign(sections: testSections),
);

UserProfile buildProfile({
  String? fullName = 'Ada Lovelace',
  String? title = 'Mathematician',
  String? email = 'ada@example.com',
  String? phone = '+44 20 7946 0000',
  String? summary = 'Pioneer of computing.',
  String? avatarUrl,
  List<ExperienceEntry> experiences = const [],
  List<EducationEntry> education = const [],
  List<SkillEntry> skills = const [],
  List<ProjectEntry> projects = const [],
  List<LanguageEntry> languages = const [],
}) => UserProfile(
  id: 'user-1',
  details: ProfileDetails(
    fullName: fullName,
    professionalTitle: title,
    email: email,
    phone: phone,
    summary: summary,
    avatarUrl: avatarUrl,
  ),
  experiences: experiences,
  education: education,
  skills: skills,
  projects: projects,
  languages: languages,
);

/// A document with enough content to exercise every section renderer.
UserProfile richProfile() => buildProfile(
  experiences: const [
    ExperienceEntry(
      id: 'e1',
      company: 'Analytical Engines Ltd',
      position: 'Lead Analyst',
      location: 'London',
      employmentType: 'Full-time',
      dateRange: DateRange(startIso: '1842-01-01', endIso: '1843-01-01'),
      descriptions: ['Designed the first algorithm.'],
    ),
  ],
  education: const [
    EducationEntry(
      id: 'ed1',
      institution: 'University of London',
      qualification: 'BSc',
      fieldOfStudy: 'Mathematics',
      dateRange: DateRange(startIso: '1836-01-01', endIso: '1840-01-01'),
      grade: 'First class',
      description: 'Specialised in analysis.',
    ),
  ],
  skills: const [
    SkillEntry(id: 's1', name: 'Mathematics'),
    SkillEntry(id: 's2', name: 'Analytical engines'),
  ],
  languages: const [LanguageEntry(id: 'l1', name: 'English', proficiency: 5)],
  projects: const [
    ProjectEntry(
      id: 'p1',
      title: 'Difference Engine notes',
      summary: 'Published notes on the engine.',
      description: 'A detailed set of notes.',
      technologies: ['Punch cards', 'Mathematics'],
      demoUrl: 'https://example.com/demo',
      sourceUrl: 'https://example.com/source',
    ),
  ],
);

void main() {
  // ------------------------------------------------------------ basic output

  group('PDF generation', () {
    test('designed export produces a parseable PDF', () async {
      final result = await offlineExporter().export(
        document: buildDocument(),
        profile: richProfile(),
        mode: ExportMode.designed,
      );

      expect(result.bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(result.bytes.take(5)), startsWith('%PDF-'));
      expect(String.fromCharCodes(result.bytes).trimRight(), endsWith('%%EOF'));
      expect(result.pageCount, greaterThanOrEqualTo(1));
      expect(result.mode, ExportMode.designed);
    });

    test('ATS export produces a parseable PDF', () async {
      final result = await offlineExporter().export(
        document: buildDocument(),
        profile: richProfile(),
        mode: ExportMode.atsFriendly,
      );

      expect(String.fromCharCodes(result.bytes.take(5)), startsWith('%PDF-'));
      expect(result.mode, ExportMode.atsFriendly);
    });
  });

  // ------------------------------------------------------ content verification

  group('designed PDF content', () {
    late String text;

    setUp(() async {
      final result = await offlineExporter().export(
        document: buildDocument(),
        profile: richProfile(),
        mode: ExportMode.designed,
      );
      text = extractPdfText(result.bytes);
    });

    test('the PDF really contains extractable text', () {
      expect(text.trim(), isNotEmpty);
    });

    test('includes the profile name, title and contact labels', () {
      expect(text, contains('Ada Lovelace'));
      expect(text, contains('Mathematician'));
      expect(text, contains('Email: ada@example.com'));
      expect(text, contains('Phone: +44 20 7946 0000'));
    });

    test('includes every section heading and entry', () {
      expect(text, contains('Professional Experience'));
      expect(text, contains('Education'));
      expect(text, contains('Skills'));
      expect(text, contains('Lead Analyst'));
      expect(text, contains('Analytical Engines Ltd'));
      expect(text, contains('Designed the first algorithm.'));
      expect(text, contains('University of London'));
      expect(text, contains('Mathematics'));
    });

    test('the summary is rendered', () {
      expect(text, contains('Pioneer of computing.'));
    });

    test('contains no empty headings or placeholder artefacts', () {
      expect(text, isNot(contains('null')));
    });
  });

  group('section order and visibility', () {
    test('sections follow the stored configuration order', () async {
      final document = buildDocument(
        design: const DocumentDesign(
          sections: [
            SectionConfig(id: 'skills', kind: SectionKind.skills),
            SectionConfig(id: 'experience', kind: SectionKind.experience),
          ],
        ),
      );

      final result = await offlineExporter().export(
        document: document,
        profile: richProfile(),
        mode: ExportMode.designed,
      );
      final text = extractPdfText(result.bytes);

      final skills = text.indexOf('Skills');
      final experience = text.indexOf('Professional Experience');
      expect(skills, greaterThanOrEqualTo(0));
      expect(experience, greaterThan(skills));
    });

    test('a hidden section is absent from the PDF', () async {
      final document = buildDocument(
        design: const DocumentDesign(
          sections: [
            SectionConfig(
              id: 'experience',
              kind: SectionKind.experience,
              visible: false,
            ),
            SectionConfig(id: 'skills', kind: SectionKind.skills),
          ],
        ),
      );

      final result = await offlineExporter().export(
        document: document,
        profile: richProfile(),
        mode: ExportMode.designed,
      );
      final text = extractPdfText(result.bytes);

      expect(text, contains('Skills'));
      expect(text, isNot(contains('Professional Experience')));
      expect(text, isNot(contains('Lead Analyst')));
    });

    test('a hidden entry is absent from the PDF', () async {
      final document = buildDocument(
        design: const DocumentDesign(
          sections: [
            SectionConfig(
              id: 'experience',
              kind: SectionKind.experience,
              hiddenEntryIds: ['e1'],
            ),
          ],
        ),
      );

      final result = await offlineExporter().export(
        document: document,
        profile: richProfile(),
        mode: ExportMode.designed,
      );
      final text = extractPdfText(result.bytes);

      expect(text, isNot(contains('Analytical Engines Ltd')));
    });
  });

  group('ATS export', () {
    test('preserves all visible content in a single column', () async {
      final document = buildDocument(
        design: const DocumentDesign(
          layoutMode: LayoutMode.two,
          sections: [
            SectionConfig(
              id: 'experience',
              kind: SectionKind.experience,
              slot: ColumnSlot.left,
            ),
            SectionConfig(
              id: 'skills',
              kind: SectionKind.skills,
              slot: ColumnSlot.right,
            ),
            SectionConfig(id: 'projects', kind: SectionKind.projects),
          ],
        ),
      );

      final exporter = offlineExporter();
      final resolved = exporter.resolveFor(
        document: document,
        profile: richProfile(),
        mode: ExportMode.atsFriendly,
        languageCode: 'en',
      );

      // The ATS design is normalised to one column ...
      expect(resolved.design.layoutMode, LayoutMode.one);
      expect(resolved.design.presentation.avatarShape, AvatarShape.hidden);
      // ... while the saved design is untouched.
      expect(document.design.layoutMode, LayoutMode.two);
      expect(document.design.sections[0].slot, ColumnSlot.left);

      final result = await exporter.export(
        document: document,
        profile: richProfile(),
        mode: ExportMode.atsFriendly,
      );
      final text = extractPdfText(result.bytes);

      // Nothing is dropped by the simplification.
      expect(text, contains('Lead Analyst'));
      expect(text, contains('Difference Engine notes'));
      expect(text, contains('Mathematics'));
    });

    test('contact details stay in the body of the document', () async {
      final result = await offlineExporter().export(
        document: buildDocument(),
        profile: richProfile(),
        mode: ExportMode.atsFriendly,
      );
      final text = extractPdfText(result.bytes);

      expect(text, contains('Email: ada@example.com'));
      expect(text, contains('Phone:'));
    });
  });

  // ------------------------------------------------------------- pagination

  group('pagination and long content', () {
    UserProfile longProfile() => buildProfile(
      experiences: [
        for (var i = 0; i < 30; i++)
          ExperienceEntry(
            id: 'e$i',
            company: 'Company $i',
            position: 'Position $i',
            descriptions: ['Responsibility line for entry $i ' * 4],
          ),
      ],
      skills: [
        for (var i = 0; i < 40; i++) SkillEntry(id: 's$i', name: 'Skill$i'),
      ],
    );

    test('long content spans multiple pages without losing content', () async {
      final result = await offlineExporter().export(
        document: buildDocument(
          design: const DocumentDesign(
            sections: [
              SectionConfig(id: 'experience', kind: SectionKind.experience),
              SectionConfig(id: 'skills', kind: SectionKind.skills),
            ],
          ),
        ),
        profile: longProfile(),
        mode: ExportMode.designed,
      );

      expect(result.pageCount, greaterThan(1));

      final text = extractPdfText(result.bytes);
      // The first and the last entry both survive.
      expect(text, contains('Position 0'));
      expect(text, contains('Position 29'));
      expect(text, contains('Skill39'));
    });

    test('an explicit page break gets its own page', () async {
      final result = await offlineExporter().export(
        document: buildDocument(
          design: const DocumentDesign(
            sections: [
              SectionConfig(id: 'skills', kind: SectionKind.skills),
              SectionConfig(id: 'pb', kind: SectionKind.pageBreak),
              SectionConfig(id: 'experience', kind: SectionKind.experience),
            ],
          ),
        ),
        profile: richProfile(),
        mode: ExportMode.designed,
      );

      expect(result.pageCount, greaterThanOrEqualTo(2));
      final text = extractPdfText(result.bytes);
      expect(text, contains('Skills'));
      expect(text, contains('Professional Experience'));
    });

    test('a two-column document renders and keeps all content', () async {
      final result = await offlineExporter().export(
        document: buildDocument(
          design: const DocumentDesign(
            layoutMode: LayoutMode.two,
            sections: [
              SectionConfig(
                id: 'experience',
                kind: SectionKind.experience,
                slot: ColumnSlot.left,
              ),
              SectionConfig(
                id: 'skills',
                kind: SectionKind.skills,
                slot: ColumnSlot.right,
              ),
            ],
          ),
        ),
        profile: richProfile(),
        mode: ExportMode.designed,
      );

      final text = extractPdfText(result.bytes);
      expect(text, contains('Professional Experience'));
      expect(text, contains('Skills'));
      expect(text, contains('Lead Analyst'));
      expect(text, contains('Analytical engines'));
    });

    test('a mixed layout keeps full-width and column content', () async {
      final result = await offlineExporter().export(
        document: buildDocument(
          design: const DocumentDesign(
            layoutMode: LayoutMode.mix,
            sections: [
              SectionConfig(
                id: 'experience',
                kind: SectionKind.experience,
                slot: ColumnSlot.left,
              ),
              SectionConfig(id: 'projects', kind: SectionKind.projects),
              SectionConfig(
                id: 'skills',
                kind: SectionKind.skills,
                slot: ColumnSlot.right,
              ),
            ],
          ),
        ),
        profile: richProfile(),
        mode: ExportMode.designed,
      );

      final text = extractPdfText(result.bytes);
      expect(text, contains('Difference Engine notes'));
      expect(text, contains('Lead Analyst'));
      expect(text, contains('Mathematics'));
    });
  });

  // ------------------------------------------------------ errors & validation

  group('export errors and validation', () {
    test('an empty document cannot be exported', () async {
      await expectLater(
        offlineExporter().export(
          document: buildDocument(design: const DocumentDesign()),
          profile: buildProfile(
            fullName: null,
            title: null,
            summary: null,
            email: null,
            phone: null,
          ),
          mode: ExportMode.designed,
        ),
        throwsA(
          isA<ExportException>().having(
            (e) => e.messageKey,
            'messageKey',
            'exportErrorNoContent',
          ),
        ),
      );
    });

    test('missing name and contact details produce warnings', () async {
      final result = await offlineExporter().validate(
        document: buildDocument(),
        profile: buildProfile(fullName: null, email: null, phone: null),
        mode: ExportMode.designed,
      );

      // Warnings do not block export.
      expect(result.canExport, isTrue);
      expect(
        result.warnings.map((i) => i.code),
        containsAll(<String>['exportWarnNoName', 'exportWarnNoContact']),
      );
    });

    test('incomplete entries are counted', () async {
      final result = await offlineExporter().validate(
        document: buildDocument(),
        profile: buildProfile(
          experiences: const [
            ExperienceEntry(id: 'e1'),
            ExperienceEntry(id: 'e2', position: 'Analyst'),
          ],
        ),
        mode: ExportMode.designed,
      );

      final warning = result.warnings.firstWhere(
        (i) => i.code == 'exportWarnIncompleteEntries',
      );
      expect(warning.args?['count'], '1');
    });

    test('Arabic without an Arabic-capable font blocks export', () async {
      final profile = buildProfile(summary: 'مطور برمجيات');

      final validation = await offlineExporter().validate(
        document: buildDocument(),
        profile: profile,
        mode: ExportMode.designed,
      );
      expect(validation.canExport, isFalse);
      expect(validation.errors.first.code, 'exportErrorNoArabicFont');

      await expectLater(
        offlineExporter().export(
          document: buildDocument(),
          profile: profile,
          mode: ExportMode.designed,
        ),
        throwsA(
          isA<ExportException>().having(
            (e) => e.messageKey,
            'messageKey',
            'exportErrorNoArabicFont',
          ),
        ),
      );
    });

    test(
      'an ATS export of a multi-column design explains the change',
      () async {
        final result = await offlineExporter().validate(
          document: buildDocument(
            design: const DocumentDesign(
              layoutMode: LayoutMode.two,
              sections: [SectionConfig(id: 'skills', kind: SectionKind.skills)],
            ),
          ),
          profile: richProfile(),
          mode: ExportMode.atsFriendly,
        );

        expect(
          result.issues.map((i) => i.code),
          contains('exportInfoAtsSimplified'),
        );
      },
    );
  });

  // --------------------------------------------------------------- file names

  group('file names', () {
    test('names the mode in the file name', () {
      expect(
        exportFileName('Ada CV', ExportMode.designed),
        'Ada-CV-Designed.pdf',
      );
      expect(
        exportFileName('Ada CV', ExportMode.atsFriendly),
        'Ada-CV-ATS.pdf',
      );
    });

    test('strips path separators and control characters', () {
      expect(sanitiseFileName('../../etc/passwd'), isNot(contains('/')));
      expect(sanitiseFileName('a:b*c?d'), 'a-b-c-d');
      expect(sanitiseFileName('   '), 'document');
      expect(sanitiseFileName(''), 'document');
      expect(sanitiseFileName('x' * 200).length, lessThanOrEqualTo(60));
    });
  });

  // ------------------------------------------------------ privacy & isolation

  group('privacy and isolation', () {
    test('exporting never changes the saved design', () async {
      final document = buildDocument(
        design: const DocumentDesign(
          layoutMode: LayoutMode.mix,
          templateId: 'creative',
          sections: [
            SectionConfig(
              id: 'experience',
              kind: SectionKind.experience,
              slot: ColumnSlot.left,
            ),
          ],
        ),
      );
      final before = jsonEncode(document.design.toJson());

      await offlineExporter().export(
        document: document,
        profile: richProfile(),
        mode: ExportMode.atsFriendly,
      );

      expect(jsonEncode(document.design.toJson()), before);
    });

    test('exporting one document leaves another untouched', () async {
      final first = buildDocument(
        design: const DocumentDesign(
          layoutMode: LayoutMode.two,
          sections: [SectionConfig(id: 'skills', kind: SectionKind.skills)],
        ),
      );
      final second = buildDocument(
        design: const DocumentDesign(
          sections: [SectionConfig(id: 'skills', kind: SectionKind.skills)],
        ),
      );
      final secondBefore = jsonEncode(second.toJson());

      await offlineExporter().export(
        document: first,
        profile: richProfile(),
        mode: ExportMode.designed,
      );

      expect(jsonEncode(second.toJson()), secondBefore);
    });

    test('hidden content never reaches the flattened text', () {
      final resolved = offlineExporter().resolveFor(
        document: buildDocument(
          design: const DocumentDesign(
            sections: [
              SectionConfig(
                id: 'experience',
                kind: SectionKind.experience,
                visible: false,
              ),
              SectionConfig(
                id: 'skills',
                kind: SectionKind.skills,
                hiddenEntryIds: ['s2'],
              ),
            ],
          ),
        ),
        profile: richProfile(),
        mode: ExportMode.designed,
        languageCode: 'en',
      );

      final text = plainText(resolved);
      expect(text, isNot(contains('Lead Analyst')));
      expect(text, contains('Mathematics'));
      expect(text, isNot(contains('Analytical engines')));
    });
  });

  // --------------------------------------------------------------- portfolio

  group('portfolio documents', () {
    test('portfolio export includes project details and links', () async {
      final result = await offlineExporter().export(
        document: buildDocument(
          type: DocumentType.portfolio,
          design: const DocumentDesign(
            sections: [
              SectionConfig(id: 'projects', kind: SectionKind.projects),
            ],
          ),
        ),
        profile: richProfile(),
        mode: ExportMode.designed,
      );

      final text = extractPdfText(result.bytes);
      expect(text, contains('Projects'));
      expect(text, contains('Difference Engine notes'));
      expect(text, contains('A detailed set of notes.'));
      expect(text, contains('https://example.com/demo'));
    });
  });

  // ----------------------------------------------------------- arabic shaping

  // Shaping and bidirectional ordering are covered in detail (with code-point
  // goldens and mixed-script samples) by test/bidi_and_shaping_test.dart.

  group('script detection', () {
    test('detects logical and shaped Arabic', () {
      expect(containsArabicScript('مرحبا'), isTrue);
      expect(containsArabicScript('\uFE8F'), isTrue);
      expect(containsArabicScript('Ada Lovelace'), isFalse);
    });
  });

  // --------------------------------------------------------------- link safety

  group('external link safety', () {
    test('accepts navigable schemes', () {
      expect(isSafeExternalUrl('https://example.com'), isTrue);
      expect(isSafeExternalUrl('http://example.com'), isTrue);
      expect(isSafeExternalUrl('mailto:a@b.c'), isTrue);
    });

    test('rejects dangerous or malformed destinations', () {
      expect(isSafeExternalUrl('javascript:alert(1)'), isFalse);
      expect(isSafeExternalUrl('file:///etc/passwd'), isFalse);
      expect(isSafeExternalUrl(''), isFalse);
    });
  });

  // ------------------------------------------------------- flattened reading

  group('flattened reading order', () {
    test('follows the section configuration and skips empty sections', () {
      final resolved = offlineExporter().resolveFor(
        document: buildDocument(
          design: const DocumentDesign(
            sections: [
              SectionConfig(id: 'experience', kind: SectionKind.experience),
              SectionConfig(id: 'education', kind: SectionKind.education),
              SectionConfig(id: 'languages', kind: SectionKind.languages),
            ],
          ),
        ),
        profile: richProfile(),
        mode: ExportMode.designed,
        languageCode: 'en',
      );

      final lines = flattenDocument(resolved).map((l) => l.text).toList();
      expect(lines.first, 'Ada Lovelace');
      expect(lines, contains('Professional Experience'));
      expect(lines, contains('Education'));
      expect(lines, contains('Languages'));
      expect(
        lines.indexOf('Professional Experience'),
        lessThan(lines.indexOf('Education')),
      );
      expect(lines.indexOf('Education'), lessThan(lines.indexOf('Languages')));
    });

    test('joins only non-empty parts', () {
      expect(joinParts(['a', null, '', '  ', 'b']), 'a · b');
      expect(joinParts([null, '']), '');
    });
  });

  // ------------------------------------------------- oversized column content

  group('oversized sections in column layouts', () {
    /// Far more than one A4 page once the columns are half width: 30 jobs with
    /// two multi-line descriptions each, 12 education entries and 60 skills.
    UserProfile bulkyProfile() => buildProfile(
      experiences: [
        for (var i = 0; i < 30; i++)
          ExperienceEntry(
            id: 'e$i',
            company: 'Company $i',
            position: 'Position $i',
            location: 'City $i',
            descriptions: [
              'Responsibility A for entry $i ${'detail ' * 12}',
              'Responsibility B for entry $i ${'detail ' * 12}',
            ],
          ),
      ],
      education: [
        for (var i = 0; i < 12; i++)
          EducationEntry(
            id: 'ed$i',
            institution: 'Institute $i',
            qualification: 'Degree $i',
          ),
      ],
      skills: [
        for (var i = 0; i < 60; i++) SkillEntry(id: 's$i', name: 'Skill$i'),
      ],
    );

    DocumentDesign bulkyDesign(LayoutMode mode) => DocumentDesign(
      layoutMode: mode,
      sections: const [
        SectionConfig(
          id: 'experience',
          kind: SectionKind.experience,
          slot: ColumnSlot.left,
        ),
        SectionConfig(
          id: 'education',
          kind: SectionKind.education,
          slot: ColumnSlot.left,
        ),
        SectionConfig(
          id: 'skills',
          kind: SectionKind.skills,
          slot: ColumnSlot.right,
        ),
      ],
    );

    for (final mode in <LayoutMode>[LayoutMode.two, LayoutMode.mix]) {
      test('a section taller than a page paginates in $mode layout', () async {
        final result = await offlineExporter().export(
          document: buildDocument(design: bulkyDesign(mode)),
          profile: bulkyProfile(),
          mode: ExportMode.designed,
        );

        expect(
          result.pageCount,
          greaterThan(1),
          reason: 'the column band must be allowed to span pages',
        );

        final text = extractPdfText(result.bytes);

        // Nothing is silently truncated: the first and the last entries of the
        // oversized section are both present, along with the last lines of the
        // following sections.
        expect(text, contains('Position 0'));
        expect(text, contains('Position 29'));
        expect(text, contains('Responsibility B for entry 29'));
        expect(text, contains('Institute 11'));
        expect(text, contains('Skill59'));
      });
    }

    test(
      'oversized sections still paginate with an explicit page break',
      () async {
        final design = bulkyDesign(LayoutMode.two).copyWith(
          sections: [
            ...bulkyDesign(LayoutMode.two).sections,
            const SectionConfig(id: 'pb', kind: SectionKind.pageBreak),
            const SectionConfig(
              id: 'projects',
              kind: SectionKind.projects,
              slot: ColumnSlot.right,
            ),
          ],
        );

        final result = await offlineExporter().export(
          document: buildDocument(design: design),
          profile: buildProfile(
            experiences: bulkyProfile().experiences,
            education: bulkyProfile().education,
            skills: bulkyProfile().skills,
            projects: const [
              ProjectEntry(id: 'p1', title: 'Difference Engine notes'),
            ],
          ),
          mode: ExportMode.designed,
        );

        expect(result.pageCount, greaterThanOrEqualTo(2));
        final text = extractPdfText(result.bytes);
        expect(text, contains('Position 29'));
        expect(text, contains('Difference Engine notes'));
      },
    );

    test('a single paragraph too long for a column is reported', () async {
      final profile = buildProfile(
        experiences: [
          ExperienceEntry(
            id: 'e1',
            position: 'Analyst',
            descriptions: ['x' * (oversizedTextBlockThreshold + 50)],
          ),
        ],
      );

      final validation = await offlineExporter().validate(
        document: buildDocument(
          design: const DocumentDesign(
            layoutMode: LayoutMode.two,
            sections: [
              SectionConfig(id: 'experience', kind: SectionKind.experience),
            ],
          ),
        ),
        profile: profile,
        mode: ExportMode.designed,
      );

      expect(
        validation.issues.map((i) => i.code),
        contains('exportWarnOversizedEntry'),
      );
      // A warning never blocks the export.
      expect(validation.canExport, isTrue);
    });

    test(
      'the oversized-paragraph warning is not raised for One column',
      () async {
        final profile = buildProfile(
          experiences: [
            ExperienceEntry(
              id: 'e1',
              position: 'Analyst',
              descriptions: ['x' * (oversizedTextBlockThreshold + 50)],
            ),
          ],
        );

        final validation = await offlineExporter().validate(
          document: buildDocument(
            design: const DocumentDesign(
              sections: [
                SectionConfig(id: 'experience', kind: SectionKind.experience),
              ],
            ),
          ),
          profile: profile,
          mode: ExportMode.designed,
        );

        expect(
          validation.issues.map((i) => i.code),
          isNot(contains('exportWarnOversizedEntry')),
        );
      },
    );
  });

  // ------------------------------------------------------------ delivery

  group('delivery feedback', () {
    test('maps every delivery outcome to a distinct message', () {
      expect(deliveryMessageKey(DeliveryOutcome.success), 'exportShareSuccess');
      expect(
        deliveryMessageKey(DeliveryOutcome.dismissed),
        'exportShareCancelled',
      );
      expect(deliveryMessageKey(DeliveryOutcome.failed), 'exportShareFailed');
    });

    test('a failed delivery is never reported as success', () {
      expect(DeliveryOutcome.failed.completed, isFalse);
      expect(DeliveryOutcome.failed.cancelled, isFalse);
      expect(DeliveryOutcome.dismissed.completed, isFalse);
      expect(DeliveryOutcome.dismissed.cancelled, isTrue);
      expect(DeliveryOutcome.success.completed, isTrue);
    });
  });
}
