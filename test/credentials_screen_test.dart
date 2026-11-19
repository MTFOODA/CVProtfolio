import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cv_portfolio_maker/app/providers.dart';
import 'package:cv_portfolio_maker/app/session.dart';
import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/theme/app_theme.dart';
import 'package:cv_portfolio_maker/core/widgets/app_surfaces.dart';
import 'package:cv_portfolio_maker/data/auth/auth_service.dart';
import 'package:cv_portfolio_maker/data/local/local_repositories.dart';
import 'package:cv_portfolio_maker/data/local/local_store.dart';
import 'package:cv_portfolio_maker/features/settings/credentials_screen.dart';

class _Session extends SessionController {
  @override
  Future<AuthUser?> build() async =>
      const AuthUser(id: 'owner', email: 'owner@example.test');
}

class _Backend extends LocalBackend {
  _Backend(super.store);
  bool failSave = false;
  @override
  Future<UserProfile> saveProfile(UserProfile profile) {
    if (failSave) throw StateError('Offline');
    return super.saveProfile(profile);
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 35; i++) {
    await tester.pump(const Duration(milliseconds: 40));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  await tester.pump();
}

void main() {
  late Directory directory;
  late _Backend backend;
  late ProviderContainer container;
  setUp(() async {
    directory = Directory.systemTemp.createTempSync('credential_ui_');
    backend = _Backend(LocalStore.forDirectory(directory));
    await backend.saveProfile(
      const UserProfile(
        id: 'owner',
        details: ProfileDetails(fullName: 'Ada Lovelace'),
        projects: [ProjectEntry(id: 'retained', title: 'Existing project')],
      ),
    );
    await backend.saveDocument(
      const CvDocument(id: 'cv', ownerId: 'owner', title: 'Existing CV'),
    );
    container = ProviderContainer(
      overrides: [
        backendProvider.overrideWithValue(
          LocalBackendOrSupabase.local(backend),
        ),
        sessionProvider2.overrideWith(_Session.new),
      ],
    );
    await container.read(sessionProvider2.future);
  });
  tearDown(() async {
    container.dispose();
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  Future<void> show(
    WidgetTester tester,
    bool courses, {
    UserProfile? draft,
    Future<void> Function(UserProfile)? onSave,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => AppBackdrop(child: child!),
          home: CredentialsScreen(
            courses: courses,
            initialProfile: draft,
            onSave: onSave,
          ),
        ),
      ),
    );
    await _settle(tester);
  }

  Future<void> add(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('add-credential')));
    await _settle(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Professional Learning',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Issuer / institution'),
      'Institute',
    );
  }

  for (final courses in [false, true]) {
    testWidgets(
      '${courses ? 'courses' : 'certificates'} add/edit/visibility/delete preserve other data and CV snapshots',
      (tester) async {
        await show(tester, courses);
        await add(tester);
        final url = find.widgetWithText(TextFormField, 'Website');
        await tester.ensureVisible(url);
        await tester.enterText(url, 'javascript:alert(1)');
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await _settle(tester);
        expect(find.text('Enter a valid http or https URL.'), findsOneWidget);
        await tester.enterText(url, 'https://example.test/credential');
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await _settle(tester);
        var profile = (await tester.runAsync<UserProfile?>(
          () => backend.loadProfile('owner'),
        ))!;
        final id = courses
            ? profile.courses.single.id
            : profile.certificates.single.id;
        expect(profile.projects.single.id, 'retained');
        final cv = (await tester.runAsync(
          () => backend.loadDocument('cv', 'owner'),
        ))!;
        expect(cv.profileSnapshot!.certificates, isEmpty);
        expect(cv.profileSnapshot!.courses, isEmpty);
        await tester.tap(find.byTooltip('Edit'));
        await _settle(tester);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Title'),
          'Updated Learning',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await _settle(tester);
        profile = (await tester.runAsync<UserProfile?>(
          () => backend.loadProfile('owner'),
        ))!;
        expect(
          courses ? profile.courses.single.id : profile.certificates.single.id,
          id,
        );
        await tester.tap(find.byType(Switch));
        await _settle(tester);
        profile = (await tester.runAsync<UserProfile?>(
          () => backend.loadProfile('owner'),
        ))!;
        expect(
          courses
              ? profile.courses.single.visible
              : profile.certificates.single.visible,
          isFalse,
        );
        await _settle(tester);
        await tester.tap(find.byTooltip('Delete'));
        await _settle(tester);
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await _settle(tester);
        expect(find.text('Updated Learning'), findsOneWidget);
        await tester.tap(find.byTooltip('Delete'));
        await _settle(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await _settle(tester);
        profile = (await tester.runAsync<UserProfile?>(
          () => backend.loadProfile('owner'),
        ))!;
        expect(
          courses ? profile.courses.length : profile.certificates.length,
          0,
        );
        expect(profile.details.fullName, 'Ada Lovelace');
        expect(profile.projects.single.id, 'retained');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await _settle(tester);
      },
    );
  }
  testWidgets(
    'wizard credentials update only the supplied draft and preserve entry order',
    (tester) async {
      const draft = UserProfile(
        id: 'owner',
        certificates: [
          CertificateEntry(id: 'first', name: 'First', visible: false),
          CertificateEntry(id: 'second', name: 'Second'),
        ],
      );
      UserProfile? saved;
      await show(
        tester,
        false,
        draft: draft,
        onSave: (value) async {
          saved = value;
        },
      );
      await tester.tap(find.byTooltip('Edit').first);
      await _settle(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Updated first',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await _settle(tester);
      expect(saved!.certificates.map((entry) => entry.id), ['first', 'second']);
      expect(saved!.certificates.first.name, 'Updated first');
      expect(saved!.certificates.first.visible, isFalse);
      expect(
        (await tester.runAsync(() => backend.loadProfile('owner')))!
            .certificates,
        isEmpty,
      );
      expect(
        (await tester.runAsync(() => backend.loadDocument('cv', 'owner')))!
            .profileSnapshot!
            .certificates,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await _settle(tester);
    },
  );
  testWidgets(
    'failed credential save retains entered values and can be retried',
    (tester) async {
      await show(tester, false);
      await add(tester);
      backend.failSave = true;
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await _settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'Title'))
            .controller!
            .text,
        'Professional Learning',
      );
      backend.failSave = false;
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await _settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        (await tester.runAsync<UserProfile?>(
          () => backend.loadProfile('owner'),
        ))!.certificates.single.name,
        'Professional Learning',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await _settle(tester);
    },
  );
}
