/// The document resolution layer.
///
/// This is the single source of truth shared by every rendering target: the
/// on-screen preview, the public portfolio page, the PDF exporters and the DOCX
/// exporter. It resolves a [CvDocument] + [UserProfile] pair into a flat,
/// presentation-agnostic [ResolvedDocument] so no renderer re-implements
/// visibility, ordering or ATS rules.
library;

import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/document_models.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';

import '../utils/contact_links.dart';
import '../utils/profile_content.dart';

/// A resolved contact line, already filtered for missing values.
class ResolvedContact {
  const ResolvedContact({
    required this.label,
    required this.value,
    this.displayValue,
    this.url,
  });

  final String label;
  final String value;
  final String? displayValue;
  final String? url;
  // Labels identify icons and links; the CV displays only the contact value.
  String text() => displayValue ?? value;
}

/// A resolved section ready for rendering.
class ResolvedSection {
  const ResolvedSection({
    required this.config,
    required this.title,
    required this.experiences,
    required this.education,
    required this.skills,
    required this.languages,
    required this.certificates,
    required this.courses,
    required this.awards,
    required this.volunteer,
    required this.publications,
    required this.references,
    required this.projects,
    required this.customEntries,
    required this.summaryText,
    required this.isPageBreak,
  });

  final SectionConfig config;
  final String title;
  final List<ExperienceEntry> experiences;
  final List<EducationEntry> education;
  final List<SkillEntry> skills;
  final List<LanguageEntry> languages;
  final List<CertificateEntry> certificates;
  final List<CourseEntry> courses;
  final List<AwardEntry> awards;
  final List<VolunteerEntry> volunteer;
  final List<PublicationEntry> publications;
  final List<ReferenceEntry> references;
  final List<ProjectEntry> projects;
  final List<CustomEntry> customEntries;
  final String summaryText;
  final bool isPageBreak;

  /// `true` when the section has nothing worth rendering.
  ///
  /// Empty sections are dropped so exported documents never contain
  /// meaningless headings.
  bool get isEmpty =>
      !isPageBreak &&
      summaryText.trim().isEmpty &&
      experiences.isEmpty &&
      education.isEmpty &&
      skills.isEmpty &&
      languages.isEmpty &&
      certificates.isEmpty &&
      courses.isEmpty &&
      awards.isEmpty &&
      volunteer.isEmpty &&
      publications.isEmpty &&
      references.isEmpty &&
      projects.isEmpty &&
      customEntries.isEmpty;
}

/// A fully resolved document.
class ResolvedDocument {
  const ResolvedDocument({
    required this.document,
    required this.design,
    required this.details,
    required this.contacts,
    required this.summary,
    required this.sections,
    required this.allProjects,
  });

  final CvDocument document;
  final DocumentDesign design;
  final ProfileDetails details;

  /// Contact lines, already filtered for missing values.
  final List<ResolvedContact> contacts;

  /// Professional summary text (empty when hidden or absent).
  final String summary;

  /// Renderable sections in reading order, excluding empty ones.
  final List<ResolvedSection> sections;

  /// Every visible project referenced by this document.
  final List<ProjectEntry> allProjects;

  /// Sections assigned to a specific column slot.
  List<ResolvedSection> sectionsForSlot(ColumnSlot slot) =>
      sections.where((s) => !s.isPageBreak && s.config.slot == slot).toList();

  /// `true` when the document has no content at all.
  bool get isEmpty => sections.every((s) => s.isPageBreak) && contacts.isEmpty;

  /// Resolves a document against a profile.
  ///
  /// When [atsFriendly] is `true` the resolver enforces machine-readability: a
  /// single reading order and no empty sections. It never drops real content.
  factory ResolvedDocument.resolve({
    required CvDocument document,
    required UserProfile profile,
    required String Function(SectionKind) defaultTitle,
    bool atsFriendly = false,
  }) {
    if (document.type == DocumentType.cv && document.profileSnapshot != null) {
      profile = document.profileSnapshot!;
    }
    final design = withProfileCustomSections(document.design, profile);
    final effectiveDesign = atsFriendly ? atsSafeDesign(design) : design;

    final contacts = <ResolvedContact>[];
    final details = profile.details;

    void addContact(String label, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        final raw = value.trim();
        final web = label == 'Website' || label == 'Link';
        final target = web ? contactWebUrl(raw) : null;
        final kind = web ? contactLinkKind(raw) : label;
        final custom = details.linkLabels[raw]?.trim();
        final displayed = web && !atsFriendly
            ? custom != null && custom.isNotEmpty
                  ? custom
                  : compactContactUrl(raw)
            : raw;
        final contact = ResolvedContact(
          label: kind == 'Link' && label == 'Website' ? 'Website' : kind,
          value: raw,
          displayValue: displayed,
          url:
              target ??
              (label == 'Email' &&
                      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(raw)
                  ? Uri(scheme: 'mailto', path: raw).toString()
                  : label == 'Phone' &&
                        RegExp(r'^\+?[\d\s().-]+$').hasMatch(raw)
                  ? 'tel:${raw.replaceAll(RegExp(r'[\s().-]'), '')}'
                  : null),
        );
        if (!contacts.any(
          (c) =>
              c.url != null && c.url == contact.url ||
              c.label == contact.label && c.value == contact.value,
        )) {
          contacts.add(contact);
        }
      }
    }

    final personalSection = design.sectionOf(SectionKind.personalDetails);
    final personalVisible = personalSection?.visible ?? true;
    if (personalVisible || atsFriendly) {
      addContact('Email', details.email);
      addContact('Phone', details.phone);
      addContact('Location', details.location);
      addContact('Website', details.website);
      for (final link in details.links) {
        if (link.trim().isNotEmpty) addContact('Link', link.trim());
      }
    }

