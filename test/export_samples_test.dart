/// Generates representative exports into `build/export_samples/`.
///
/// This is the artifact generator for the manual visual QA pass:
///
/// ```sh
/// flutter test test/export_samples_test.dart
/// py -3 tools/inspect_pdf.py build/export_samples/05-designed-ar-one.pdf out
/// ```
///
/// The assertions here only prove that every sample is a complete PDF with a
/// sane page count; judging typography, spacing and glyph shapes is a manual
/// step, and the PNGs written by `tools/inspect_pdf.py` are what to review.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/document_models.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/export/export_fonts.dart';
import 'package:cv_portfolio_maker/core/export/export_service.dart';

import 'support/arabic_font.dart';

final Directory _out = Directory('build/export_samples');

/// Writes [result] to `<out>/[name]` and checks it looks like a real PDF.
Future<void> _write(
  String name,
  ExportResult result, {
  int minPages = 1,
}) async {
  await _out.create(recursive: true);
  final file = File('${_out.path}${Platform.pathSeparator}$name');
  await file.writeAsBytes(result.bytes);

  expect(result.bytes.length, greaterThan(1000), reason: name);
  expect(
    String.fromCharCodes(result.bytes.sublist(0, 5)),
    '%PDF-',
    reason: name,
  );
  expect(result.pageCount, greaterThanOrEqualTo(minPages), reason: name);
  // ignore: avoid_print
  print(
    'wrote $name -> ${result.pageCount} page(s), '
    '${result.bytes.length} bytes',
  );
}

const List<SectionConfig> _oneColumnSections = [
  SectionConfig(id: 'profile', kind: SectionKind.profile),
  SectionConfig(id: 'experience', kind: SectionKind.experience),
  SectionConfig(id: 'projects', kind: SectionKind.projects),
  SectionConfig(id: 'education', kind: SectionKind.education),
  SectionConfig(id: 'skills', kind: SectionKind.skills),
];

const List<SectionConfig> _twoColumnSections = [
  SectionConfig(id: 'profile', kind: SectionKind.profile),
  SectionConfig(id: 'skills', kind: SectionKind.skills, slot: ColumnSlot.left),
  SectionConfig(
    id: 'languages',
    kind: SectionKind.languages,
    slot: ColumnSlot.left,
  ),
  SectionConfig(
    id: 'experience',
    kind: SectionKind.experience,
    slot: ColumnSlot.right,
  ),
  SectionConfig(
    id: 'education',
    kind: SectionKind.education,
    slot: ColumnSlot.right,
  ),
];

const List<SectionConfig> _mixSections = [
  SectionConfig(id: 'profile', kind: SectionKind.profile),
  SectionConfig(id: 'experience', kind: SectionKind.experience),
  SectionConfig(id: 'skills', kind: SectionKind.skills, slot: ColumnSlot.left),
  SectionConfig(
    id: 'languages',
    kind: SectionKind.languages,
    slot: ColumnSlot.left,
  ),
  SectionConfig(
    id: 'education',
    kind: SectionKind.education,
    slot: ColumnSlot.right,
  ),
  SectionConfig(id: 'awards', kind: SectionKind.awards, slot: ColumnSlot.right),
];

