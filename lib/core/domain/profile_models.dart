/// Reusable profile entry models.
///
/// The profile is the single source of truth for a user's information. CVs and
/// portfolios *reference* these entries and control only their presentation.
///
/// These are hand-written immutable models (no code generation), so the project
/// builds without `build_runner` and has no `freezed`/`_$` generated code.
library;

Map<String, dynamic> _mapOf(dynamic raw) =>
    raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

List<T> _listOf<T>(dynamic raw, T Function(Map<String, dynamic>) decode) {
  if (raw is! List) return <T>[];
  return raw
      .whereType<Map>()
      .map((e) => decode(Map<String, dynamic>.from(e)))
      .toList();
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) return const <String>[];
  return raw.whereType<String>().toList();
}

DateRange _dateRangeOf(dynamic raw) => raw is Map
    ? DateRange.fromJson(Map<String, dynamic>.from(raw))
    : const DateRange();

bool _blank(String? value) => value == null || value.trim().isEmpty;

/// Formats an ISO-like date into `Mon YYYY`, tolerating free text.
String prettyDate(String? iso) {
  if (iso == null) return '';
  final value = iso.trim();
  if (value.isEmpty) return '';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[parsed.month - 1]} ${parsed.year}';
}

/// A date range used by experience, education and projects.
class DateRange {
  const DateRange({this.startIso, this.endIso, this.isCurrent = false});

  final String? startIso;
  final String? endIso;
  final bool isCurrent;

  DateRange copyWith({String? startIso, String? endIso, bool? isCurrent}) =>
      DateRange(
        startIso: startIso ?? this.startIso,
        endIso: endIso ?? this.endIso,
        isCurrent: isCurrent ?? this.isCurrent,
      );

  factory DateRange.fromJson(Map<String, dynamic> json) => DateRange(
    startIso: json['startIso'] as String?,
    endIso: json['endIso'] as String?,
    isCurrent: json['isCurrent'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'startIso': startIso,
    'endIso': endIso,
    'isCurrent': isCurrent,
  };
}

/// Extension helpers for [DateRange].
extension DateRangeX on DateRange {
  bool get isEmpty => _blank(startIso) && _blank(endIso);

  String format() {
    if (isEmpty) return '';
    final start = prettyDate(startIso);
    if (isCurrent || _blank(endIso)) {
      return start.isEmpty ? '' : '$start - Present';
    }
    final end = prettyDate(endIso);
    if (start.isEmpty) return end;
    return '$start - $end';
  }
}

/// Personal details shared across every document.
class ProfileDetails {
  const ProfileDetails({
    this.fullName,
    this.professionalTitle,
    this.email,
    this.phone,
    this.location,
    this.website,
    this.links = const <String>[],
    this.summary,
    this.avatarUrl,
  });

  final String? fullName;
  final String? professionalTitle;
  final String? email;
  final String? phone;
  final String? location;
  final String? website;
  final List<String> links;
  final String? summary;
  final String? avatarUrl;

  ProfileDetails copyWith({
    String? fullName,
    String? professionalTitle,
    String? email,
    String? phone,
    String? location,
    String? website,
    List<String>? links,
    String? summary,
    String? avatarUrl,
  }) => ProfileDetails(
    fullName: fullName ?? this.fullName,
    professionalTitle: professionalTitle ?? this.professionalTitle,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    location: location ?? this.location,
    website: website ?? this.website,
    links: links ?? this.links,
    summary: summary ?? this.summary,
    avatarUrl: avatarUrl ?? this.avatarUrl,
  );

  factory ProfileDetails.fromJson(Map<String, dynamic> json) => ProfileDetails(
    fullName: json['fullName'] as String?,
    professionalTitle: json['professionalTitle'] as String?,
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    location: json['location'] as String?,
    website: json['website'] as String?,
    links: _stringList(json['links']),
    summary: json['summary'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'professionalTitle': professionalTitle,
    'email': email,
    'phone': phone,
    'location': location,
    'website': website,
    'links': links,
    'summary': summary,
    'avatarUrl': avatarUrl,
  };
}

/// A professional experience entry.
class ExperienceEntry {
  const ExperienceEntry({
    required this.id,
    this.company,
    this.position,
    this.location,
    this.employmentType,
    this.dateRange = const DateRange(),
    this.descriptions = const <String>[],
    this.visible = true,
  });

