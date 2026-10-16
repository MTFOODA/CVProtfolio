/// Shared enumerations for the CV & Portfolio domain model.
library;

/// Kind of document a user creates.
enum DocumentType { cv, portfolio }

/// How a document is shared with the outside world.
enum ShareMode {
  /// Only the authenticated owner can read it.
  privateDraft,

  /// Anyone holding the URL can read it.
  publicLink,

  /// A single, unguessable token for one intended recipient.
  restrictedRecipient,
}

/// Supported section kinds. `custom` maps to a user-defined section.
enum SectionKind {
  personalDetails,
  profile,
  experience,
  education,
  certificates,
  projects,
  courses,
  skills,
  languages,
  awards,
  volunteer,
  publications,
  references,
  custom,
  pageBreak,
}

/// Extension helpers for [SectionKind].
extension SectionKindX on SectionKind {
  /// Stable machine identifier persisted in the database.
  String get key => switch (this) {
    SectionKind.personalDetails => 'personal_details',
    SectionKind.profile => 'profile',
    SectionKind.experience => 'experience',
    SectionKind.education => 'education',
    SectionKind.certificates => 'certificates',
    SectionKind.projects => 'projects',
    SectionKind.courses => 'courses',
    SectionKind.skills => 'skills',
    SectionKind.languages => 'languages',
    SectionKind.awards => 'awards',
    SectionKind.volunteer => 'volunteer',
    SectionKind.publications => 'publications',
    SectionKind.references => 'references',
    SectionKind.custom => 'custom',
    SectionKind.pageBreak => 'page_break',
  };

  /// Resolves a [SectionKind] from its persisted [key].
  static SectionKind fromKey(String key) => SectionKind.values.firstWhere(
    (k) => k.key == key,
    orElse: () => SectionKind.custom,
  );

  /// Sections that hold collections of user entries.
  bool get isEntrySection => switch (this) {
    SectionKind.personalDetails ||
    SectionKind.profile ||
    SectionKind.pageBreak => false,
    _ => true,
  };

  /// Page breaks are structural, not content-bearing.
  bool get isPageBreak => this == SectionKind.pageBreak;
}

/// Column placement for a section inside a document layout.
enum ColumnSlot {
  /// Full width across the page (only meaningful in `mix` layouts).
  fullWidth,

  /// First (left in LTR) column.
  left,

  /// Second (right in LTR) column.
  right,
}

/// Top-level layout strategy for a document.
enum LayoutMode {
  /// Single column.
  one,

  /// Two balanced columns.
  two,

  /// Mixed: full-width sections plus column sections.
  mix,
}

/// Proficiency scale used by skills and languages.
enum Proficiency { none, beginner, intermediate, advanced, expert, native }

/// Media type attached to a project.
enum MediaKind { image, video }

/// Export flavour.
enum ExportMode {
  /// Single-column, machine readable, ATS oriented.
  atsFriendly,

  /// Faithful to the user's visual design.
  designed,
}

/// Shape of the profile avatar in rendered documents.
enum AvatarShape { circle, roundedSquare, square, hidden }

/// Style of the divider drawn between sections.
enum DividerStyle { none, thin, thick, dotted, gradient }