/// A CV long enough to exercise every section renderer and wrap lines.
UserProfile _englishProfile() => const UserProfile(
  id: 'u1',
  details: ProfileDetails(
    fullName: 'Ada Lovelace',
    professionalTitle: 'Lead Analyst & Systems Mathematician',
    email: 'ada@example.com',
    phone: '+44 20 7946 0000',
    location: 'London, United Kingdom',
    website: 'https://example.com/ada',
    links: ['https://github.com/ada', 'https://linkedin.com/in/ada'],
    summary:
        'Mathematician and writer who designed the first published algorithm. '
        'Experienced in symbolic computation, technical documentation and '
        'cross-team collaboration on analytical engine programmes.',
  ),
  experiences: [
    ExperienceEntry(
      id: 'e1',
      company: 'Analytical Engines Ltd',
      position: 'Lead Analyst',
      location: 'London',
      employmentType: 'Full-time',
      dateRange: DateRange(startIso: '1842-01-01', endIso: '1843-06-01'),
      descriptions: [
        'Designed the first published algorithm for computing Bernoulli '
            'numbers on the Analytical Engine.',
        'Documented the engine’s instruction set for non-specialist readers.',
      ],
    ),
    ExperienceEntry(
      id: 'e2',
      company: 'Royal Society',
      position: 'Technical Translator',
      location: 'London',
      employmentType: 'Contract',
      dateRange: DateRange(startIso: '1840-01-01', endIso: '1841-12-31'),
      descriptions: ['Translated and annotated Menabrea’s engine memoir.'],
    ),
  ],
  projects: [
    ProjectEntry(
      id: 'p1',
      title: 'Difference Engine notes',
      summary: 'Published notes on the engine.',
      description:
          'A detailed set of notes covering the mechanism, the notation and '
          'the worked examples.',
      technologies: ['Punch cards', 'Mathematics'],
      demoUrl: 'https://example.com/demo',
      sourceUrl: 'https://example.com/source',
    ),
  ],
  education: [
    EducationEntry(
      id: 'ed1',
      institution: 'University of London',
      qualification: 'BSc',
      fieldOfStudy: 'Mathematics',
      dateRange: DateRange(startIso: '1836-01-01', endIso: '1840-01-01'),
      grade: 'First class',
      description: 'Specialised in analysis and symbolic methods.',
    ),
  ],
  skills: [
    SkillEntry(id: 's1', name: 'Mathematics'),
    SkillEntry(id: 's2', name: 'Analytical engines'),
    SkillEntry(id: 's3', name: 'Technical writing'),
  ],
  languages: [LanguageEntry(id: 'l1', name: 'English', proficiency: 5)],
  awards: [AwardEntry(id: 'a1', name: 'Engine Medal', issuer: 'Royal Society')],
);

/// The same CV in Arabic: checks shaping, RTL order and mirrored punctuation,
/// with Latin runs (email, URLs, digits) embedded in Arabic paragraphs.
UserProfile _arabicProfile() => const UserProfile(
  id: 'u2',
  details: ProfileDetails(
    fullName: 'أحمد بن علي',
    professionalTitle: 'مهندس برمجيات أول',
    email: 'ahmed@example.com',
    phone: '+20 123 456 7890',
    location: 'القاهرة، مصر',
    website: 'https://example.com/ahmed',
    links: ['https://github.com/ahmed'],
    summary:
        'مطور تطبيقات الجوال مع خبرة 8 سنوات في بناء الأنظمة الكبيرة '
        '(أكثر من مليوني مستخدم) وقيادة الفرق التقنية.',
  ),
  experiences: [
    ExperienceEntry(
      id: 'e1',
      company: 'Cairo Software',
      position: 'Senior Engineer',
      location: 'القاهرة',
      dateRange: DateRange(startIso: '2020-01-01', endIso: '2024-01-01'),
      descriptions: [
        'بنى منصة الجوال التي يخدمها أكثر من مليوني مستخدم (Android و iOS).',
        'قاد فريقاً من 6 مهندسين وتابع مؤشرات الأداء خلال 2023.',
      ],
    ),
  ],
  projects: [
    ProjectEntry(
      id: 'p1',
      title: 'منصة الدفع الإلكتروني',
      summary: 'واجهات برمجة للتطبيقات المالية.',
      description: 'تصميم وتنفيذ واجهات برمجة (APIs) آمنة.',
      technologies: ['Flutter', 'Dart'],
      demoUrl: 'https://example.com/demo',
    ),
  ],
  education: [
    EducationEntry(
      id: 'ed1',
      institution: 'جامعة القاهرة',
      qualification: 'بكالوريوس',
      fieldOfStudy: 'هندسة الحاسبات',
      dateRange: DateRange(startIso: '2012-01-01', endIso: '2016-01-01'),
      grade: 'جيد جداً',
    ),
  ],
  skills: [
    SkillEntry(id: 's1', name: 'تطوير تطبيقات الجوال'),
    SkillEntry(id: 's2', name: 'Flutter'),
    SkillEntry(id: 's3', name: 'قواعد البيانات'),
  ],
  languages: [LanguageEntry(id: 'l1', name: 'العربية', proficiency: 5)],
  awards: [
    AwardEntry(id: 'a1', name: 'جائزة الابتكار', issuer: 'وزارة الاتصالات'),
  ],
);