  final String id;
  final String? company;
  final String? position;
  final String? location;
  final String? employmentType;
  final DateRange dateRange;
  final List<String> descriptions;
  final bool visible;

  ExperienceEntry copyWith({
    String? id,
    String? company,
    String? position,
    String? location,
    String? employmentType,
    DateRange? dateRange,
    List<String>? descriptions,
    bool? visible,
  }) => ExperienceEntry(
    id: id ?? this.id,
    company: company ?? this.company,
    position: position ?? this.position,
    location: location ?? this.location,
    employmentType: employmentType ?? this.employmentType,
    dateRange: dateRange ?? this.dateRange,
    descriptions: descriptions ?? this.descriptions,
    visible: visible ?? this.visible,
  );

  factory ExperienceEntry.fromJson(Map<String, dynamic> json) =>
      ExperienceEntry(
        id: '${json['id'] ?? ''}',
        company: json['company'] as String?,
        position: json['position'] as String?,
        location: json['location'] as String?,
        employmentType: json['employmentType'] as String?,
        dateRange: _dateRangeOf(json['dateRange']),
        descriptions: _stringList(json['descriptions']),
        visible: json['visible'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'company': company,
    'position': position,
    'location': location,
    'employmentType': employmentType,
    'dateRange': dateRange.toJson(),
    'descriptions': descriptions,
    'visible': visible,
  };
}

/// An education entry.
class EducationEntry {
  const EducationEntry({
    required this.id,
    this.institution,
    this.qualification,
    this.fieldOfStudy,
    this.dateRange = const DateRange(),
    this.grade,
    this.description,
    this.visible = true,
  });

  final String id;
  final String? institution;
  final String? qualification;
  final String? fieldOfStudy;
  final DateRange dateRange;
  final String? grade;
  final String? description;
  final bool visible;

  EducationEntry copyWith({
    String? id,
    String? institution,
    String? qualification,
    String? fieldOfStudy,
    DateRange? dateRange,
    String? grade,
    String? description,
    bool? visible,
  }) => EducationEntry(
    id: id ?? this.id,
    institution: institution ?? this.institution,
    qualification: qualification ?? this.qualification,
    fieldOfStudy: fieldOfStudy ?? this.fieldOfStudy,
    dateRange: dateRange ?? this.dateRange,
    grade: grade ?? this.grade,
    description: description ?? this.description,
    visible: visible ?? this.visible,
  );

  factory EducationEntry.fromJson(Map<String, dynamic> json) => EducationEntry(
    id: '${json['id'] ?? ''}',
    institution: json['institution'] as String?,
    qualification: json['qualification'] as String?,
    fieldOfStudy: json['fieldOfStudy'] as String?,
    dateRange: _dateRangeOf(json['dateRange']),
    grade: json['grade'] as String?,
    description: json['description'] as String?,
    visible: json['visible'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'institution': institution,
    'qualification': qualification,
    'fieldOfStudy': fieldOfStudy,
    'dateRange': dateRange.toJson(),
    'grade': grade,
    'description': description,
    'visible': visible,
  };
}

/// A skill entry. [proficiency] follows the 0..5 scale used by
/// `proficiencyLabel` (0 = unset, 5 = native).
class SkillEntry {
  const SkillEntry({
    required this.id,
    this.name,
    this.category = 'general',
    this.proficiency,
    this.visible = true,
  });

  final String id;
  final String? name;
  final String category;
  final int? proficiency;
  final bool visible;

  SkillEntry copyWith({
    String? id,
    String? name,
    String? category,
    int? proficiency,
    bool? visible,
  }) => SkillEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    proficiency: proficiency ?? this.proficiency,
    visible: visible ?? this.visible,
  );

  factory SkillEntry.fromJson(Map<String, dynamic> json) => SkillEntry(
    id: '${json['id'] ?? ''}',
    name: json['name'] as String?,
    category: json['category'] as String? ?? 'general',
    proficiency: (json['proficiency'] as num?)?.toInt(),
    visible: json['visible'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'proficiency': proficiency,
    'visible': visible,
  };
}

/// A spoken or written language with an optional proficiency level.
class LanguageEntry {
  const LanguageEntry({
    required this.id,
    required this.name,
    this.proficiency,
    this.visible = true,
  });

