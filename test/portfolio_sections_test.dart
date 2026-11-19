import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/document_models.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/render/resolved_document.dart';
import 'package:cv_portfolio_maker/core/render/section_titles.dart';
import 'package:cv_portfolio_maker/core/theme/app_theme.dart';
import 'package:cv_portfolio_maker/core/widgets/app_surfaces.dart';
import 'package:cv_portfolio_maker/features/portfolio/portfolio_contacts.dart';
import 'package:cv_portfolio_maker/features/portfolio/portfolio_navigation.dart';
import 'package:cv_portfolio_maker/features/portfolio/public_portfolio_view.dart';

const _document = CvDocument(
  id: 'portfolio',
  ownerId: 'owner',
  title: 'Portfolio',
  type: DocumentType.portfolio,
  design: DocumentDesign(
    sections: [
      SectionConfig(id: 'intro', kind: SectionKind.profile),
      SectionConfig(id: 'contact', kind: SectionKind.personalDetails),
      SectionConfig(id: 'experience', kind: SectionKind.experience),
      SectionConfig(id: 'projects', kind: SectionKind.projects),
      SectionConfig(id: 'skills', kind: SectionKind.skills),
      SectionConfig(id: 'certificates', kind: SectionKind.certificates),
      SectionConfig(id: 'courses', kind: SectionKind.courses),
    ],
  ),
);
const _profile = UserProfile(
  id: 'owner',
  details: ProfileDetails(
    fullName: 'Ada',
    location: 'Cairo',
    website: 'https://ada.example/portfolio',
    email: 'ada@example.test',
    links: [
      'https://github.com/ada',
      'https://example.test/work',
      'javascript:alert(1)',
    ],
  ),
  experiences: [
    ExperienceEntry(
      id: 'exp',
      position: 'Senior Engineer',
      company: 'Engine Company',
    ),
  ],
  projects: [ProjectEntry(id: 'project', title: 'Engine project')],
  skills: [SkillEntry(id: 'skill', name: 'Dart')],
  certificates: [
    CertificateEntry(
      id: 'cert',
      name: 'Architecture certificate',
      credentialUrl: 'https://example.test/cert',
    ),
  ],
  customSections: [
    CustomSection(
      id: 'extra-course',
      title: 'My learning journey',
      category: CustomSectionCategory.courses,
      entries: [CustomEntry(id: 'course', title: 'Cloud course')],
    ),
    CustomSection(
      id: 'extra-project',
      title: 'Other work',
      category: CustomSectionCategory.projects,
      entries: [CustomEntry(id: 'project2', title: 'Second project')],
    ),
  ],
);

ResolvedDocument resolve(
  UserProfile profile, [
  CvDocument document = _document,
]) => ResolvedDocument.resolve(
  document: document,
  profile: profile,
  defaultTitle: defaultTitleResolver('en'),
);