/// A CV long enough to force several pages and to exercise a page break.
UserProfile _longProfile({required bool arabic}) {
  final experiences = <ExperienceEntry>[
    for (var i = 1; i <= 40; i++)
      ExperienceEntry(
        id: 'e$i',
        company: arabic ? 'شركة رقم $i' : 'Company $i',
        position: arabic ? 'مهندس برمجيات $i' : 'Software Engineer $i',
        location: arabic ? 'القاهرة' : 'London',
        dateRange: DateRange(startIso: '2000-01-01', endIso: '2024-01-01'),
        descriptions: [
          if (arabic)
            'قيادة مشروع رقم $i مع فريق من 5 مهندسين وتسليمه في الموعد المتفق عليه.'
          else
            'Led project $i with a team of five engineers and shipped it on '
                'schedule, covering design, delivery and support.',
        ],
      ),
  ];
  return UserProfile(
    id: 'u3',
    details: ProfileDetails(
      fullName: arabic ? 'سارة عبد الله' : 'Grace Hopper',
      professionalTitle: arabic ? 'مديرة هندسة' : 'Engineering Manager',
      email: arabic ? 'sara@example.com' : 'grace@example.com',
      phone: '+1 555 0100',
      summary: arabic
          ? 'قائدة هندسية بخبرة عشرين عاماً في بناء الأنظمة الموزعة.'
          : 'Engineering leader with twenty years building distributed systems.',
    ),
    experiences: experiences,
    skills: const [SkillEntry(id: 's1', name: 'Architecture')],
  );
}

/// Builds a document around [sections].
CvDocument _document({
  required LayoutMode layout,
  required List<SectionConfig> sections,
  DocumentType type = DocumentType.cv,
  bool rtl = false,
  PageConfig? page,
}) => CvDocument(
  id: 'doc-1',
  ownerId: 'u1',
  title: 'Sample',
  type: type,
  isRtl: rtl,
  design: DocumentDesign(
    layoutMode: layout,
    isRtl: rtl,
    sections: sections,
    page:
        page ??
        const PageConfig(
          showPageNumbers: true,
          showHeader: true,
          headerText: 'CV & Portfolio Studio',
          showFooter: true,
          footerText: 'Generated sample',
        ),
  ),
);