  final String id;
  final String name;
  final int? proficiency;
  final bool visible;

  LanguageEntry copyWith({
    String? id,
    String? name,
    int? proficiency,
    bool? visible,
  }) => LanguageEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    proficiency: proficiency ?? this.proficiency,
    visible: visible ?? this.visible,
  );

  factory LanguageEntry.fromJson(Map<String, dynamic> json) => LanguageEntry(
    id: '${json['id'] ?? ''}',
    name: '${json['name'] ?? ''}',
    proficiency: (json['proficiency'] as num?)?.toInt(),
    visible: json['visible'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'proficiency': proficiency,
    'visible': visible,
  };
}

/// A certificate or credential.
class CertificateEntry {
  const CertificateEntry({
    required this.id,
    required this.name,
    this.issuer,
    this.dateRange = const DateRange(),
    this.credentialId,
    this.credentialUrl,
    this.visible = true,
  });

  final String id;
  final String name;
  final String? issuer;
  final DateRange dateRange;
  final String? credentialId;
  final String? credentialUrl;
  final bool visible;

  CertificateEntry copyWith({
    String? id,
    String? name,
    String? issuer,
    DateRange? dateRange,
    String? credentialId,
    String? credentialUrl,
    bool? visible,
  }) => CertificateEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    issuer: issuer ?? this.issuer,
    dateRange: dateRange ?? this.dateRange,
    credentialId: credentialId ?? this.credentialId,
    credentialUrl: credentialUrl ?? this.credentialUrl,
    visible: visible ?? this.visible,
  );

  factory CertificateEntry.fromJson(Map<String, dynamic> json) =>
      CertificateEntry(
        id: '${json['id'] ?? ''}',
        name: '${json['name'] ?? ''}',
        issuer: json['issuer'] as String?,
        dateRange: _dateRangeOf(json['dateRange']),
        credentialId: json['credentialId'] as String?,
        credentialUrl: json['credentialUrl'] as String?,
        visible: json['visible'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'issuer': issuer,
    'dateRange': dateRange.toJson(),
    'credentialId': credentialId,
    'credentialUrl': credentialUrl,
    'visible': visible,
  };
}

/// A course entry.
class CourseEntry {
  const CourseEntry({
    required this.id,
    this.name,
    this.institution,
    this.dateRange = const DateRange(),
    this.credentialUrl,
    this.visible = true,
  });

  final String id;
  final String? name;
  final String? institution;
  final DateRange dateRange;
  final String? credentialUrl;
  final bool visible;

  CourseEntry copyWith({
    String? id,
    String? name,
    String? institution,
    DateRange? dateRange,
    String? credentialUrl,
    bool? visible,
  }) => CourseEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    institution: institution ?? this.institution,
    dateRange: dateRange ?? this.dateRange,
    credentialUrl: credentialUrl ?? this.credentialUrl,
    visible: visible ?? this.visible,
  );

  factory CourseEntry.fromJson(Map<String, dynamic> json) => CourseEntry(
    id: '${json['id'] ?? ''}',
    name: json['name'] as String?,
    institution: json['institution'] as String?,
    dateRange: _dateRangeOf(json['dateRange']),
    credentialUrl: json['credentialUrl'] as String?,
    visible: json['visible'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'institution': institution,
    'dateRange': dateRange.toJson(),
    'credentialUrl': credentialUrl,
    'visible': visible,
  };
}

/// An award or achievement entry.
class AwardEntry {
  const AwardEntry({
    required this.id,
    this.name,
    this.issuer,
    this.dateRange = const DateRange(),
    this.description,
    this.visible = true,
  });

  final String id;
  final String? name;
  final String? issuer;
  final DateRange dateRange;
  final String? description;
  final bool visible;

  AwardEntry copyWith({
    String? id,
    String? name,
    String? issuer,
    DateRange? dateRange,
    String? description,
    bool? visible,
  }) => AwardEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    issuer: issuer ?? this.issuer,
    dateRange: dateRange ?? this.dateRange,
    description: description ?? this.description,
    visible: visible ?? this.visible,
  );

