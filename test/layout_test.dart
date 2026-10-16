import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:cv_portfolio_maker/core/design/templates.dart';
import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/document_models.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/render/document_layout.dart';
import 'package:cv_portfolio_maker/core/render/resolved_document.dart';
import 'package:cv_portfolio_maker/core/render/section_titles.dart';

// ---------------------------------------------------------------- test helpers

/// Builds a bare [ResolvedSection] purely for layout partitioning tests.
ResolvedSection sec(String id, SectionKind kind, ColumnSlot slot) =>
    ResolvedSection(
      config: SectionConfig(id: id, kind: kind, slot: slot),
      title: defaultTitleEn(kind),
      experiences: const [],
      education: const [],
      skills: const [],
      languages: const [],
      certificates: const [],
      courses: const [],
      awards: const [],
      volunteer: const [],
      publications: const [],
      references: const [],
      projects: const [],
      customEntries: const [],
      summaryText: '',
      isPageBreak: kind == SectionKind.pageBreak,
    );

CvDocument docWith(DocumentDesign design, {bool isRtl = false}) => CvDocument(
  id: 'doc-1',
  ownerId: 'user-1',
  title: 'My CV',
  design: design,
  isRtl: isRtl,
);

UserProfile profileWith({
  String? summary,
  List<ExperienceEntry> experiences = const [],
  List<SkillEntry> skills = const [],
  List<ProjectEntry> projects = const [],
}) => UserProfile(
  id: 'user-1',
  details: ProfileDetails(
    fullName: 'Ada Lovelace',
    professionalTitle: 'Analyst',
    email: 'ada@example.com',
    summary: summary,
  ),
  experiences: experiences,
  skills: skills,
  projects: projects,
);

ResolvedDocument resolve(
  CvDocument document,
  UserProfile profile, {
  bool atsFriendly = false,
}) => ResolvedDocument.resolve(
  document: document,
  profile: profile,
  defaultTitle: defaultTitleEn,
  atsFriendly: atsFriendly,
);

List<String> idsOf(List<ResolvedSection> sections) =>
    sections.map((s) => s.config.id).toList();