void main() {
  test('writes representative samples for visual review', () async {
    final fontPath = findArabicFont();
    expect(fontPath, isNotNull, reason: 'the bundled Arabic font must exist');

    final latin = DocumentExporter(fonts: const BaseFontSource());
    final arabic = DocumentExporter(
      fonts: FixtureFontSource(await loadPdfFont(fontPath!)),
    );

    final en = _englishProfile();
    final ar = _arabicProfile();

    // 01-03: every layout, English, designed mode.
    await _write(
      '01-designed-en-one.pdf',
      await latin.export(
        document: _document(
          layout: LayoutMode.one,
          sections: _oneColumnSections,
        ),
        profile: en,
        mode: ExportMode.designed,
      ),
    );
    await _write(
      '02-designed-en-two.pdf',
      await latin.export(
        document: _document(
          layout: LayoutMode.two,
          sections: _twoColumnSections,
        ),
        profile: en,
        mode: ExportMode.designed,
      ),
    );
    await _write(
      '03-designed-en-mix.pdf',
      await latin.export(
        document: _document(layout: LayoutMode.mix, sections: _mixSections),
        profile: en,
        mode: ExportMode.designed,
      ),
    );

    // 04-05: Arabic with an embedded font, including Latin runs inside the
    // Arabic paragraphs (email, URLs, digits).
    await _write(
      '04-designed-ar-one.pdf',
      await arabic.export(
        document: _document(
          layout: LayoutMode.one,
          sections: _oneColumnSections,
          rtl: true,
        ),
        profile: ar,
        mode: ExportMode.designed,
      ),
    );
    await _write(
      '05-designed-ar-two.pdf',
      await arabic.export(
        document: _document(
          layout: LayoutMode.two,
          sections: _twoColumnSections,
          rtl: true,
        ),
        profile: ar,
        mode: ExportMode.designed,
      ),
    );

    // 06-07: ATS mode collapses the design; both scripts must stay readable.
    await _write(
      '06-ats-en.pdf',
      await latin.export(
        document: _document(
          layout: LayoutMode.two,
          sections: _twoColumnSections,
        ),
        profile: en,
        mode: ExportMode.atsFriendly,
      ),
    );
    await _write(
      '07-ats-ar.pdf',
      await arabic.export(
        document: _document(
          layout: LayoutMode.one,
          sections: _oneColumnSections,
          rtl: true,
        ),
        profile: ar,
        mode: ExportMode.atsFriendly,
      ),
    );

    // 08: a portfolio document.
    await _write(
      '08-portfolio-en.pdf',
      await latin.export(
        document: _document(
          layout: LayoutMode.one,
          sections: _oneColumnSections,
          type: DocumentType.portfolio,
        ),
        profile: en,
        mode: ExportMode.designed,
      ),
    );

    // 09-10: long documents plus an explicit page break in the middle.
    const longSections = <SectionConfig>[
      ..._oneColumnSections,
      SectionConfig(id: 'brk', kind: SectionKind.pageBreak),
      SectionConfig(id: 'experience2', kind: SectionKind.experience),
    ];
    await _write(
      '09-long-en.pdf',
      await latin.export(
        document: _document(layout: LayoutMode.one, sections: longSections),
        profile: _longProfile(arabic: false),
        mode: ExportMode.designed,
      ),
      minPages: 2,
    );
    await _write(
      '10-long-ar.pdf',
      await arabic.export(
        document: _document(
          layout: LayoutMode.one,
          sections: longSections,
          rtl: true,
        ),
        profile: _longProfile(arabic: true),
        mode: ExportMode.designed,
      ),
      minPages: 2,
    );

    // 11: the page-number toggle turned off (the footer must disappear).
    await _write(
      '11-designed-en-no-numbers.pdf',
      await latin.export(
        document: _document(
          layout: LayoutMode.one,
          sections: _oneColumnSections,
          page: const PageConfig(showPageNumbers: false),
        ),
        profile: en,
        mode: ExportMode.designed,
      ),
    );
  });

  test('writes DOCX samples for office compatibility checks', () async {
    await _out.create(recursive: true);
    final exporter = DocumentExporter(fonts: const BaseFontSource());

    final samples =
        <
          ({
            String name,
            CvDocument document,
            UserProfile profile,
            String language,
          })
        >[
          (
            name: '01-designed-en.docx',
            document: _document(
              layout: LayoutMode.one,
              sections: _oneColumnSections,
            ),
            profile: _englishProfile(),
            language: 'en',
          ),
          (
            name: '04-designed-ar.docx',
            document: _document(
              layout: LayoutMode.one,
              sections: _oneColumnSections,
              rtl: true,
            ),
            profile: _arabicProfile(),
            language: 'ar',
          ),
          (
            name: '06-ats-en.docx',
            document: _document(
              layout: LayoutMode.two,
              sections: _twoColumnSections,
            ),
            profile: _englishProfile(),
            language: 'en',
          ),
        ];

    for (final sample in samples) {
      final result = await exporter.exportDocx(
        document: sample.document,
        profile: sample.profile,
        languageCode: sample.language,
      );
      final file = File('${_out.path}${Platform.pathSeparator}${sample.name}');
      await file.writeAsBytes(result.bytes);

      expect(result.bytes.length, greaterThan(2000), reason: sample.name);
      // A .docx is a ZIP container, so it starts with a local file header.
      expect(result.bytes.sublist(0, 2), <int>[
        0x50,
        0x4B,
      ], reason: sample.name);
      // ignore: avoid_print
      print(
        'wrote ${sample.name} -> ${result.bytes.length} bytes '
        '(suggested name: ${result.fileName})',
      );
    }
  });
}
