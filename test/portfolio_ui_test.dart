import 'package:cv_portfolio_maker/core/design/app_icons.dart';
import 'package:cv_portfolio_maker/features/settings/settings_screen.dart';
import 'package:cv_portfolio_maker/features/portfolio/portfolio_settings_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:cv_portfolio_maker/core/theme/app_theme.dart';

import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'dart:ui' show ImageByteFormat, PictureRecorder;

import 'package:flutter/services.dart';
import 'package:cv_portfolio_maker/core/domain/document_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cv_portfolio_maker/app/router.dart';

import 'package:cv_portfolio_maker/app/providers.dart';
import 'package:cv_portfolio_maker/app/session.dart';
import 'package:cv_portfolio_maker/core/config/app_config.dart';
import 'package:cv_portfolio_maker/core/design/templates.dart';
import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/data/auth/auth_service.dart';
import 'package:cv_portfolio_maker/data/local/local_repositories.dart';
import 'package:cv_portfolio_maker/data/local/local_store.dart';
import 'package:cv_portfolio_maker/data/repositories.dart';
import 'package:cv_portfolio_maker/features/portfolio/portfolio_builder_screen.dart';
import 'package:cv_portfolio_maker/features/cv_design/cv_design_settings_screen.dart';
import 'package:cv_portfolio_maker/features/portfolio/portfolio_controller.dart';
import 'package:cv_portfolio_maker/features/portfolio/portfolio_widgets.dart';

class _Session extends SessionController {
  @override
  Future<AuthUser?> build() async => const AuthUser(
    id: 'owner',
    email: 'ada@example.test',
    displayName: 'Ada Lovelace',
  );
}

class _Backend extends LocalBackend {
  _Backend(super.store);
  bool failSave = false;
  @override
  Future<CvDocument> saveDocument(CvDocument document) {
    if (failSave) throw StateError('Offline');
    return super.saveDocument(document);
  }
}