void main() {
  test('page availability follows resolved visibility and typed additions', () {
    expect(
      PortfolioContent(
        resolve(const UserProfile(id: 'owner')),
        const UserProfile(id: 'owner'),
      ).pages,
      [PortfolioPage.about],
    );
    final content = PortfolioContent(resolve(_profile), _profile);
    final individuallyHidden = _profile.copyWith(
      experiences: [_profile.experiences.single.copyWith(visible: false)],
      projects: [_profile.projects.single.copyWith(visible: false)],
      skills: [_profile.skills.single.copyWith(visible: false)],
      certificates: [_profile.certificates.single.copyWith(visible: false)],
      courses: [
        const CourseEntry(
          id: 'hidden-course',
          name: 'Hidden course',
          visible: false,
        ),
      ],
      customSections: [],
    );
    expect(
      PortfolioContent(resolve(individuallyHidden), individuallyHidden).pages,
      [PortfolioPage.about],
    );
    expect(content.pages, PortfolioPage.values);
    expect(
      content.sections(PortfolioPage.credentials).map((s) => s.title),
      contains('My learning journey'),
    );
    expect(
      content
          .sections(PortfolioPage.projects)
          .expand((s) => s.customEntries)
          .single
          .title,
      'Second project',
    );
    final hidden = _document.copyWith(
      design: _document.design.copyWith(
        sections: [
          for (final section in _document.design.sections)
            section.copyWith(visible: false),
          const SectionConfig(
            id: 'hidden-course',
            kind: SectionKind.custom,
            customSectionId: 'extra-course',
            visible: false,
          ),
          const SectionConfig(
            id: 'hidden-project',
            kind: SectionKind.custom,
            customSectionId: 'extra-project',
            visible: false,
          ),
        ],
      ),
    );
    expect(PortfolioContent(resolve(_profile, hidden), _profile).pages, [
      PortfolioPage.about,
    ]);
  });

  test(
    'a typed project alone supplies a page and entry-level hiding removes it',
    () {
      final customOnly = _profile.copyWith(
        projects: [],
        skills: [],
        experiences: [],
        certificates: [],
        customSections: [_profile.customSections.last],
      );
      expect(PortfolioContent(resolve(customOnly), customOnly).pages, [
        PortfolioPage.about,
        PortfolioPage.projects,
      ]);
      final hidden = customOnly.copyWith(
        customSections: [
          customOnly.customSections.single.copyWith(
            entries: [
              customOnly.customSections.single.entries.single.copyWith(
                visible: false,
              ),
            ],
          ),
        ],
      );
      expect(PortfolioContent(resolve(hidden), hidden).pages, [
        PortfolioPage.about,
      ]);
    },
  );

  test('categories survive names/JSON while legacy known headings remain recognizable', () {
    for (final category in CustomSectionCategory.values) {
      final section = CustomSection(
        id: 's',
        title: 'A unique title',
        category: category,
      );
      expect(
        CustomSection.fromJson(section.toJson())
            .copyWith(title: 'Renamed')
            .category,
        category,
      );
    }
    expect(
      CustomSection.fromJson({'id': 's', 'title': 'Certificates'}).category,
      CustomSectionCategory.certificates,
    );
    expect(
      CustomSection.fromJson({'id': 's', 'title': 'الكورسات'}).category,
      CustomSectionCategory.courses,
    );
    expect(
      CustomSection.fromJson({'id': 's', 'title': 'Projects'}).category,
      CustomSectionCategory.projects,
    );
    expect(
      CustomSection.fromJson({'id': 's', 'title': 'Something else'}).category,
      CustomSectionCategory.custom,
    );
    expect(
      CustomSection.fromJson({
        'id': 's',
        'title': 'Courses',
        'category': 'custom',
      }).category,
      CustomSectionCategory.custom,
    );
  });

  testWidgets(
    'selection stays on the same page as navigation grows and falls back after deletion',
    (tester) async {
      var profile = _profile.copyWith(
        experiences: [],
        projects: [],
        certificates: [],
        customSections: [],
      );
      late StateSetter update;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return PublicPortfolioView(
                  document: _document,
                  profile: profile,
                  resolved: resolve(profile),
                  onOpen: (_) {},
                  onDownload: () {},
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(NavigationDestination, 'Skills'));
      await tester.pumpAndSettle();
      update(() => profile = _profile);
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3,
      );
      expect(find.text('Dart'), findsOneWidget);
      update(() => profile = _profile.copyWith(skills: []));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      expect(find.text('Senior Engineer'), findsNothing);
      expect(find.text('Architecture certificate'), findsNothing);
      await tester.tap(
        find.widgetWithText(NavigationDestination, 'Experience'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Senior Engineer'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(NavigationDestination, 'Credentials'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Architecture certificate'), findsOneWidget);
      expect(find.text('Cloud course'), findsOneWidget);
      update(() => profile = const UserProfile(id: 'owner'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'portfolio/other links are icons inside the hero and contact text is not repeated',
    (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: PublicPortfolioView(
              document: _document,
              profile: _profile,
              resolved: resolve(_profile),
              onOpen: opened.add,
              onDownload: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Contact'), findsNothing);
      final icon = find.byTooltip('Portfolio');
      expect(
        find.ancestor(of: icon, matching: find.byType(AppHeroSurface)),
        findsOneWidget,
      );
      await tester.ensureVisible(icon);
      await tester.tap(icon);
      await tester.pumpAndSettle();
      expect(opened.single.toString(), 'https://ada.example/portfolio');
      expect(find.text('https://ada.example/portfolio'), findsNothing);
      expect(
        find.ancestor(
          of: find.text('Cairo'),
          matching: find.byType(AppHeroSurface),
        ),
        findsOneWidget,
      );
      expect(
        portfolioContacts(_profile.details)
            .where((a) => a.uri.scheme == 'javascript'),
        isEmpty,
      );
      expect(
        portfolioContacts(_profile.details)
            .any((a) => a.uri.toString() == 'https://example.test/work'),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