  factory AwardEntry.fromJson(Map<String, dynamic> json) => AwardEntry(
    id: '${json['id'] ?? ''}',
    name: json['name'] as String?,
    issuer: json['issuer'] as String?,
    dateRange: _dateRangeOf(json['dateRange']),
    description: json['description'] as String?,
    visible: json['visible'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'issuer': issuer,
    'dateRange': dateRange.toJson(),
    'description': description,
    'visible': visible,
  };
}

/// A volunteer experience entry.
class VolunteerEntry {
  const VolunteerEntry({
    required this.id,
    this.organization,
    this.role,
    this.location,
    this.dateRange = const DateRange(),
    this.descriptions = const <String>[],
    this.visible = true,
  });

  final String id;
  final String? organization;
  final String? role;
  final String? location;
  final DateRange dateRange;
  final List<String> descriptions;
  final bool visible;

  VolunteerEntry copyWith({
    String? id,
    String? organization,
    String? role,
    String? location,
    DateRange? dateRange,
    List<String>? descriptions,
    bool? visible,
  }) => VolunteerEntry(
    id: id ?? this.id,
    organization: organization ?? this.organization,
    role: role ?? this.role,
    location: location ?? this.location,
    dateRange: dateRange ?? this.dateRange,
    descriptions: descriptions ?? this.descriptions,
    visible: visible ?? this.visible,
  );

  factory VolunteerEntry.fromJson(Map<String, dynamic> json) => VolunteerEntry(
    id: '${json['id'] ?? ''}',
    organization: json['organization'] as String?,
    role: json['role'] as String?,
    location: json['location'] as String?,
    dateRange: _dateRangeOf(json['dateRange']),
    descriptions: _stringList(json['descriptions']),
    visible: json['visible'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'organization': organization,
    'role': role,
    'location': location,
    'dateRange': dateRange.toJson(),
    'descriptions': descriptions,
    'visible': visible,
  };
}

/// A publication entry.
class PublicationEntry {
  const PublicationEntry({
    required this.id,
    this.title,
    this.venue,
    this.dateRange = const DateRange(),
    this.credentialUrl,
    this.visible = true,
  });

  final String id;
  final String? title;
  final String? venue;
  final DateRange dateRange;
  final String? credentialUrl;
  final bool visible;

  PublicationEntry copyWith({
    String? id,
    String? title,
    String? venue,
    DateRange? dateRange,
    String? credentialUrl,
    bool? visible,
  }) => PublicationEntry(
    id: id ?? this.id,
    title: title ?? this.title,
    venue: venue ?? this.venue,
    dateRange: dateRange ?? this.dateRange,
    credentialUrl: credentialUrl ?? this.credentialUrl,
    visible: visible ?? this.visible,
  );

  factory PublicationEntry.fromJson(Map<String, dynamic> json) =>
      PublicationEntry(
        id: '${json['id'] ?? ''}',
        title: json['title'] as String?,
        venue: json['venue'] as String?,
        dateRange: _dateRangeOf(json['dateRange']),
        credentialUrl: json['credentialUrl'] as String?,
        visible: json['visible'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'venue': venue,
    'dateRange': dateRange.toJson(),
    'credentialUrl': credentialUrl,
    'visible': visible,
  };
}

/// A reference entry.
class ReferenceEntry {
  const ReferenceEntry({
    required this.id,
    this.name,
    this.relationship,
    this.notes,
    this.visible = true,
  });

  final String id;
  final String? name;
  final String? relationship;
  final String? notes;
  final bool visible;

  ReferenceEntry copyWith({
    String? id,
    String? name,
    String? relationship,
    String? notes,
    bool? visible,
  }) => ReferenceEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    relationship: relationship ?? this.relationship,
    notes: notes ?? this.notes,
    visible: visible ?? this.visible,
  );

  factory ReferenceEntry.fromJson(Map<String, dynamic> json) => ReferenceEntry(
    id: '${json['id'] ?? ''}',
    name: json['name'] as String?,
    relationship: json['relationship'] as String?,
    notes: json['notes'] as String?,
    visible: json['visible'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'relationship': relationship,
    'notes': notes,
    'visible': visible,
  };
}

/// A project entry for portfolios.
class ProjectEntry {
  const ProjectEntry({
    required this.id,
    this.title,
    this.summary,
    this.description,
    this.demoUrl,
    this.sourceUrl,
    this.websiteUrl,
    this.technologies = const <String>[],
    this.media = const <String>[],
    this.featured = false,
    this.visible = true,
  });