// A simulated remote read boundary for native plugin contract tests only.
class _RemoteReadBackend implements LocalBackendOrSupabase {
  _RemoteReadBackend(this.local);
  @override
  bool get isLocal => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  final LocalBackend local;
  @override
  Future<UserProfile?> loadProfile(String userId) => local.loadProfile(userId);
  @override
  Future<List<CvDocument>> listDocuments(String userId) =>
      local.listDocuments(userId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final sdkCache = File(Platform.resolvedExecutable).parent.parent.parent;
    final fonts = Directory('${sdkCache.path}/material_fonts');
    if (fonts.existsSync()) {
      for (final entry in {
        'Roboto': 'roboto-regular.ttf',
        'MaterialIcons': 'materialicons-regular.otf',
      }.entries) {
        final loader = FontLoader(entry.key)
          ..addFont(
            File('${fonts.path}/${entry.value}')
                .readAsBytes()
                .then(ByteData.sublistView),
          );
        await loader.load();
      }
    }
  });
  late Directory dir;
  late _Backend local;
  late ProviderContainer container;
  late CvDocument document;
  final screenshotKey = GlobalKey();
  GoRouter? activeRouter;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('portfolio_ui_test');
    local = _Backend(LocalStore.forDirectory(dir));
    document = CvDocument(
      id: 'portfolio',
      ownerId: 'owner',
      title: 'My Portfolio',
      type: DocumentType.portfolio,
      design: designForTemplate(
        'minimal',
        DocumentType.portfolio,
      ).copyWith(templateId: 'ocean'),
    );
    await local.saveDocument(document);
    await local.saveProfile(
      const UserProfile(
        id: 'owner',
        details: ProfileDetails(
          fullName: 'Ada Lovelace',
          professionalTitle: 'Software Engineer',
          summary: 'I build thoughtful tools that help people turn ideas into useful products.',
          email: 'ada@example.test',
          links: ['https://github.com/ada', 'javascript:alert(1)'],
        ),
        projects: [
          ProjectEntry(
            id: 'p1',
            title: 'Analytical Engine',
            description: 'A programmable engine for solving complex problems. Built with careful attention to accessibility and performance.',
            technologies: ['Dart', 'Flutter', 'Supabase'],
            demoUrl: 'https://demo.example.test',
            sourceUrl: 'https://github.com/ada/engine',
          ),
          ProjectEntry(id: 'p2', title: 'Hidden project', visible: false),
          ProjectEntry(
            id: 'p3',
            title: 'Notes',
            summary: 'A space for ideas',
            demoUrl: 'javascript:alert(1)',
          ),
        ],
        skills: [
          SkillEntry(
            id: 's1',
            name: 'Flutter',
            category: 'Mobile Development',
            proficiency: 4,
          ),
          SkillEntry(id: 's2', name: 'Invisible skill', visible: false),
        ],
        experiences: [
          ExperienceEntry(
            id: 'e1',
            position: 'Engineer',
            company: 'Engine Works',
          ),
        ],
        education: [
          EducationEntry(
            id: 'ed1',
            institution: 'University',
            qualification: 'Mathematics',
          ),
        ],
      ),
    );
    container = ProviderContainer(
      overrides: [
        backendProvider.overrideWithValue(LocalBackendOrSupabase.local(local)),
        sessionProvider2.overrideWith(_Session.new),
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
  });
  tearDown(() async {
    container.dispose();
    try {
      if (dir.existsSync()) await dir.delete(recursive: true);
    } on FileSystemException {
      /* A provider read can still be releasing a Windows file handle. */
    }
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      if (i >= 4 &&
          find.byType(LinearProgressIndicator).evaluate().isEmpty &&
          find.byType(CircularProgressIndicator).evaluate().isEmpty &&
          !tester
              .widgetList<PortfolioSettingsTab>(
                find.byType(PortfolioSettingsTab),
              )
              .any((settings) => settings.busy) &&
          !container.read(portfolioProvider).isLoading) {
        break;
      }
    }
    await tester.pump();
  }

  Future<void> mount(WidgetTester tester, {int tab = 0}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final signed = ValueNotifier(true);
    final router = buildRouter(
      isSignedIn: signed,
      currentUserId: () => 'owner',
    );
    activeRouter = router;
    addTearDown(router.dispose);
    addTearDown(signed.dispose);
    router.go('/portfolio');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
          builder: (context, child) =>
              RepaintBoundary(key: screenshotKey, child: child!),
        ),
      ),
    );
    await settle(tester);
    if (tab == 3) {
      unawaited(router.push<void>('/settings?section=portfolio'));
      await settle(tester);
    } else if (tab > 0) {
      await tester.tap(find.byType(NavigationDestination).at(tab));
      await settle(tester);
    }
  }

  Future<void> tab(WidgetTester tester, String label) async {
    final router = activeRouter!;
    if (label == 'Settings') {
      if (find.byType(SettingsScreen).evaluate().isEmpty) {
        unawaited(router.push<void>('/settings?section=portfolio'));
      }
    } else {
      if (find.byType(SettingsScreen).evaluate().isNotEmpty) {
        router.pop();
        await settle(tester);
      }
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
    }
    await settle(tester);
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    final boundary =
        screenshotKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ImageByteFormat.png);
      final file = File('build/portfolio-review/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'available portfolio pages retain state while global settings stay accessible',
    (tester) async {
      await mount(tester);
      expect(find.text('Software Engineer'), findsOneWidget);
      expect(
        find.textContaining('Ada Lovelace', findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(NavigationBar), findsOneWidget);
      await screenshot(tester, 'about');
      await tester.tap(find.text('View Work'));
      await settle(tester);
      expect(find.text('Analytical Engine'), findsOneWidget);
      expect(find.text('Hidden project'), findsNothing);
      expect(find.text('Live Demo'), findsOneWidget);
      expect(find.text('GitHub'), findsOneWidget);
      await screenshot(tester, 'projects');
      final scroll = find.descendant(
        of: find.byKey(const PageStorageKey('portfolio-projects')),
        matching: find.byType(Scrollable),
      );
      await tester.drag(scroll, const Offset(0, -250));
      await tester.pumpAndSettle();
      final offset = tester.state<ScrollableState>(scroll).position.pixels;
      await tab(tester, 'Skills');
      expect(find.text('Mobile Development'), findsOneWidget);
      expect(find.text('Expert'), findsOneWidget);
      expect(find.text('Invisible skill'), findsNothing);
      await screenshot(tester, 'skills');
      await tab(tester, 'Settings');
      expect(find.text('Color Theme'), findsOneWidget);
      await screenshot(tester, 'settings');
      await tab(tester, 'Projects');
      expect(tester.state<ScrollableState>(scroll).position.pixels, offset);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'theme and visibility save and survive reopening without deleting profile data',
    (tester) async {
      await mount(tester, tab: 3);
      await tester.tap(find.text('Forest'));
      await settle(tester);
      expect(
        container.read(portfolioProvider).value!.design.templateId,
        'forest',
      );
      final hide = find.byTooltip('Hide Projects');
      await tester.ensureVisible(hide);
      await settle(tester);
      await tester.tap(hide);
      await settle(tester);
      expect(
        container
            .read(portfolioProvider)
            .value!
            .design
            .sectionOf(SectionKind.projects)!
            .visible,
        isFalse,
      );
      await tab(tester, 'About');
      expect(
        find.widgetWithText(NavigationDestination, 'Projects'),
        findsNothing,
      );
      expect(find.text('Analytical Engine'), findsNothing);
      await tester.runAsync(() async {
        final saved = (await local.loadDocument(document.id, 'owner'))!;
        expect(saved.design.templateId, 'forest');
        expect(saved.design.sectionOf(SectionKind.projects)!.visible, isFalse);
        expect((await local.loadProfile('owner'))!.projects.length, 3);
      });
      await tester.pumpWidget(const SizedBox.shrink());
      container.invalidate(portfolioProvider);
      await mount(tester);
      expect(
        container.read(portfolioProvider).value!.design.templateId,
        'forest',
      );
      expect(
        find.widgetWithText(NavigationDestination, 'Projects'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profile invalidation refreshes data, narrow screens do not overflow',
    (tester) async {
      await mount(tester);
      await tester.runAsync(() async {
        final profile = (await local.loadProfile('owner'))!;
        await local.saveProfile(
          profile.copyWith(
            details: profile.details.copyWith(
              professionalTitle: 'Updated Engineer',
            ),
          ),
        );
      });
      container.invalidate(profileProvider('owner'));
      await settle(tester);
      expect(find.text('Updated Engineer'), findsOneWidget);
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpAndSettle();
      for (final label in ['Projects', 'Skills', 'Settings', 'About']) {
        await tab(tester, label);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'share on a local draft explains unavailable link and opens Settings',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('Share'));
      await settle(tester);
      expect(find.text('Color Theme'), findsOneWidget);
      expect(
        find.textContaining('configured backend and share host'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'reordering persists, failed saves roll back, passwords enforce access',
    () async {
      final loaded = (await container.read(portfolioProvider.future))!;
      final sections = [...loaded.design.sections.reversed];
      await container
          .read(portfolioProvider.notifier)
          .save(
            loaded.copyWith(design: loaded.design.copyWith(sections: sections)),
          );
      final saved = (await container.read(portfolioProvider.future))!;
      expect(saved.design.sections.first.id, sections.first.id);
      local.failSave = true;
      await expectLater(
        container
            .read(portfolioProvider.notifier)
            .save(
              saved.copyWith(design: saved.design.copyWith(templateId: 'rose')),
            ),
        throwsStateError,
      );
      expect(
        container.read(portfolioProvider).value!.design.templateId,
        saved.design.templateId,
      );
      local.failSave = false;
      await container.read(portfolioProvider.notifier).publish();
      final published = (await container.read(portfolioProvider.future))!;
      expect(await local.resolveBySlug(published.publicSlug!), isNotNull);
      await container.read(portfolioProvider.notifier).setPassword('secret');
      await container.read(portfolioProvider.future);
      await expectLater(
        local.resolveBySlug(published.publicSlug!),
        throwsA(isA<ShareNotFoundException>()),
      );
      expect(
        await local.resolveBySlugWithPassword(published.publicSlug!, 'wrong'),
        isNull,
      );
      expect(
        await local.resolveBySlugWithPassword(published.publicSlug!, 'secret'),
        isNotNull,
      );
      await container.read(portfolioProvider.notifier).setPassword(null);
      await container.read(portfolioProvider.future);
      expect(await local.resolveBySlug(published.publicSlug!), isNotNull);
      await container
          .read(portfolioProvider.notifier)
          .save(
            container.read(portfolioProvider).value!.copyWith(published: false),
          );
      await expectLater(
        local.resolveBySlug(published.publicSlug!),
        throwsA(isA<ShareNotFoundException>()),
      );
    },
  );

  test('outbound links reject malformed and unsafe schemes', () {
    for (final value in [
      null,
      '',
      'github.com/ada',
      'javascript:alert(1)',
      'file:///secret',
      'https://',
      'https://user:password@example.test',
    ]) {
      expect(portfolioWebUri(value), isNull);
    }
    expect(portfolioWebUri('https://github.com/ada')!.host, 'github.com');
  });

  test('share links require publication and a real backend host; protection stays on slug route', () {
    final published = document.copyWith(
      published: true,
      shareMode: ShareMode.publicLink,
      publicSlug: () => 'ada',
    );
    expect(
      portfolioShareUrl(document, 'https://portfolio.test', local: false),
      isNull,
    );
    expect(
      portfolioShareUrl(published, 'https://portfolio.test', local: true),
      isNull,
    );
    expect(
      portfolioShareUrl(
        published,
        'https://cv-portfolio.example.com',
        local: false,
      ),
      isNull,
    );
    expect(
      portfolioShareUrl(
        published.copyWith(accessPasswordHash: () => 'never-shared'),
        'https://portfolio.test',
        local: false,
      ),
      'https://portfolio.test/p/ada',
    );
  });

  testWidgets('missing and broken images render the local placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SizedBox(
            width: 100,
            height: 100,
            child: PortfolioImage(
              source: 'javascript:bad',
              ownerId: 'owner',
              fallback: Icon(AppIcons.webAsset),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    expect(find.byIcon(AppIcons.webAsset), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'main navigation opens one Portfolio bar and back returns to the dashboard',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final signedIn = ValueNotifier(true);
      final router = buildRouter(
        isSignedIn: signedIn,
        currentUserId: () => 'owner',
      );
      addTearDown(router.dispose);
      addTearDown(signedIn.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Portfolio'),
        ),
      );
      await settle(tester);
      expect(find.byType(PortfolioBuilderScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await settle(tester);
      expect(find.byType(PortfolioBuilderScreen), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      router.push('/portfolio/settings');
      await settle(tester);
      expect(find.text('Color Theme'), findsOneWidget);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(signedIn.value, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Preview CV opens design settings directly and back returns to dashboard',
    (tester) async {
      await tester.runAsync(
        () => local.saveDocument(
          CvDocument(
            id: 'cv',
            ownerId: 'owner',
            title: 'My CV',
            design: designForTemplate('minimal', DocumentType.cv),
          ),
        ),
      );
      SharedPreferences.setMockInitialValues({});
      final signedIn = ValueNotifier(true);
      final router = buildRouter(
        isSignedIn: signedIn,
        currentUserId: () => 'owner',
      );
      addTearDown(router.dispose);
      addTearDown(signedIn.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await settle(tester);
      await tester.ensureVisible(find.byTooltip('Preview CV').first);
      await settle(tester);
      await tester.tap(find.byTooltip('Preview CV').first);
      await settle(tester);
      expect(find.byType(CvDesignSettingsScreen), findsOneWidget);
      expect(find.text('CV Design Settings'), findsOneWidget);
      expect(find.byTooltip('Export PDF / Word'), findsOneWidget);
      expect(find.text('Document layout & sections'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await settle(tester);
      expect(find.byType(CvDesignSettingsScreen), findsNothing);
      expect(find.byTooltip('Preview CV'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'first open creates one reusable draft even after provider reload',
    () async {
      await local.deleteDocument(document.id, 'owner');
      final first = (await container.read(portfolioProvider.future))!;
      container.invalidate(portfolioProvider);
      final reopened = (await container.read(portfolioProvider.future))!;
      expect(reopened.id, first.id);
      expect((await local.listDocuments('owner')).length, 1);
    },
  );

  testWidgets(
    'empty projects and skills stay out of navigation while editing remains available',
    (tester) async {
      await tester.runAsync(
        () => local.saveProfile(
          const UserProfile(
            id: 'owner',
            details: ProfileDetails(fullName: 'Ada'),
          ),
        ),
      );
      await mount(tester);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('View Work'), findsNothing);
      expect(find.text('Edit profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('uploaded local project images resolve from storage paths', (
    tester,
  ) async {
    final media = (await tester.runAsync(() async {
      final recorder = PictureRecorder();
      Canvas(
        recorder,
      ).drawRect(const Rect.fromLTWH(0, 0, 2, 2), Paint()..color = Colors.blue);
      final picture = recorder.endRecording();
      final image = await picture.toImage(2, 2);
      final bytes = (await image.toByteData(format: ImageByteFormat.png))!
          .buffer
          .asUint8List();
      image.dispose();
      picture.dispose();
      return local.uploadBytes(
        userId: 'owner',
        fileName: 'cover.png',
        bytes: bytes,
        contentType: 'image/png',
      );
    }))!;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: SizedBox(
            width: 100,
            height: 100,
            child: PortfolioImage(
              source: media.storagePath,
              ownerId: 'owner',
              fallback: const Icon(AppIcons.webAsset),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(AppIcons.webAsset), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'native share and clipboard receive only the saved protected slug URL',
    (tester) async {
      await tester.runAsync(
        () => local.saveDocument(
          document.copyWith(
            published: true,
            shareMode: ShareMode.publicLink,
            publicSlug: () => 'ada',
            accessPasswordHash: () => 'private-hash',
          ),
        ),
      );
      container.dispose();
      container = ProviderContainer(
        overrides: [
          backendProvider.overrideWithValue(_RemoteReadBackend(local)),
          sessionProvider2.overrideWith(_Session.new),
          appConfigProvider.overrideWithValue(
            const AppConfig(
              supabaseUrl: 'https://backend.example.test',
              supabaseAnonKey: 'public-test-key',
              googleWebClientId: '',
              googleIosClientId: '',
              shareBaseUrl: 'https://portfolio.test',
              backendMode: BackendMode.supabase,
            ),
          ),
        ],
      );
      final calls = <MethodCall>[];
      final clipboard = <String>[];
      final copied = Completer<void>();
      const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(shareChannel, (call) async {
        calls.add(call);
        return 'app';
      });
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard.add((call.arguments as Map)['text'] as String);
          await copied.future;
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(shareChannel, null);
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      });
      await mount(tester);
      await tester.tap(find.text('Share'));
      await settle(tester);
      expect(calls.single.arguments['text'], 'https://portfolio.test/p/ada');
      expect(
        calls.single.arguments.toString(),
        isNot(contains('private-hash')),
      );
      await tab(tester, 'Settings');
      await tester.ensureVisible(find.text('Copy'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Copy'));
      await tester.pump();
      expect(find.text('Portfolio link copied'), findsNothing);
      copied.complete();
      await settle(tester);
      expect(clipboard.single, 'https://portfolio.test/p/ada');
      expect(find.text('Portfolio link copied'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
