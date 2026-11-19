import 'package:cv_portfolio_maker/core/design/app_icons.dart';

import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cv_portfolio_maker/app/providers.dart';
import 'package:cv_portfolio_maker/app/router.dart';
import 'package:cv_portfolio_maker/app/session.dart';
import 'package:cv_portfolio_maker/core/config/app_config.dart';
import 'package:cv_portfolio_maker/core/design/templates.dart';
import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/theme/app_theme.dart';
import 'package:cv_portfolio_maker/data/auth/auth_service.dart';
import 'package:cv_portfolio_maker/data/repositories.dart';
import 'package:cv_portfolio_maker/features/about/about_app_screen.dart';
import 'package:cv_portfolio_maker/core/branding/app_branding.dart';
import 'package:cv_portfolio_maker/data/local/local_repositories.dart';
import 'package:cv_portfolio_maker/data/local/local_store.dart';
import 'package:cv_portfolio_maker/features/cv_builder/cv_builder_wizard_screen.dart';
import 'package:cv_portfolio_maker/features/editor/document_editor_screen.dart';
import 'package:cv_portfolio_maker/features/cv_design/cv_design_settings_screen.dart';
import 'package:cv_portfolio_maker/features/portfolio/portfolio_builder_screen.dart';
import 'package:cv_portfolio_maker/features/portfolio/public_portfolio_view.dart';
import 'package:cv_portfolio_maker/features/profile/profile_screen.dart';
import 'package:cv_portfolio_maker/features/settings/credentials_screen.dart';
import 'package:cv_portfolio_maker/main.dart';

const _user = AuthUser(id: 'owner', email: 'ada@example.test');
const _original = UserProfile(
  id: 'owner',
  details: ProfileDetails(fullName: 'Ada Lovelace'),
);

class _Auth extends Fake implements AuthService {
  AuthUser? user = _user;
  final events = StreamController<AuthUser?>.broadcast();
  @override
  AuthUser? get currentUser => user;
  @override
  Future<AuthUser?> restoreSession() async => currentUser;
  @override
  Stream<AuthUser?> get authStateChanges => events.stream;
  @override
  bool get isRecoveringPassword => false;
}

class _Backend extends LocalBackend {
  _Backend(super.store);
  bool failDocumentRead = false;
  bool failProfileSave = false;
  @override
  Future<CvDocument?> loadDocument(String id, String owner) {
    if (failDocumentRead) throw StateError('Network unavailable');
    return super.loadDocument(id, owner);
  }

  @override
  Future<UserProfile> saveProfile(UserProfile profile) {
    if (failProfileSave) {
      failProfileSave = false;
      throw StateError('Profile write unavailable');
    }
    return super.saveProfile(profile);
  }
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 40));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
}