void main() {
  // ------------------------------------------------------------------ clamping

  group('clampColumnRatio', () {
    test('keeps valid ratios untouched', () {
      expect(clampColumnRatio(0.5), 0.5);
      expect(clampColumnRatio(0.25), 0.25);
      expect(clampColumnRatio(0.75), 0.75);
      expect(clampColumnRatio(0.4), 0.4);
    });

    test('clamps ratios that would collapse a column', () {
      expect(clampColumnRatio(0.0), 0.25);
      expect(clampColumnRatio(0.1), 0.25);
      expect(clampColumnRatio(0.99), 0.75);
      expect(clampColumnRatio(1.0), 0.75);
      expect(clampColumnRatio(-3), 0.25);
    });

    test('falls back to a balanced split for non-finite values', () {
      expect(clampColumnRatio(double.nan), 0.5);
      expect(clampColumnRatio(double.infinity), 0.5);
      expect(clampColumnRatio(double.negativeInfinity), 0.5);
    });
  });

  // --------------------------------------------------------------- partition

  group('partitionSections', () {
    test('sorts into buckets while preserving reading order', () {
      final buckets = partitionSections([
        sec('a', SectionKind.experience, ColumnSlot.left),
        sec('b', SectionKind.skills, ColumnSlot.right),
        sec('c', SectionKind.projects, ColumnSlot.fullWidth),
        sec('d', SectionKind.education, ColumnSlot.left),
      ]);

      expect(idsOf(buckets.full), ['c']);
      expect(idsOf(buckets.left), ['a', 'd']);
      expect(idsOf(buckets.right), ['b']);
      expect(buckets.hasColumns, isTrue);
    });

    test('a page break always spans the full width', () {
      final buckets = partitionSections([
        sec('pb', SectionKind.pageBreak, ColumnSlot.left),
      ]);

      expect(idsOf(buckets.full), ['pb']);
      expect(buckets.left, isEmpty);
    });

    test('reports no columns when every section is full width', () {
      final buckets = partitionSections([
        sec('a', SectionKind.experience, ColumnSlot.fullWidth),
      ]);

      expect(buckets.hasColumns, isFalse);
    });
  });

  // ------------------------------------------------------------------- two

  group('twoColumnBuckets', () {
    test('honours explicit left and right assignments', () {
      final buckets = twoColumnBuckets([
        sec('a', SectionKind.experience, ColumnSlot.left),
        sec('b', SectionKind.skills, ColumnSlot.right),
      ]);

      expect(idsOf(buckets.left), ['a']);
      expect(idsOf(buckets.right), ['b']);
      expect(buckets.full, isEmpty);
    });

    test(
      'full-width sections fall back to the left column (never dropped)',
      () {
        final buckets = twoColumnBuckets([
          sec('a', SectionKind.experience, ColumnSlot.fullWidth),
          sec('b', SectionKind.skills, ColumnSlot.right),
        ]);

        expect(idsOf(buckets.left), ['a']);
        expect(idsOf(buckets.right), ['b']);
        expect(buckets.hasColumns, isTrue);
      },
    );

    test('auto-balances when nothing is assigned to a column yet', () {
      final buckets = twoColumnBuckets([
        sec('a', SectionKind.experience, ColumnSlot.fullWidth),
        sec('b', SectionKind.education, ColumnSlot.fullWidth),
        sec('c', SectionKind.skills, ColumnSlot.fullWidth),
        sec('d', SectionKind.languages, ColumnSlot.fullWidth),
      ]);

      expect(idsOf(buckets.left), ['a', 'c']);
      expect(idsOf(buckets.right), ['b', 'd']);
    });

    test('handles an empty document', () {
      final buckets = twoColumnBuckets(const []);
      expect(buckets.left, isEmpty);
      expect(buckets.right, isEmpty);
      expect(buckets.hasColumns, isFalse);
    });
  });

  // ------------------------------------------------------------------- mix

  group('buildMixRows', () {
    test('interleaves full-width sections in reading order', () {
      final rows = buildMixRows([
        sec('a', SectionKind.experience, ColumnSlot.left),
        sec('b', SectionKind.skills, ColumnSlot.right),
        sec('c', SectionKind.projects, ColumnSlot.fullWidth),
        sec('d', SectionKind.languages, ColumnSlot.left),
      ]);

      expect(rows.length, 3);

      expect(rows[0].isFullWidth, isFalse);
      expect(idsOf(rows[0].left), ['a']);
      expect(idsOf(rows[0].right), ['b']);

      expect(rows[1].isFullWidth, isTrue);
      expect(idsOf(rows[1].full), ['c']);

      expect(rows[2].isFullWidth, isFalse);
      expect(idsOf(rows[2].left), ['d']);
      expect(rows[2].right, isEmpty);
    });

    test(
      'differs from a two-column layout when full width is in the middle',
      () {
        final sections = [
          sec('a', SectionKind.experience, ColumnSlot.left),
          sec('b', SectionKind.projects, ColumnSlot.fullWidth),
          sec('c', SectionKind.skills, ColumnSlot.right),
        ];

        final rows = buildMixRows(sections);
        expect(rows.first.isFullWidth, isFalse);
        expect(rows[1].isFullWidth, isTrue);
        expect(rows.last.isFullWidth, isFalse);

        // `Two` never produces a full-width band.
        final two = twoColumnBuckets(sections);
        expect(two.full, isEmpty);
        expect(idsOf(two.left), ['a', 'b']);
        expect(idsOf(two.right), ['c']);
      },
    );

    test('groups every column section when there is no full-width break', () {
      final rows = buildMixRows([
        sec('a', SectionKind.experience, ColumnSlot.left),
        sec('b', SectionKind.skills, ColumnSlot.right),
        sec('c', SectionKind.education, ColumnSlot.left),
      ]);

      expect(rows.length, 1);
      expect(rows.single.isFullWidth, isFalse);
      expect(idsOf(rows.single.left), ['a', 'c']);
      expect(idsOf(rows.single.right), ['b']);
    });

    test('a page break becomes its own full-width band', () {
      final rows = buildMixRows([
        sec('a', SectionKind.experience, ColumnSlot.left),
        sec('pb', SectionKind.pageBreak, ColumnSlot.right),
        sec('b', SectionKind.skills, ColumnSlot.right),
      ]);

      expect(rows.length, 3);
      expect(rows[1].isFullWidth, isTrue);
      expect(rows[1].full.single.isPageBreak, isTrue);
    });

    test('handles an empty document', () {
      expect(buildMixRows(const []), isEmpty);
    });
  });

  // ------------------------------------------------------------ serialization

  group('DocumentDesign serialization', () {
    test('round-trips every design property', () {
      final design = DocumentDesign(
        layoutMode: LayoutMode.mix,
        templateId: 'creative',
        isRtl: true,
        sections: const [
          SectionConfig(
            id: 'experience',
            kind: SectionKind.experience,
            slot: ColumnSlot.left,
            visible: false,
            customTitle: 'Work history',
            pageBreakBefore: true,
            hiddenEntryIds: ['e1'],
            fieldVisibility: {'location': false},
          ),
          SectionConfig(
            id: 'pb',
            kind: SectionKind.pageBreak,
            slot: ColumnSlot.fullWidth,
          ),
        ],
        colors: const ColorConfig(primary: 0xFF123456, accent: 0xFFABCDEF),
        typography: const TypographyConfig(
          headingFont: 'lora',
          bodyFontSize: 11.5,
          uppercaseSectionTitles: true,
        ),
        spacing: const SpacingConfig(leftColumnRatio: 0.42, columnGap: 18),
        page: const PageConfig(pageSize: 'letter', portrait: false),
        presentation: const PresentationConfig(
          dividerStyle: DividerStyle.dotted,
          avatarShape: AvatarShape.roundedSquare,
          headerStyle: 'center',
        ),
      );

      // Encode through a real JSON string to prove the map is JSON-safe.
      final restored = DocumentDesign.fromJson(
        jsonDecode(jsonEncode(design.toJson())) as Map<String, dynamic>,
      );

      expect(restored.layoutMode, LayoutMode.mix);
      expect(restored.templateId, 'creative');
      expect(restored.isRtl, isTrue);
      expect(restored.colors.primary, 0xFF123456);
      expect(restored.colors.accent, 0xFFABCDEF);
      expect(restored.typography.headingFont, 'lora');
      expect(restored.typography.uppercaseSectionTitles, isTrue);
      expect(restored.spacing.leftColumnRatio, 0.42);
      expect(restored.spacing.columnGap, 18);
      expect(restored.page.pageSize, 'letter');
      expect(restored.page.portrait, isFalse);
      expect(restored.presentation.dividerStyle, DividerStyle.dotted);
      expect(restored.presentation.avatarShape, AvatarShape.roundedSquare);
      expect(restored.presentation.headerStyle, 'center');

      expect(restored.sections.map((s) => s.id), ['experience', 'pb']);
      final experience = restored.sections.first;
      expect(experience.kind, SectionKind.experience);
      expect(experience.slot, ColumnSlot.left);
      expect(experience.visible, isFalse);
      expect(experience.customTitle, 'Work history');
      expect(experience.pageBreakBefore, isTrue);
      expect(experience.hiddenEntryIds, ['e1']);
      expect(experience.fieldVisibility['location'], isFalse);
      expect(restored.sections.last.isPageBreak, isTrue);
    });

    test('an empty map yields sensible defaults', () {
      final design = DocumentDesign.fromJson(const {});

      expect(design.layoutMode, LayoutMode.one);
      expect(design.templateId, 'minimal');
      expect(design.sections, isEmpty);
      expect(design.colors.paper, 0xFFFFFFFF);
      expect(design.typography.bodyFontSize, 10.5);
      expect(design.spacing.leftColumnRatio, 0.38);
      expect(design.page.pageSize, 'a4');
      expect(design.presentation.dividerStyle, DividerStyle.thin);
    });

    test('older documents without newer fields still load', () {
      final design = DocumentDesign.fromJson(const {
        'layoutMode': 'two',
        'sections': [
          {'id': 'skills', 'kind': 'skills'},
        ],
      });

      expect(design.layoutMode, LayoutMode.two);
      expect(design.sections.single.id, 'skills');
      expect(design.sections.single.slot, ColumnSlot.fullWidth);
      expect(design.sections.single.visible, isTrue);
    });

    test('unknown fields and enum values are ignored safely', () {
      final design = DocumentDesign.fromJson(const {
        'layoutMode': 'not-a-mode',
        'futureField': {'nested': true},
        'sections': [
          {'id': 'x', 'kind': 'unknown_kind', 'slot': 'sideways', 'extra': 1},
          'not-a-map',
        ],
      });

      expect(design.layoutMode, LayoutMode.one);
      expect(design.sections.length, 1);
      expect(design.sections.single.slot, ColumnSlot.fullWidth);
    });

    test('SectionConfig round-trips', () {
      const config = SectionConfig(
        id: 'skills',
        kind: SectionKind.skills,
        slot: ColumnSlot.right,
        entryOrder: ['s2', 's1'],
        customSectionId: 'cs-1',
      );

      final restored = SectionConfig.fromJson(
        jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
      );

      expect(restored.id, 'skills');
      expect(restored.kind, SectionKind.skills);
      expect(restored.slot, ColumnSlot.right);
      expect(restored.entryOrder, ['s2', 's1']);
      expect(restored.customSectionId, 'cs-1');
    });
  });

  // ---------------------------------------------------------- resolved output

  group('ResolvedDocument visibility and ordering', () {
    test('hidden sections are excluded from rendered output', () {
      final design = DocumentDesign(
        sections: const [
          SectionConfig(
            id: 'experience',
            kind: SectionKind.experience,
            visible: false,
          ),
          SectionConfig(id: 'skills', kind: SectionKind.skills),
        ],
      );

      final resolved = resolve(
        docWith(design),
        profileWith(
          experiences: [const ExperienceEntry(id: 'e1', company: 'ACME')],
          skills: [const SkillEntry(id: 's1', name: 'Dart')],
        ),
      );

      expect(idsOf(resolved.sections), ['skills']);
      expect(resolved.design.visibleSections.length, 1);
    });

    test('empty sections never render an empty heading', () {
      final design = DocumentDesign(
        sections: const [
          SectionConfig(id: 'experience', kind: SectionKind.experience),
          SectionConfig(id: 'skills', kind: SectionKind.skills),
        ],
      );

      final resolved = resolve(
        docWith(design),
        profileWith(
          skills: [const SkillEntry(id: 's1', name: 'Dart')],
        ),
      );

      expect(idsOf(resolved.sections), ['skills']);
    });

    test('section order follows the stored configuration order', () {
      final design = DocumentDesign(
        sections: const [
          SectionConfig(id: 'skills', kind: SectionKind.skills),
          SectionConfig(id: 'experience', kind: SectionKind.experience),
          SectionConfig(id: 'education', kind: SectionKind.education),
        ],
      );

      final resolved = resolve(
        docWith(design),
        profileWith(
          experiences: [const ExperienceEntry(id: 'e1', company: 'ACME')],
          skills: [const SkillEntry(id: 's1', name: 'Dart')],
        ),
      );

      // Education has no entries and is dropped; the rest keep their order.
      expect(idsOf(resolved.sections), ['skills', 'experience']);
    });

    test('One layout keeps reading order regardless of column slot', () {
      final design = DocumentDesign(
        layoutMode: LayoutMode.one,
        sections: const [
          SectionConfig(
            id: 'a',
            kind: SectionKind.skills,
            slot: ColumnSlot.right,
          ),
          SectionConfig(
            id: 'b',
            kind: SectionKind.experience,
            slot: ColumnSlot.left,
          ),
        ],
      );

      final resolved = resolve(
        docWith(design),
        profileWith(
          experiences: [const ExperienceEntry(id: 'e1', company: 'ACME')],
          skills: [const SkillEntry(id: 's1', name: 'Dart')],
        ),
      );

      // One mode renders `resolved.sections` verbatim (no bucketing).
      expect(idsOf(resolved.sections), ['a', 'b']);
    });

    test('two-column rendering drops full-width bands', () {
      final design = DocumentDesign(
        layoutMode: LayoutMode.two,
        sections: const [
          SectionConfig(id: 'experience', kind: SectionKind.experience),
          SectionConfig(
            id: 'skills',
            kind: SectionKind.skills,
            slot: ColumnSlot.right,
          ),
        ],
      );

      final resolved = resolve(
        docWith(design),
        profileWith(
          experiences: [const ExperienceEntry(id: 'e1', company: 'ACME')],
          skills: [const SkillEntry(id: 's1', name: 'Dart')],
        ),
      );

      final buckets = twoColumnBuckets(resolved.sections);
      expect(buckets.full, isEmpty);
      expect(idsOf(buckets.left), ['experience']);
      expect(idsOf(buckets.right), ['skills']);
    });

    test('mixed rendering keeps full-width content in place', () {
      final design = DocumentDesign(
        layoutMode: LayoutMode.mix,
        sections: const [
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
      );

      final resolved = resolve(
        docWith(design),
        profileWith(
          experiences: [const ExperienceEntry(id: 'e1', company: 'ACME')],
          skills: [const SkillEntry(id: 's1', name: 'Dart')],
          projects: [const ProjectEntry(id: 'p1', title: 'Engine')],
        ),
      );

      final rows = buildMixRows(resolved.sections);
      expect(rows.length, 3);
      expect(rows[1].isFullWidth, isTrue);
      expect(idsOf(rows[1].full), ['projects']);
    });

    test('page-break sections are preserved in order', () {
      final design = DocumentDesign(
        sections: const [
          SectionConfig(id: 'skills', kind: SectionKind.skills),
          SectionConfig(id: 'pb', kind: SectionKind.pageBreak),
          SectionConfig(id: 'experience', kind: SectionKind.experience),
        ],
      );

      final resolved = resolve(
        docWith(design),
        profileWith(
          experiences: [const ExperienceEntry(id: 'e1', company: 'ACME')],
          skills: [const SkillEntry(id: 's1', name: 'Dart')],
        ),
      );

      expect(idsOf(resolved.sections), ['skills', 'pb', 'experience']);
      expect(resolved.sections[1].isPageBreak, isTrue);
      expect(resolved.sections[1].isEmpty, isFalse);
    });

    test('hidden entries inside a section are dropped', () {
      final design = DocumentDesign(
        sections: const [
          SectionConfig(
            id: 'experience',
            kind: SectionKind.experience,
            hiddenEntryIds: ['e2'],
          ),
        ],
      );

      final resolved = resolve(
        docWith(design),
        profileWith(
          experiences: [
            const ExperienceEntry(id: 'e1', company: 'ACME'),
            const ExperienceEntry(id: 'e2', company: 'Secret'),
          ],
        ),
      );

      expect(resolved.sections.single.experiences.map((e) => e.id), ['e1']);
    });

    test('long content across many sections survives resolution intact', () {
      final design = DocumentDesign(
        sections: const [
          SectionConfig(id: 'experience', kind: SectionKind.experience),
          SectionConfig(id: 'skills', kind: SectionKind.skills),
        ],
      );

      final resolved = resolve(
        docWith(design),
        profileWith(
          experiences: [
            for (var i = 0; i < 40; i++)
              ExperienceEntry(
                id: 'e$i',
                company: 'Company $i',
                position: 'Role $i',
                descriptions: ['A very long description ' * 20],
              ),
          ],
          skills: [
            for (var i = 0; i < 60; i++)
              SkillEntry(id: 's$i', name: 'Skill $i'),
          ],
        ),
      );

      expect(resolved.sections.first.experiences.length, 40);
      expect(resolved.sections.last.skills.length, 60);
    });
  });

  // ------------------------------------------------------------------- ATS

  group('ATS-safe rendering', () {
    test('forces a single column without mutating the saved design', () {
      final design = DocumentDesign(
        layoutMode: LayoutMode.mix,
        sections: const [
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
      );

      final resolved = resolve(
        docWith(design),
        profileWith(
          experiences: [const ExperienceEntry(id: 'e1', company: 'ACME')],
          skills: [const SkillEntry(id: 's1', name: 'Dart')],
        ),
        atsFriendly: true,
      );

      expect(resolved.design.layoutMode, LayoutMode.one);
      expect(resolved.design.presentation.avatarShape, AvatarShape.hidden);
      expect(resolved.design.presentation.dividerStyle, DividerStyle.none);
      expect(resolved.design.isRtl, isFalse);

      // Content is never dropped by the simplification.
      expect(idsOf(resolved.sections), ['experience', 'skills']);

      // The caller's saved design is untouched.
      expect(design.layoutMode, LayoutMode.mix);
      expect(design.sections.first.slot, ColumnSlot.left);
    });
  });

  // -------------------------------------------------------------- templates

  group('templates', () {
    test('every built-in template builds a design for both document types', () {
      expect(builtinTemplates, isNotEmpty);
      for (final template in builtinTemplates) {
        for (final type in DocumentType.values) {
          final design = template.build(type);
          expect(design.templateId, template.id);
          expect(design.sections, isNotEmpty, reason: template.id);
        }
      }
    });

    test('modern and designer are two-column, creative is mixed', () {
      expect(
        designForTemplate('modern', DocumentType.cv).layoutMode,
        LayoutMode.two,
      );
      expect(
        designForTemplate('designer', DocumentType.portfolio).layoutMode,
        LayoutMode.two,
      );
      expect(
        designForTemplate('creative', DocumentType.cv).layoutMode,
        LayoutMode.mix,
      );
      expect(
        designForTemplate('minimal', DocumentType.cv).layoutMode,
        LayoutMode.one,
      );
    });

    test('an unknown template id falls back to minimal', () {
      final design = designForTemplate('does-not-exist', DocumentType.cv);
      expect(design.templateId, 'minimal');
    });

    test('portfolios lead with the projects section', () {
      final cv = defaultSections(isPortfolio: false);
      final portfolio = defaultSections(isPortfolio: true);

      expect(cv.first.kind, SectionKind.personalDetails);
      expect(portfolio[2].kind, SectionKind.projects);
    });

    test('two designs built from the same template do not share state', () {
      final a = designForTemplate('modern', DocumentType.cv);
      final b = designForTemplate('modern', DocumentType.cv);

      final mutated = a.copyWith(
        sections: [for (final s in a.sections) s.copyWith(visible: false)],
      );

      expect(b.sections.any((s) => s.visible), isTrue);
      expect(mutated.sections.any((s) => s.visible), isFalse);
    });
  });
}
