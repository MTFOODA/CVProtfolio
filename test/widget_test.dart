import 'package:flutter_test/flutter_test.dart';

import 'package:cv_portfolio_maker/core/domain/profile_models.dart';

void main() {
  group('UserProfile', () {
    test('round-trips through JSON', () {
      final profile = UserProfile(
        id: 'u1',
        details: const ProfileDetails(
          fullName: 'Ada Lovelace',
          email: 'ada@example.com',
          links: ['https://example.com'],
        ),
        experiences: [
          ExperienceEntry(
            id: 'e1',
            company: 'Analytical Engines Ltd',
            position: 'Analyst',
            dateRange: DateRange(startIso: '1843-01-01'),
          ),
        ],
        customSections: const [
          CustomSection(
            id: 'cs1',
            title: 'Interests',
            entries: [
              CustomEntry(id: 'ce1', title: 'Mathematics', content: 'Poetry'),
            ],
          ),
        ],
      );

      final restored = UserProfile.fromJson(profile.toJson());

      expect(restored.id, 'u1');
      expect(restored.details.fullName, 'Ada Lovelace');
      expect(restored.details.links, ['https://example.com']);
      expect(restored.experiences.single.company, 'Analytical Engines Ltd');
      expect(
        restored.customSections.single.entries.single.title,
        'Mathematics',
      );
    });

    test('parses snake_case custom_sections from the database row shape', () {
      final profile = UserProfile.fromJson({
        'id': 'u1',
        'details': {'summary': 'Hello'},
        'custom_sections': [
          {'id': 'cs1', 'title': 'Interests', 'entries': []},
        ],
      });

      expect(profile.details.summary, 'Hello');
      expect(profile.customSections.single.id, 'cs1');
    });
  });

  group('profileCompletion', () {
    test('empty profile scores 0', () {
      expect(profileCompletion(const UserProfile(id: 'u1')), 0);
    });

    test('full profile scores 100', () {
      final profile = UserProfile(
        id: 'u1',
        details: const ProfileDetails(
          fullName: 'Ada',
          professionalTitle: 'Analyst',
          email: 'a@b.c',
          phone: '123',
          summary: 'A pioneer',
        ),
        experiences: [ExperienceEntry(id: 'e1')],
        education: [EducationEntry(id: 'ed1')],
        skills: [SkillEntry(id: 's1', name: 'Math')],
        projects: [ProjectEntry(id: 'p1')],
        languages: [LanguageEntry(id: 'l1', name: 'English')],
      );

      expect(profileCompletion(profile), 100);
    });
  });
}