  final String id;
  final String? title;
  final String? summary;
  final String? description;
  final String? demoUrl;
  final String? sourceUrl;
  final String? websiteUrl;
  final List<String> technologies;
  final List<String> media;
  final bool featured;
  final bool visible;

  ProjectEntry copyWith({
    String? id,
    String? title,
    String? summary,
    String? description,
    String? demoUrl,
    String? sourceUrl,
    String? websiteUrl,
    List<String>? technologies,
    List<String>? media,
    bool? featured,
    bool? visible,
  }) => ProjectEntry(
    id: id ?? this.id,
    title: title ?? this.title,
    summary: summary ?? this.summary,
    description: description ?? this.description,
    demoUrl: demoUrl ?? this.demoUrl,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    websiteUrl: websiteUrl ?? this.websiteUrl,
    technologies: technologies ?? this.technologies,
    media: media ?? this.media,
    featured: featured ?? this.featured,
    visible: visible ?? this.visible,
  );

  factory ProjectEntry.fromJson(Map<String, dynamic> json) => ProjectEntry(
    id: '${json['id'] ?? ''}',
    title: json['title'] as String?,
    summary: json['summary'] as String?,
    description: json['description'] as String?,
    demoUrl: json['demoUrl'] as String?,
    sourceUrl: json['sourceUrl'] as String?,
    websiteUrl: json['websiteUrl'] as String?,
    technologies: _stringList(json['technologies']),
    media: _stringList(json['media']),
    featured: json['featured'] as bool? ?? false,
    visible: json['visible'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'summary': summary,
    'description': description,
    'demoUrl': demoUrl,
    'sourceUrl': sourceUrl,
    'websiteUrl': websiteUrl,
    'technologies': technologies,
    'media': media,
    'featured': featured,
    'visible': visible,
  };
}

/// A user-defined section with its own entries.
class CustomSection {
  const CustomSection({
    required this.id,
    required this.title,
    this.entries = const <CustomEntry>[],
  });

  final String id;
  final String title;
  final List<CustomEntry> entries;

  CustomSection copyWith({
    String? id,
    String? title,
    List<CustomEntry>? entries,
  }) => CustomSection(
    id: id ?? this.id,
    title: title ?? this.title,
    entries: entries ?? this.entries,
  );

  factory CustomSection.fromJson(Map<String, dynamic> json) => CustomSection(
    id: '${json['id'] ?? ''}',
    title: '${json['title'] ?? ''}',
    entries: _listOf<CustomEntry>(json['entries'], CustomEntry.fromJson),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'entries': entries.map((e) => e.toJson()).toList(),
  };
}

/// An entry inside a user-defined section.
class CustomEntry {
  const CustomEntry({required this.id, required this.title, this.content});

  final String id;
  final String title;
  final String? content;

  CustomEntry copyWith({String? id, String? title, String? content}) =>
      CustomEntry(
        id: id ?? this.id,
        title: title ?? this.title,
        content: content ?? this.content,
      );

  factory CustomEntry.fromJson(Map<String, dynamic> json) => CustomEntry(
    id: '${json['id'] ?? ''}',
    title: '${json['title'] ?? ''}',
    content: json['content'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
  };
}

/// The complete profile: personal details plus every section's entries.
class UserProfile {
  const UserProfile({
    required this.id,
    this.details = const ProfileDetails(),
    this.experiences = const <ExperienceEntry>[],
    this.education = const <EducationEntry>[],
    this.skills = const <SkillEntry>[],
    this.languages = const <LanguageEntry>[],
    this.certificates = const <CertificateEntry>[],
    this.courses = const <CourseEntry>[],
    this.awards = const <AwardEntry>[],
    this.volunteer = const <VolunteerEntry>[],
    this.publications = const <PublicationEntry>[],
    this.references = const <ReferenceEntry>[],
    this.projects = const <ProjectEntry>[],
    this.customSections = const <CustomSection>[],
    this.updatedAtIso,
  });

  final String id;
  final ProfileDetails details;
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
  final List<CustomSection> customSections;
  final String? updatedAtIso;