    final includedIds = document.includedProjectIds;
    var projects = profile.projects.where((p) => p.visible).toList();
    if (includedIds != null) {
      final allowed = includedIds.toSet();
      projects = projects.where((p) => allowed.contains(p.id)).toList();
    }
    // Stable sort: featured projects lead, otherwise user order is kept.
    projects.sort((a, b) {
      if (a.featured == b.featured) return 0;
      return a.featured ? -1 : 1;
    });

    final sections = <ResolvedSection>[];
    String? summaryText;

    for (final config in effectiveDesign.visibleSections) {
      if (config.isPageBreak) {
        sections.add(
          ResolvedSection(
            config: config,
            title: '',
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
            isPageBreak: true,
          ),
        );
        continue;
      }

      // Personal details and the professional summary are rendered as part of
      // the document header, never as their own section: the header already
      // prints them, so a section here would be an empty heading.
      if (config.kind == SectionKind.personalDetails) continue;
      if (config.kind == SectionKind.profile) {
        final text = (profile.details.summary ?? '').trim();
        if (text.isNotEmpty) summaryText = text;
        continue;
      }

      final hiddenIds = config.hiddenEntryIds.toSet();
      final section = _resolveSection(
        config: config,
        title: config.resolvedTitle((kind) {
          if (kind == SectionKind.custom) {
            for (final section in profile.customSections) {
              if (section.id == config.customSectionId) return section.title;
            }
          }
          return defaultTitle(kind);
        }),
        profile: profile,
        projects: projects,
        hiddenIds: hiddenIds,
      );

      // Never render an empty heading.
      if (section.isEmpty) continue;

      if (config.kind == SectionKind.profile) summaryText = section.summaryText;
      sections.add(section);
    }

    return ResolvedDocument(
      document: document,
      design: effectiveDesign,
      details: details,
      contacts: contacts,
      summary: summaryText ?? '',
      sections: sections,
      allProjects: projects,
    );
  }
}

/// Resolves one section's entries, applying hidden ids and user ordering.
ResolvedSection _resolveSection({
  required SectionConfig config,
  required String title,
  required UserProfile profile,
  required List<ProjectEntry> projects,
  required Set<String> hiddenIds,
}) {
  List<T> keep<T>(List<T> items, String Function(T) idOf) {
    final visible = items.where((e) => !hiddenIds.contains(idOf(e))).toList();
    return config.applyOrder(visible, idOf);
  }

  return ResolvedSection(
    config: config,
    title: title,
    experiences: config.kind == SectionKind.experience
        ? keep(
            profile.experiences.where((e) => e.visible).toList(),
            (e) => e.id,
          )
        : const [],
    education: config.kind == SectionKind.education
        ? keep(profile.education.where((e) => e.visible).toList(), (e) => e.id)
        : const [],
    skills: config.kind == SectionKind.skills
        ? keep(profile.skills.where((e) => e.visible).toList(), (e) => e.id)
        : const [],
    languages: config.kind == SectionKind.languages
        ? keep(profile.languages.where((e) => e.visible).toList(), (e) => e.id)
        : const [],
    certificates: config.kind == SectionKind.certificates
        ? keep(
            profile.certificates.where((e) => e.visible).toList(),
            (e) => e.id,
          )
        : const [],
    courses: config.kind == SectionKind.courses
        ? keep(profile.courses.where((e) => e.visible).toList(), (e) => e.id)
        : const [],
    awards: config.kind == SectionKind.awards
        ? keep(profile.awards.where((e) => e.visible).toList(), (e) => e.id)
        : const [],
    volunteer: config.kind == SectionKind.volunteer
        ? keep(profile.volunteer.where((e) => e.visible).toList(), (e) => e.id)
        : const [],
    publications: config.kind == SectionKind.publications
        ? keep(
            profile.publications.where((e) => e.visible).toList(),
            (e) => e.id,
          )
        : const [],
    references: config.kind == SectionKind.references
        ? keep(profile.references.where((e) => e.visible).toList(), (e) => e.id)
        : const [],
    projects: config.kind == SectionKind.projects
        ? keep(projects, (p) => p.id)
        : const [],
    customEntries: config.kind == SectionKind.custom
        ? _resolveCustomEntries(profile, config, hiddenIds)
        : const [],
    summaryText: config.kind == SectionKind.profile
        ? (profile.details.summary ?? '').trim()
        : '',
    isPageBreak: false,
  );
}

/// Resolves the entries of a user-defined section.
List<CustomEntry> _resolveCustomEntries(
  UserProfile profile,
  SectionConfig config,
  Set<String> hiddenIds,
) {
  for (final custom in profile.customSections) {
    if (custom.id != config.customSectionId) continue;
    final kept = custom.entries
        .where((e) => e.visible && !hiddenIds.contains(e.id))
        .toList();
    return config.applyOrder(kept, (e) => e.id);
  }
  return const [];
}

/// Produces the ATS-safe design: single column, no decorative overrides.
///
/// Content and section choices are preserved; only presentation is normalised
/// so applicant tracking systems can extract text reliably.
DocumentDesign atsSafeDesign(DocumentDesign design) => design.copyWith(
  layoutMode: LayoutMode.one,
  isRtl: false,
  presentation: design.presentation.copyWith(
    avatarShape: AvatarShape.hidden,
    showContactIcons: false,
    contactInline: true,
    contactArrangement: 'multiRow',
    showContactLabels: false,
    identityArrangement: 'stacked',
    dividerStyle: DividerStyle.none,
    showSectionIcons: false,
  ),
  page: design.page.copyWith(
    showHeader: false,
    showFooter: false,
    showPageNumbers: true,
  ),
);
