import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cv_portfolio_maker/app/biometric_lock.dart';
import 'package:cv_portfolio_maker/data/auth/biometric_authenticator.dart';

import 'package:cv_portfolio_maker/app/providers.dart';
import 'package:cv_portfolio_maker/core/config/app_config.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/data/auth/auth_service.dart';
import 'package:cv_portfolio_maker/data/local/local_repositories.dart';
import 'package:cv_portfolio_maker/data/local/local_store.dart';
import 'package:cv_portfolio_maker/features/cv_builder/cv_builder_wizard_screen.dart';
import 'package:cv_portfolio_maker/core/widgets/contact_link_fields.dart';

/// A signed-in [AuthService] with no external dependencies.
class _NoBiometrics extends Fake implements BiometricAuthenticator {
  @override
  bool get usesWindowsHello => false;
  @override
  Future<bool> isAvailable() async => false;
}

class _FakeAuthService implements AuthService {
  _FakeAuthService(this.user);

  final AuthUser user;

  @override
  AuthUser? get currentUser => user;

  @override
  Stream<AuthUser?> get authStateChanges => Stream<AuthUser?>.value(user);

  @override
  Future<AuthUser> signInWithGoogle() async => user;

  @override
  Future<AuthUser> signInLocally({String email = 'local@example.com'}) async =>
      user;

  @override
  Future<AuthUser?> restoreSession() async => user;

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async => user;

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async => user;

  @override
  Future<void> resetPassword(String email) async {}

  @override
  bool get isRecoveringPassword => false;

  @override
  Future<void> updatePassword(String password) async {}
}

