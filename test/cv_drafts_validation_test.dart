import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/render/resolved_document.dart';
import 'package:cv_portfolio_maker/core/render/section_titles.dart';
import 'package:cv_portfolio_maker/core/utils/contact_links.dart';
import 'package:cv_portfolio_maker/core/utils/input_validation.dart';
import 'package:cv_portfolio_maker/core/utils/profile_content.dart';
import 'package:cv_portfolio_maker/data/local/local_repositories.dart';
import 'package:cv_portfolio_maker/data/local/local_store.dart';
import 'package:cv_portfolio_maker/data/repositories.dart';

void main() {
  test('names and descriptions accept either language while rejecting mixed scripts', () {
    for (final name in [
      'Grace Hopper',
      'أحمد محمد',
      'O’Connor',
      'Jean-Luc',
      'د. أحمد',
    ]) {
      expect(InputValidation.name(name), isNull, reason: name);
    }
    expect(InputValidation.name('أحمد Ahmed'), 'singleLanguageRequired');
    expect(InputValidation.name('12345'), 'invalidName');
    expect(InputValidation.name(''), 'required');
    expect(InputValidation.text('وصف عربي للمشروع'), isNull);
    expect(InputValidation.text('A useful project.'), isNull);
    expect(InputValidation.text('وصف Flutter'), 'singleLanguageRequired');
    expect(InputValidation.text('a' * 4001), 'inputTooLong');
    expect(InputValidation.text('abc\u0000'), 'invalidText');
  });
  test('grade remains text, including Arabic words, letter grades and decimal scores', () {
    for (final value in ['Excellent', 'جيد جدًا', 'A+', '3.8 / 4', '85%', '']) {
      expect(InputValidation.grade(value), isNull, reason: value);
    }
    expect(InputValidation.grade('جيد Good'), 'singleLanguageRequired');
  });
  test(
    'email, link and international phone conditions reject malformed input',
    () {
      for (final value in ['ada@example.com', 'dev+cv@sub.example.test']) {
        expect(InputValidation.email(value), isNull);
      }
      for (final value in [
        'a..b@example.test',
        '.a@example.test',
        'a@-example.test',
        'a@x..test',
        'bad',
        'a b@example.test',
      ]) {
        expect(InputValidation.email(value), 'invalidEmail', reason: value);
      }
      expect(internationalPhone('+20 (101) 234-5678'), '+201012345678');
      expect(internationalPhone('٠٠٢٠١٠١٢٣٤٥٦٧٨'), '+201012345678');
      expect(InputValidation.phone('01012345678'), 'invalidPhone');
      expect(InputValidation.phone('+201012345678'), isNull);
      expect(contactWebUrl('github.com/mtfooda'), 'https://github.com/mtfooda');
      for (final link in [
        'javascript:alert(1)',
        'ftp://example.test',
        'https://a..test',
        'https://-a.test',
        'https://user:secret@example.test',
        'https://example.test/a b',
      ]) {
        expect(contactWebUrl(link), isNull, reason: link);
      }
    },
  );
  test('UI date labels localise without changing the default stored-document formatting', () {
    const range = DateRange(startIso: '2024-01-01', isCurrent: true);
    expect(range.format(), 'Jan 2024 - Present');
    expect(range.format(languageCode: 'ar'), 'يناير 2024 - الآن');
  });

  late Directory dir;
  late LocalStore store;
  late LocalBackend backend;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('cv_draft_audit_');
    store = LocalStore.forDirectory(dir);
    backend = LocalBackend(store);
  });
  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });
  const oldProfile = UserProfile(
    id: 'owner',
    details: ProfileDetails(fullName: 'Ada Lovelace'),
    projects: [ProjectEntry(id: 'old', title: 'Existing project')],
    skills: [SkillEntry(id: 's', name: 'Dart')],
  );

  test(
    'legacy CV content is preserved before the shared profile changes',
    () async {
      await store.writeMap('profiles_owner', oldProfile.toJson());
      await store.writeList('documents_owner', [
        const CvDocument(
          id: 'legacy',
          ownerId: 'owner',
          title: 'Old CV',
        ).toJson()..remove('profileSnapshot'),
      ]);
      const next = UserProfile(
        id: 'owner',
        details: ProfileDetails(fullName: 'Grace Hopper'),
      );
      await backend.saveProfile(next);
      final reopened = await LocalBackend(LocalStore.forDirectory(dir))
          .loadDocument('legacy', 'owner');
      expect(reopened!.profileSnapshot!.details.fullName, 'Ada Lovelace');
      final resolved = ResolvedDocument.resolve(
        document: reopened,
        profile: next,
        defaultTitle: defaultTitleEn,
      );
      expect(resolved.details.fullName, 'Ada Lovelace');
      expect(
        (await backend.loadProfile('owner'))!.details.fullName,
        'Grace Hopper',
      );
    },
  );
  test('each CV saves independent content and can be reopened without a live profile overwrite', () async {
    await backend.saveProfile(oldProfile);
    final first = await backend.saveDocument(
      const CvDocument(id: 'a', ownerId: 'owner', title: 'First'),
    );
    const secondProfile = UserProfile(
      id: 'owner',
      details: ProfileDetails(fullName: 'Grace Hopper'),
    );
    await backend.saveDocument(
      const CvDocument(
        id: 'b',
        ownerId: 'owner',
        title: 'Second',
        profileSnapshot: secondProfile,
      ),
    );
    await backend.saveProfile(secondProfile);
    final reopened = await backend.loadDocument('a', 'owner');
    expect(reopened!.profileSnapshot!.details.fullName, 'Ada Lovelace');
    expect(
      (await backend.loadDocument(
        'b',
        'owner',
      ))!.profileSnapshot!.details.fullName,
      'Grace Hopper',
    );
    expect(
      CvDocument.fromJson(first.toJson())
          .profileSnapshot!
          .projects
          .single
          .title,
      'Existing project',
    );
  });
  test('unsaved drafts are independent by user and document and are excluded from saved CVs', () async {
    await backend.saveCvDraft(
      'owner',
      'new',
      const CvBuilderDraft(profile: oldProfile, step: 3),
    );
    await backend.saveCvDraft(
      'owner',
      'existing',
      const CvBuilderDraft(
        profile: UserProfile(
          id: 'owner',
          details: ProfileDetails(fullName: 'Grace'),
        ),
        step: 5,
      ),
    );
    await backend.saveCvDraft(
      'other',
      'new',
      const CvBuilderDraft(
        profile: UserProfile(
          id: 'other',
          details: ProfileDetails(fullName: 'Other'),
        ),
      ),
    );
    final reopened = LocalBackend(LocalStore.forDirectory(dir));
    expect((await reopened.loadCvDraft('owner', 'new'))!.step, 3);
    expect(
      (await reopened.loadCvDraft(
        'owner',
        'existing',
      ))!.profile.details.fullName,
      'Grace',
    );
    expect(
      (await reopened.loadCvDraft('other', 'new'))!.profile.details.fullName,
      'Other',
    );
    expect(await reopened.listDocuments('owner'), isEmpty);
    expect(await reopened.loadProfile('owner'), isNull);
    await reopened.deleteCvDraft('owner', 'new');
    expect(await reopened.loadCvDraft('owner', 'new'), isNull);
    expect(await reopened.loadCvDraft('owner', 'existing'), isNotNull);
    expect(
      () => reopened.saveCvDraft(
        'other',
        'bad',
        const CvBuilderDraft(profile: oldProfile),
      ),
      throwsA(isA<UnauthorizedException>()),
    );
  });
  test('saving a new CV preserves existing Portfolio entries and updates matching ids', () {
    const freshCv = UserProfile(
      id: 'owner',
      details: ProfileDetails(fullName: 'Grace Hopper'),
      projects: [ProjectEntry(id: 'new', title: 'New project')],
      skills: [SkillEntry(id: 's', name: 'Dart', proficiency: 4)],
    );
    final merged = mergeCvIntoProfile(oldProfile, freshCv);
    expect(merged.projects.map((p) => p.id), ['old', 'new']);
    expect(merged.skills.single.proficiency, 4);
    expect(freshCv.projects.map((p) => p.id), ['new']);
    expect(oldProfile.details.fullName, 'Ada Lovelace');
  });
  test('editing an old CV applies explicit deletions without reverting newer profile content', () {
    const latest = UserProfile(
      id: 'owner',
      details: ProfileDetails(fullName: 'Grace Hopper'),
      projects: [
        ProjectEntry(id: 'old', title: 'Updated project'),
        ProjectEntry(id: 'new', title: 'New project'),
      ],
    );
    final unchanged = mergeCvIntoProfile(
      latest,
      oldProfile,
      previous: oldProfile,
    );
    expect(unchanged.details.fullName, 'Grace Hopper');
    expect(unchanged.projects.first.title, 'Updated project');
    final removed = mergeCvIntoProfile(
      latest,
      oldProfile.copyWith(projects: []),
      previous: oldProfile,
    );
    expect(removed.projects.single.id, 'new');
    expect(removed.details.fullName, 'Grace Hopper');
  });
}