void main() {
  late Directory directory;
  late _Backend backend;
  late ProviderContainer container;
  late _Auth auth;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = Directory.systemTemp.createTempSync('cv_flow_');
    backend = _Backend(LocalStore.forDirectory(directory));
    await backend.saveProfile(_original);
    for (final (id, name) in [
      ('first', 'Ada Lovelace'),
      ('second', 'Grace Hopper'),
    ]) {
      await backend.saveDocument(
        CvDocument(
          id: id,
          ownerId: 'owner',
          title: name,
          profileSnapshot: _original.copyWith(
            details: ProfileDetails(fullName: name),
          ),
          design: designForTemplate('minimal', DocumentType.cv),
        ),
      );
    }
    auth = _Auth();
    container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        backendProvider.overrideWithValue(
          LocalBackendOrSupabase.local(backend),
        ),
        appConfigProvider.overrideWithValue(
          const AppConfig(
            supabaseUrl: '',
            supabaseAnonKey: '',
            googleWebClientId: '',
            googleIosClientId: '',
            shareBaseUrl: 'https://portfolio.example.test',
          ),
        ),
      ],
    );
    await container.read(sessionProvider2.future);
  });
  tearDown(() async {
    container.dispose();
    await auth.events.close();
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  testWidgets('a direct account switch rebuilds retained dashboard forms', (
    tester,
  ) async {
    await tester.runAsync(
      () => backend.saveProfile(
        const UserProfile(
          id: 'other',
          details: ProfileDetails(fullName: 'Grace Hopper'),
        ),
      ),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CVPortfolioStudio(),
      ),
    );
    await settle(tester);
    await tester.tap(find.byType(NavigationDestination).at(1));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name'),
      'Private Owner Draft',
    );
    auth.user = const AuthUser(id: 'other', email: 'other@example.test');
    auth.events.add(auth.user);
    await settle(tester);
    expect(container.read(sessionProvider2).value?.id, 'other');
    expect(find.text('Private Owner Draft'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets(
    'login resumes the requested document and route changes reload its content',
    (tester) async {
      final signed = ValueNotifier(false);
      final router = buildRouter(
        isSignedIn: signed,
        currentUserId: () => 'owner',
      );
      addTearDown(router.dispose);
      addTearDown(signed.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      router.go('/wizard/first');
      await settle(tester);
      expect(router.routeInformationProvider.value.uri.path, '/login');
      expect(
        router.routeInformationProvider.value.uri.queryParameters['from'],
        '/wizard/first',
      );
      signed.value = true;
      await settle(tester);
      expect(router.routeInformationProvider.value.uri.path, '/wizard/first');
      expect(find.text('Ada Lovelace'), findsWidgets);
      router.go('/wizard/second');
      await settle(tester);
      expect(find.text('Grace Hopper'), findsWidgets);
      expect(find.text('Ada Lovelace'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    },
  );

  testWidgets('document read failure offers retry and loads after recovery', (
    tester,
  ) async {
    backend.failDocumentRead = true;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: DocumentEditorScreen(documentId: 'first'),
        ),
      ),
    );
    await settle(tester);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    backend.failDocumentRead = false;
    await tester.tap(find.text('Retry'));
    await settle(tester);
    expect(find.text('Retry'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets(
    'duplicating a saved CV preserves its snapshot and selections while creating a private draft',
    (tester) async {
      final source =
          (await tester.runAsync(
            () => backend.loadDocument('second', 'owner'),
          ))!.copyWith(
            published: true,
            shareMode: ShareMode.publicLink,
            publicSlug: () => 'shared-cv',
            accessPasswordHash: () => 'existing-hash',
            includedProjectIds: () => ['selected-project'],
            allowPdfDownload: false,
          );
      await tester.runAsync(() => backend.saveDocument(source));
      final signed = ValueNotifier(true);
      final router = buildRouter(
        isSignedIn: signed,
        currentUserId: () => 'owner',
      );
      addTearDown(router.dispose);
      addTearDown(signed.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await settle(tester);
      final card = find
          .ancestor(of: find.text('Grace Hopper'), matching: find.byType(Card))
          .first;
      final menu = find.descendant(
        of: card,
        matching: find.byTooltip('More actions'),
      );
      await tester.ensureVisible(menu);
      await settle(tester);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate'));
      await settle(tester);
      final docs = await tester.runAsync(() => backend.listDocuments('owner'));
      final copy = docs!.singleWhere((d) => d.title == 'Grace Hopper (copy)');
      expect(copy.profileSnapshot!.details.fullName, 'Grace Hopper');
      expect(copy.includedProjectIds, ['selected-project']);
      expect(copy.allowPdfDownload, isFalse);
      expect(copy.published, isFalse);
      expect(copy.shareMode, ShareMode.privateDraft);
      expect(copy.publicSlug, isNull);
      expect(copy.accessPasswordHash, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    },
  );

  testWidgets(
    'saving contact details preserves projects added while the form was open',
    (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await settle(tester);
      await tester.runAsync(
        () => backend.saveProfile(
          _original.copyWith(
            projects: [const ProjectEntry(id: 'new', title: 'New project')],
          ),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name'),
        'Katherine Johnson',
      );
      await tester.tap(find.byTooltip('Save'));
      await settle(tester);
      final saved = await tester.runAsync(() => backend.loadProfile('owner'));
      expect(saved!.details.fullName, 'Katherine Johnson');
      expect(saved.projects.single.id, 'new');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    },
  );

  testWidgets(
    'CV layout expansion and scroll offsets survive preview round trips independently',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const DocumentEditorScreen(documentId: 'first'),
          ),
        ),
      );
      await settle(tester);
      expect(find.byType(CvDesignSettingsScreen), findsOneWidget);
      final layout = find.widgetWithText(
        ExpansionTile,
        'Document layout & sections',
      );
      await tester.ensureVisible(layout);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Document layout & sections'));
      await tester.pumpAndSettle();
      final controls = find
          .ancestor(of: layout, matching: find.byType(SingleChildScrollView))
          .first;
      final scroll = find
          .descendant(of: controls, matching: find.byType(Scrollable))
          .first;
      final before = tester.state<ScrollableState>(scroll).position.pixels;
      expect(before, greaterThan(0));
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byTooltip('Preview CV'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Customize CV'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.state<ScrollableState>(scroll).position.pixels,
          closeTo(before, 1),
        );
        final tileContext = tester.element(
          find.text('Document layout & sections'),
        );
        expect(ExpansibleController.of(tileContext).isExpanded, isTrue);
      }
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    },
  );

  testWidgets('changing a public slug replaces the previous visitor content', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await backend.saveProfile(
        const UserProfile(
          id: 'other',
          details: ProfileDetails(fullName: 'Grace Hopper'),
        ),
      );
      for (final (id, owner) in [
        ('public-first', 'owner'),
        ('public-second', 'other'),
      ]) {
        await backend.saveDocument(
          CvDocument(
            id: id,
            ownerId: owner,
            title: id,
            type: DocumentType.portfolio,
            published: true,
            shareMode: ShareMode.publicLink,
            publicSlug: id,
            design: designForTemplate('minimal', DocumentType.portfolio),
          ),
        );
        await backend.saveShare(
          DocumentShare(
            id: id,
            documentId: id,
            slug: id,
            mode: ShareMode.publicLink,
          ),
        );
      }
    });
    final signed = ValueNotifier(false);
    final router = buildRouter(isSignedIn: signed, currentUserId: () => '');
    addTearDown(router.dispose);
    addTearDown(signed.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.go('/p/public-first');
    await settle(tester);
    await settle(tester);
    expect(
      tester
          .widget<PublicPortfolioView>(find.byType(PublicPortfolioView))
          .profile
          .details
          .fullName,
      'Ada Lovelace',
    );
    expect(find.byTooltip('Download PDF'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('portfolio-app-about')));
    await settle(tester);
    expect(find.byType(AboutAppScreen), findsOneWidget);
    expect(find.text(kDeveloperName), findsOneWidget);
    expect(
      tester
          .widget<AboutAppScreen>(find.byType(AboutAppScreen))
          .portfolioThemeId,
      'ocean',
    );
    router.pop();
    await settle(tester);
    expect(find.byType(PublicPortfolioView), findsOneWidget);
    expect(
      tester
          .widget<PublicPortfolioView>(find.byType(PublicPortfolioView))
          .profile
          .details
          .fullName,
      'Ada Lovelace',
    );
    router.go('/p/public-second');
    await settle(tester);
    await settle(tester);
    expect(
      tester
          .widget<PublicPortfolioView>(find.byType(PublicPortfolioView))
          .profile
          .details
          .fullName,
      'Grace Hopper',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  });

  testWidgets(
    'reopening after a partial generation failure retries the same CV and updates portfolio content',
    (tester) async {
      final signed = ValueNotifier(true);
      final router = buildRouter(
        isSignedIn: signed,
        currentUserId: () => 'owner',
      );
      addTearDown(router.dispose);
      addTearDown(signed.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      router.go('/wizard/first');
      await settle(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name'),
        'Katherine Johnson',
      );
      await tester.tap(find.text('Skip'));
      await settle(tester);
      backend.failProfileSave = true;
      await tester.tap(find.text('Generate CV'));
      await settle(tester);
      for (var attempt = 0; attempt < 6 && backend.failProfileSave; attempt++) {
        await settle(tester);
      }
      expect(
        backend.failProfileSave,
        isFalse,
        reason: 'Wait for the simulated profile failure before reopening',
      );
      await settle(tester);
      expect(find.byType(CvBuilderWizardScreen), findsOneWidget);
      final before = await tester.runAsync(() => backend.loadProfile('owner'));
      expect(before!.details.fullName, 'Ada Lovelace');
      final committed = await tester.runAsync(
        () => backend.loadDocument('first', 'owner'),
      );
      expect(committed!.profileSnapshot!.details.fullName, 'Katherine Johnson');
      router.go('/settings');
      await settle(tester);
      router.go('/wizard/first');
      await settle(tester);
      ScaffoldMessenger.of(tester.element(find.byType(CvBuilderWizardScreen)))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate CV'));
      await settle(tester);
      for (
        var attempt = 0;
        attempt < 6 && find.byType(DocumentEditorScreen).evaluate().isEmpty;
        attempt++
      ) {
        await settle(tester);
      }
      final after = await tester.runAsync(() => backend.loadProfile('owner'));
      expect(after!.details.fullName, 'Katherine Johnson');
      final docs = await tester.runAsync(() => backend.listDocuments('owner'));
      expect(docs!.where((d) => d.type == DocumentType.cv).length, 2);
      for (
        var attempt = 0;
        attempt < 4 && find.byType(DocumentEditorScreen).evaluate().isEmpty;
        attempt++
      ) {
        await settle(tester);
      }
      expect(find.byType(DocumentEditorScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    },
  );

  testWidgets(
    'custom entry draft generates an independent CV and joins the live portfolio profile',
    (tester) async {
      const extra = CustomSection(
        id: 'extra',
        title: 'Professional development',
        entries: [
          CustomEntry(
            id: 'credential',
            title: 'Cloud certificate',
            issuer: 'Institute',
            dateRange: DateRange(startIso: '2024-01-01', isCurrent: true),
            credentialId: 'C-42',
            url: 'https://example.test/verify',
          ),
        ],
      );
      await tester.runAsync(
        () => backend.saveCvDraft(
          'owner',
          'first',
          CvBuilderDraft(
            profile: _original.copyWith(customSections: [extra]),
            step: 7,
          ),
        ),
      );
      final signed = ValueNotifier(true);
      final router = buildRouter(
        isSignedIn: signed,
        currentUserId: () => 'owner',
      );
      addTearDown(router.dispose);
      addTearDown(signed.dispose);
      router.go('/wizard/first');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await settle(tester);
      expect(find.text('Professional development'), findsOneWidget);
      await tester.tap(find.text('Generate CV'));
      for (
        var i = 0;
        i < 8 && find.byType(DocumentEditorScreen).evaluate().isEmpty;
        i++
      ) {
        await settle(tester);
      }
      final saved = (await tester.runAsync(
        () => backend.loadDocument('first', 'owner'),
      ))!;
      expect(
        saved
            .profileSnapshot!
            .customSections
            .single
            .entries
            .single
            .credentialId,
        'C-42',
      );
      expect(
        saved.design.sections.any(
          (section) => section.customSectionId == 'extra',
        ),
        isTrue,
      );
      final live = (await tester.runAsync(() => backend.loadProfile('owner')))!;
      expect(live.customSections.single.title, 'Professional development');
      final other = (await tester.runAsync(
        () => backend.loadDocument('second', 'owner'),
      ))!;
      expect(other.profileSnapshot!.customSections, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    },
  );

  testWidgets(
    'portfolio settings deep links and global credential shortcuts stay reachable',
    (tester) async {
      final signed = ValueNotifier(true);
      final router = buildRouter(
        isSignedIn: signed,
        currentUserId: () => 'owner',
      );
      addTearDown(router.dispose);
      addTearDown(signed.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      router.go('/portfolio');
      await settle(tester);
      router.go('/portfolio/settings');
      await settle(tester);
      expect(router.routeInformationProvider.value.uri.path, '/settings');
      expect(
        router.routeInformationProvider.value.uri.queryParameters['section'],
        'portfolio',
      );
      expect(find.byType(ExpansionTile), findsWidgets);
      expect(find.text('Color Theme'), findsOneWidget);
      router.go('/settings');
      await settle(tester);
      for (final icon in [AppIcons.certificate, AppIcons.courses]) {
        final shortcut = find.widgetWithIcon(ActionChip, icon);
        await tester.ensureVisible(shortcut);
        await settle(tester);
        await tester.tap(shortcut);
        await settle(tester);
        if (icon == AppIcons.customize) {
          expect(
            tester
                .widget<PortfolioBuilderScreen>(
                  find.byType(PortfolioBuilderScreen),
                )
                .settingsOnly,
            isTrue,
          );
        } else {
          expect(
            tester
                .widget<CredentialsScreen>(find.byType(CredentialsScreen))
                .courses,
            icon == AppIcons.courses,
          );
        }
        router.pop();
        await settle(tester);
        expect(router.routeInformationProvider.value.uri.path, '/settings');
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    },
  );
}