void main() {
  late Directory dir;
  late LocalBackendOrSupabase backend;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('cv_wizard_test');
    backend = LocalBackendOrSupabase.local(
      LocalBackend(LocalStore.forDirectory(dir)),
    );

    await backend.saveProfile(
      UserProfile(
        id: 'user-1',
        details: const ProfileDetails(
          fullName: 'Ada Lovelace',
          email: 'ada@example.com',
        ),
        experiences: const [
          ExperienceEntry(
            id: 'exp-1',
            position: 'Engineer',
            company: 'Analytical Engines',
            dateRange: DateRange(startIso: '2020-01-15', endIso: '2022-06-30'),
            descriptions: ['Built things'],
          ),
          // Currently employed, with a start date and no end date.
          ExperienceEntry(
            id: 'exp-2',
            position: 'Lead',
            company: 'Difference Engine',
            dateRange: DateRange(startIso: '2022-07-01', isCurrent: true),
          ),
        ],
        education: const [
          EducationEntry(
            id: 'edu-1',
            institution: 'Cambridge',
            qualification: 'BSc',
            fieldOfStudy: 'Mathematics',
            dateRange: DateRange(startIso: '2015-09-01', endIso: '2018-06-30'),
          ),
          // Optional dates entirely missing.
          EducationEntry(
            id: 'edu-2',
            institution: 'Open University',
            qualification: 'MSc',
          ),
        ],
        languages: const [
          LanguageEntry(id: 'lang-1', name: 'English', proficiency: 5),
        ],
      ),
    );
  });

  tearDown(() {
    // The local store may still hold a handle on some platforms; a failed
    // temp cleanup must never fail the test.
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Ignored: the OS will reclaim the temporary directory.
    }
  });

  /// Advances the widget tree while allowing the local JSON store's real
  /// file I/O to complete, which the fake-async test zone would otherwise
  /// block forever.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
    }
    await tester.pump();
  }

  Future<void> pumpWizard(WidgetTester tester) async {
    await tester.runAsync(
      () => backend.saveDocument(
        const CvDocument(
          id: 'editing',
          ownerId: 'user-1',
          title: 'Existing CV',
        ),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          biometricAuthenticatorProvider.overrideWithValue(_NoBiometrics()),
          appConfigProvider.overrideWithValue(
            const AppConfig(
              supabaseUrl: '',
              supabaseAnonKey: '',
              googleWebClientId: '',
              googleIosClientId: '',
              shareBaseUrl: 'https://example.test',
            ),
          ),
          backendProvider.overrideWithValue(backend),
          authServiceProvider.overrideWithValue(
            _FakeAuthService(
              const AuthUser(id: 'user-1', email: 'ada@example.com'),
            ),
          ),
        ],
        child: const MaterialApp(
          home: CvBuilderWizardScreen(documentId: 'editing'),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> tapText(WidgetTester tester, String label) async {
    final finder = find.text(label);
    expect(finder, findsWidgets, reason: 'Expected a "$label" control');
    await tester.tap(finder.first);
    await settle(tester);
  }

  testWidgets(
    'contact display names save with destinations and preserve other links',
    (tester) async {
      const githubUrl = 'https://github.com/example-user';
      const otherUrl = 'https://example.test/profile';
      await tester.runAsync(
        () => backend.saveProfile(
          UserProfile(
            id: 'user-1',
            details: const ProfileDetails(
              fullName: 'Ada Lovelace',
              email: 'ada@example.com',
              avatarUrl: 'https://example.test/avatar.png',
              website: 'https://example.test',
              links: [githubUrl, otherUrl],
              linkLabels: {otherUrl: 'Other profile'},
            ),
          ),
        ),
      );
      await pumpWizard(tester);
      final githubFields = find.byWidgetPredicate(
        (w) => w is ContactLinkFields && w.label == 'GitHub',
      );
      final labelField = find
          .descendant(of: githubFields, matching: find.byType(TextFormField))
          .last;
      await tester.ensureVisible(labelField);
      await tester.enterText(labelField, 'dev-name');
      await tapText(tester, 'Continue');
      final draft = await tester.runAsync(
        () => backend.loadCvDraft('user-1', 'editing'),
      );
      final saved = draft!.profile;
      expect(saved.details.links, contains(githubUrl));
      expect(saved.details.linkLabels[githubUrl], 'dev-name');
      expect(saved.details.links, contains(otherUrl));
      expect(saved.details.linkLabels[otherUrl], 'Other profile');
      expect(saved.details.avatarUrl, 'https://example.test/avatar.png');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Continue through to Review renders every date range', (
    tester,
  ) async {
    await pumpWizard(tester);

    // Personal -> Experience -> Education -> Projects -> Skills -> Languages.
    for (var step = 0; step < 5; step++) {
      await tapText(tester, 'Continue');
    }

    // Languages step is now visible.
    expect(find.text('Languages'), findsWidgets);

    // Languages -> Additional entries -> Review.
    await tapText(tester, 'Continue');
    expect(find.byKey(const ValueKey('add-custom-entry')), findsOneWidget);
    await tapText(tester, 'Continue');

    // Review must render without throwing.
    expect(tester.takeException(), isNull);
    expect(find.text('Review & Custom Content'), findsWidgets);

    // Formatted ranges, including current employment and missing dates.
    expect(find.textContaining('Jan 2020 - Jun 2022'), findsWidgets);
    expect(find.textContaining('Jul 2022 - Present'), findsWidgets);
    expect(find.textContaining('Sep 2015 - Jun 2018'), findsWidgets);
  });

  testWidgets(
    'experience descriptions retain old items and save a pending labelled item',
    (tester) async {
      await pumpWizard(tester);
      await tapText(tester, 'Continue');
      await tapText(tester, 'Engineer');
      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('Built things', findRichText: true),
        findsOneWidget,
      );
      final dropdown = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Architecture').last);
      await tester.pumpAndSettle();
      final input = find.widgetWithText(TextField, 'Entry text');
      await tester.ensureVisible(input);
      await tester.enterText(input, 'Clean architecture with Cubit');
      final save = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Add'),
      );
      await tester.tap(save);
      await tester.pumpAndSettle();
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      await tapText(tester, 'Continue');
      final draft = await tester.runAsync(
        () => backend.loadCvDraft('user-1', 'editing'),
      );
      final descriptions =
          draft!.profile.experiences.first.resolvedDescriptions;
      expect(descriptions.map((e) => e.formatted), [
        'Built things',
        'Architecture: Clean architecture with Cubit',
      ]);
      expect(descriptions.last.label, 'Architecture');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Skip jumps to Review and Back returns through additional entries',
    (tester) async {
      await pumpWizard(tester);

      await tapText(tester, 'Skip');
      expect(find.text('Review & Custom Content'), findsWidgets);
      expect(tester.takeException(), isNull);

      await tapText(tester, 'Back');
      expect(find.byKey(const ValueKey('add-custom-entry')), findsOneWidget);
      await tapText(tester, 'Back');
      expect(find.text('Languages'), findsWidgets);
      expect(tester.takeException(), isNull);

      await tapText(tester, 'Continue');
      await tapText(tester, 'Continue');
      expect(find.text('Review & Custom Content'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