  UserProfile copyWith({
    String? id,
    ProfileDetails? details,
    List<ExperienceEntry>? experiences,
    List<EducationEntry>? education,
    List<SkillEntry>? skills,
    List<LanguageEntry>? languages,
    List<CertificateEntry>? certificates,
    List<CourseEntry>? courses,
    List<AwardEntry>? awards,
    List<VolunteerEntry>? volunteer,
    List<PublicationEntry>? publications,
    List<ReferenceEntry>? references,
    List<ProjectEntry>? projects,
    List<CustomSection>? customSections,
    String? updatedAtIso,
  }) => UserProfile(
    id: id ?? this.id,
    details: details ?? this.details,
    experiences: experiences ?? this.experiences,
    education: education ?? this.education,
    skills: skills ?? this.skills,
    languages: languages ?? this.languages,
    certificates: certificates ?? this.certificates,
    courses: courses ?? this.courses,
    awards: awards ?? this.awards,
    volunteer: volunteer ?? this.volunteer,
    publications: publications ?? this.publications,
    references: references ?? this.references,
    projects: projects ?? this.projects,
    customSections: customSections ?? this.customSections,
    updatedAtIso: updatedAtIso ?? this.updatedAtIso,
  );

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: '${json['id'] ?? ''}',
    details: ProfileDetails.fromJson(_mapOf(json['details'])),
    experiences: _listOf<ExperienceEntry>(
      json['experiences'],
      ExperienceEntry.fromJson,
    ),
    education: _listOf<EducationEntry>(
      json['education'],
      EducationEntry.fromJson,
    ),
    skills: _listOf<SkillEntry>(json['skills'], SkillEntry.fromJson),
    languages: _listOf<LanguageEntry>(
      json['languages'],
      LanguageEntry.fromJson,
    ),
    certificates: _listOf<CertificateEntry>(
      json['certificates'],
      CertificateEntry.fromJson,
    ),
    courses: _listOf<CourseEntry>(json['courses'], CourseEntry.fromJson),
    awards: _listOf<AwardEntry>(json['awards'], AwardEntry.fromJson),
    volunteer: _listOf<VolunteerEntry>(
      json['volunteer'],
      VolunteerEntry.fromJson,
    ),
    publications: _listOf<PublicationEntry>(
      json['publications'],
      PublicationEntry.fromJson,
    ),
    references: _listOf<ReferenceEntry>(
      json['references'],
      ReferenceEntry.fromJson,
    ),
    projects: _listOf<ProjectEntry>(json['projects'], ProjectEntry.fromJson),
    customSections: _listOf<CustomSection>(
      json['customSections'] ?? json['custom_sections'],
      CustomSection.fromJson,
    ),
    updatedAtIso: (json['updatedAtIso'] ?? json['updated_at']) as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'details': details.toJson(),
    'experiences': experiences.map((e) => e.toJson()).toList(),
    'education': education.map((e) => e.toJson()).toList(),
    'skills': skills.map((e) => e.toJson()).toList(),
    'languages': languages.map((e) => e.toJson()).toList(),
    'certificates': certificates.map((e) => e.toJson()).toList(),
    'courses': courses.map((e) => e.toJson()).toList(),
    'awards': awards.map((e) => e.toJson()).toList(),
    'volunteer': volunteer.map((e) => e.toJson()).toList(),
    'publications': publications.map((e) => e.toJson()).toList(),
    'references': references.map((e) => e.toJson()).toList(),
    'projects': projects.map((e) => e.toJson()).toList(),
    'custom_sections': customSections.map((e) => e.toJson()).toList(),
    'updated_at': updatedAtIso,
  };
}

/// Calculates profile completeness as a 0..100 score for onboarding.
///
/// Each of the ten core signals contributes equally. Contact/identity fields
/// count when non-empty; collection sections count when they have entries.
int profileCompletion(UserProfile profile) {
  var done = 0;
  const total = 10;

  void tally(bool filled) {
    if (filled) done++;
  }

  tally(!_blank(profile.details.fullName));
  tally(!_blank(profile.details.professionalTitle));
  tally(!_blank(profile.details.email));
  tally(!_blank(profile.details.phone));
  tally(!_blank(profile.details.summary));
  tally(profile.experiences.isNotEmpty);
  tally(profile.education.isNotEmpty);
  tally(profile.skills.isNotEmpty);
  tally(profile.projects.isNotEmpty);
  tally(profile.languages.isNotEmpty);

  final score = ((done / total) * 100).round();
  return score.clamp(0, 100).toInt();
}
