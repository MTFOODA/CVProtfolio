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
  'Email': 0xe0be, // Icons.mail_outline
  'Phone': 0xe0b0, // Icons.phone_outlined
  'Location': 0xe0c8, // Icons.place_outlined
  'Website': 0xe894, // Icons.language
  'Link': 0xe157, // Icons.link
};

/// Icons used for section headings in rendered documents.
const Map<SectionKind, int> sectionIconCodes = {
  SectionKind.profile: 0xe873, // Icons.person_outline
  SectionKind.experience: 0xe8d3, // Icons.work_outline
  SectionKind.education: 0xe80c, // Icons.school_outlined
  SectionKind.certificates: 0xe868, // Icons.workspace_premium_outlined
  SectionKind.projects: 0xe871, // Icons.folder_outlined
  SectionKind.courses: 0xe873, // Icons.menu_book_outlined
  SectionKind.skills: 0xe945, // Icons.star_outline
  SectionKind.languages: 0xe8e2, // Icons.translate
  SectionKind.awards: 0xea23, // Icons.emoji_events_outlined
  SectionKind.volunteer: 0xea47, // Icons.volunteer_activism_outlined
  SectionKind.publications: 0xe865, // Icons.article_outlined
  SectionKind.references: 0xe7fd, // Icons.people_outline
  SectionKind.custom: 0xe147, // Icons.tune
};
