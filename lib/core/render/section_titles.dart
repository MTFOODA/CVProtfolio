/// Default section headings and their localisation.
library;

import 'package:cv_portfolio_maker/core/domain/enums.dart';

/// Default English heading for each section kind.
const Map<SectionKind, String> defaultSectionTitlesEn = {
  SectionKind.personalDetails: 'Personal Details',
  SectionKind.profile: 'Profile',
  SectionKind.experience: 'Professional Experience',
  SectionKind.education: 'Education',
  SectionKind.certificates: 'Certificates',
  SectionKind.projects: 'Projects',
  SectionKind.courses: 'Courses',
  SectionKind.skills: 'Skills',
  SectionKind.languages: 'Languages',
  SectionKind.awards: 'Awards & Achievements',
  SectionKind.volunteer: 'Volunteer Experience',
  SectionKind.publications: 'Publications',
  SectionKind.references: 'References',
  SectionKind.custom: 'Custom Section',
  SectionKind.pageBreak: 'Page Break',
};

/// Default Arabic heading for each section kind.
const Map<SectionKind, String> defaultSectionTitlesAr = {
  SectionKind.personalDetails: 'البيانات الشخصية',
  SectionKind.profile: 'الملخص المهني',
  SectionKind.experience: 'الخبرة المهنية',
  SectionKind.education: 'التعليم',
  SectionKind.certificates: 'الشهادات',
  SectionKind.projects: 'المشاريع',
  SectionKind.courses: 'الدورات',
  SectionKind.skills: 'المهارات',
  SectionKind.languages: 'اللغات',
  SectionKind.awards: 'الجوائز والإنجازات',
  SectionKind.volunteer: 'العمل التطوعي',
  SectionKind.publications: 'الأبحاث والمقالات',
  SectionKind.references: 'المُحيلون',
  SectionKind.custom: 'قسم مخصص',
  SectionKind.pageBreak: 'فاصل صفحات',
};

/// English default title resolver, for `ResolvedDocument.resolve`.
String defaultTitleEn(SectionKind kind) =>
    defaultSectionTitlesEn[kind] ?? 'Section';

/// Arabic default title resolver.
String defaultTitleAr(SectionKind kind) =>
    defaultSectionTitlesAr[kind] ?? 'قسم';

/// Returns the default resolver for a document language code.
String Function(SectionKind) defaultTitleResolver(String languageCode) =>
    languageCode == 'ar' ? defaultTitleAr : defaultTitleEn;

/// Human readable proficiency label.
String proficiencyLabel(int? level, {String languageCode = 'en'}) {
  if (level == null) return '';
  const en = ['', 'Beginner', 'Intermediate', 'Advanced', 'Expert', 'Native'];
  const ar = ['', 'مبتدئ', 'متوسط', 'متقدم', 'خبير', 'أصلي'];
  final table = languageCode == 'ar' ? ar : en;
  if (level < 0 || level >= table.length) return '';
  return table[level];
}

/// Icons used for contact labels in rendered documents.
const Map<String, int> contactIconCodes = {
  'Email': 0xe0e1, // Icons.mail_outline
  'Phone': 0xe0cd, // Icons.phone_outlined
  'Location': 0xe55f, // Icons.place_outlined
  'Website': 0xe894, // Icons.language
  'Link': 0xe157, // Icons.link
};

/// Icons used for section headings in rendered documents.
const Map<SectionKind, int> sectionIconCodes = {
  // Code points belong to the bundled CvContactIcons font, not the SDK's
  // version-specific MaterialIcons font. Screen and PDF use the same glyphs.
  SectionKind.profile: 0xe7fd,
  SectionKind.experience: 0xe8f9,
  SectionKind.education: 0xe80c,
  SectionKind.certificates: 0xe86f,
  SectionKind.projects: 0xe2c7,
  SectionKind.courses: 0xe865,
  SectionKind.skills: 0xe838,
  SectionKind.languages: 0xe894,
  SectionKind.awards: 0xe8e5,
  SectionKind.volunteer: 0xe87c,
  SectionKind.publications: 0xe873,
  SectionKind.references: 0xe7fb,
  SectionKind.custom: 0xe8b8,
};
