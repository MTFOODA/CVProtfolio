import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cv_portfolio_maker/features/dashboard/dashboard_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cv_portfolio_maker/main.dart';
import 'package:cv_portfolio_maker/app/providers.dart';
import 'package:cv_portfolio_maker/app/router.dart';
import 'package:cv_portfolio_maker/app/session.dart';
import 'package:cv_portfolio_maker/core/config/app_config.dart';
import 'package:cv_portfolio_maker/core/design/portfolio_themes.dart';
import 'package:cv_portfolio_maker/core/design/skill_icons.dart';
import 'package:cv_portfolio_maker/core/design/cv_design_options.dart';
import 'package:cv_portfolio_maker/core/design/templates.dart';
import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/l10n/app_strings.dart';
import 'package:cv_portfolio_maker/core/l10n/strings_ar.dart';
import 'package:cv_portfolio_maker/core/l10n/strings_en.dart';
import 'package:cv_portfolio_maker/core/theme/app_theme.dart';
import 'package:cv_portfolio_maker/core/theme/app_tokens.dart';
import 'package:cv_portfolio_maker/core/widgets/app_surfaces.dart';
import 'package:cv_portfolio_maker/data/auth/auth_service.dart';
import 'package:cv_portfolio_maker/data/local/local_repositories.dart';
import 'package:cv_portfolio_maker/data/local/local_store.dart';
import 'package:cv_portfolio_maker/data/repositories.dart';
import 'package:cv_portfolio_maker/features/cv_builder/project_entry_dialog.dart';
import 'package:cv_portfolio_maker/features/cv_builder/cv_builder_wizard_screen.dart';
import 'package:cv_portfolio_maker/features/cv_design/cv_design_settings_screen.dart';
import 'package:cv_portfolio_maker/features/portfolio/portfolio_builder_screen.dart';
import 'package:cv_portfolio_maker/features/portfolio/portfolio_contacts.dart';
import 'package:cv_portfolio_maker/features/portfolio/portfolio_settings_screen.dart';
import 'package:cv_portfolio_maker/features/portfolio/portfolio_theme.dart';
import 'package:cv_portfolio_maker/features/portfolio/public_portfolio_view.dart';
import 'package:cv_portfolio_maker/features/profile/profile_screen.dart';
import 'package:cv_portfolio_maker/features/settings/settings_screen.dart';
import 'package:cv_portfolio_maker/features/templates/templates_screen.dart';

class _Auth implements AuthService {
  @override
  bool get isRecoveringPassword => false;
  @override
  AuthUser? get currentUser =>
      const AuthUser(id: 'owner', email: 'ada@example.test');
  @override
  Future<AuthUser?> restoreSession() async => currentUser;
  @override
  Stream<AuthUser?> get authStateChanges => Stream.value(currentUser);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _profile = UserProfile(
  id: 'owner',
  details: ProfileDetails(
    fullName: 'Ada Lovelace',
    professionalTitle: 'Software Engineer',
    email: 'ada@example.test',
    phone: '+20 101 234 5678',
    location: 'Giza, Egypt',
    summary: 'I build useful tools.',
    links: ['https://github.com/ada', 'https://linkedin.com/in/ada'],
  ),
  projects: [
    ProjectEntry(
      id: 'p',
      title: 'Engine',
      description: 'A useful project.',
      sourceUrl: 'https://github.com/ada/engine',
      technologies: ['Dart', 'Flutter'],
    ),
  ],
  skills: [
    SkillEntry(id: 's', name: 'Flutter', iconId: 'flutter', proficiency: 4),
  ],
  experiences: [
    ExperienceEntry(id: 'e', position: 'Engineer', company: 'Engine Works'),
  ],
  certificates: [
    CertificateEntry(id: 'certificate', name: 'Cloud certificate'),
  ],
  courses: [CourseEntry(id: 'course', name: 'Cloud course')],
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 80));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
  }
  await tester.pump();
}

Future<void> _captureAudit(
  WidgetTester tester,
  GlobalKey key,
  String name,
) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ImageByteFormat.png);
    final file = File('build/modernization-audit/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final sdkCache = File(Platform.resolvedExecutable).parent.parent.parent;
    final material = File(
      '${sdkCache.path}/material_fonts/materialicons-regular.otf',
    );
    if (material.existsSync()) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(material.readAsBytes().then(ByteData.sublistView))).load();
    }
    for (final entry in {
      'inter': 'Inter-Regular.ttf',
      'tajawal': 'Tajawal-Regular.ttf',
      'Roboto': 'Roboto-Regular.ttf',
      'notoNaskhArabic': 'NotoNaskhArabic-Regular.ttf',
      'CvBrandIcons': 'ContactBrands-Regular.ttf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load('assets/google_fonts/${entry.value}'))).load();
    }
  });
  late Directory dir;
  late LocalBackend local;
  late ProviderContainer container;
  late CvDocument portfolio;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('app_ui_audit_');
    local = LocalBackend(LocalStore.forDirectory(dir));
    await local.saveProfile(_profile);
    await local.saveDocument(
      CvDocument(
        id: 'cv',
        ownerId: 'owner',
        title: 'Saved CV',
        design: designForTemplate('minimal', DocumentType.cv),
      ),
    );
    portfolio = CvDocument(
      id: 'portfolio',
      ownerId: 'owner',
      title: 'My Portfolio',
      type: DocumentType.portfolio,
      published: true,
      publicSlug: 'ada',
      shareMode: ShareMode.publicLink,
      design: designForTemplate(
        'minimal',
        DocumentType.portfolio,
      ).copyWith(templateId: 'forest'),
    );
    await local.saveDocument(portfolio);
    await local.saveShare(
      const DocumentShare(
        id: 'share',
        documentId: 'portfolio',
        mode: ShareMode.publicLink,
        slug: 'ada',
      ),
    );
    container = ProviderContainer(
      overrides: [
        backendProvider.overrideWithValue(LocalBackendOrSupabase.local(local)),
        authServiceProvider.overrideWithValue(_Auth()),
        appConfigProvider.overrideWithValue(
          const AppConfig(
            supabaseUrl: '',
            supabaseAnonKey: '',
            googleWebClientId: '',
            googleIosClientId: '',
            shareBaseUrl: 'https://cv.example.test',
          ),
        ),
      ],
    );
    await container.read(sessionProvider2.future);
  });
  tearDown(() async {
    container.dispose();
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  test(
    'English and Arabic dictionaries have matching keys and placeholders',
    () {
      expect(arStrings.keys.toSet(), enStrings.keys.toSet());
      for (final key in enStrings.keys) {
        final placeholders = RegExp(r'\{[^}]+\}');
        expect(
          placeholders.allMatches(arStrings[key]!).map((m) => m[0]).toSet(),
          placeholders.allMatches(enStrings[key]!).map((m) => m[0]).toSet(),
          reason: key,
        );
      }
    },
  );

  test('active text and icons have accessible contrast in both app and Portfolio themes', () {
    double contrast(Color a, Color b) {
      final aa = a.computeLuminance();
      final bb = b.computeLuminance();
      return ((aa > bb ? aa : bb) + .05) / ((aa > bb ? bb : aa) + .05);
    }

    for (final base in [AppTheme.light(), AppTheme.dark()]) {
      for (final color in AppGradients.canvas(base.brightness).colors) {
        final decorated = Color.alphaBlend(
          AppPalette.silver.withValues(alpha: .035),
          Color.alphaBlend(
            AppPalette.ice.withValues(
              alpha: base.brightness == Brightness.dark ? .045 : .14,
            ),
            color,
          ),
        );
        for (final foreground in [
          base.colorScheme.onSurface,
          base.colorScheme.onSurfaceVariant,
          base.colorScheme.primary,
        ]) {
          expect(
            contrast(foreground, decorated),
            greaterThanOrEqualTo(4.5),
            reason: 'Decorated ${base.brightness} canvas: $color',
          );
        }
      }
      for (final color in AppGradients.hero(base.brightness).colors) {
        final decorated = Color.alphaBlend(
          AppPalette.ice.withValues(
            alpha: base.brightness == Brightness.dark ? .045 : .14,
          ),
          color,
        );
        expect(
          contrast(base.colorScheme.onSurface, decorated),
          greaterThanOrEqualTo(4.5),
          reason: 'Hero foreground: $color',
        );
      }
      for (final theme in [
        base,
        ...portfolioThemes.map((p) => portfolioUiTheme(base, p)),
      ]) {
        final c = theme.colorScheme;
        for (final pair in [
          (c.onPrimaryContainer, c.primaryContainer),
          (c.onSurface, c.surface),
          (c.onSurfaceVariant, c.surface),
          (c.primary, c.surface),
          (c.onPrimary, c.primary),
          (c.error, c.surface),
          (c.onSecondary, c.secondary),
        ]) {
          expect(
            contrast(pair.$1, pair.$2),
            greaterThanOrEqualTo(4.5),
            reason: '${theme.brightness}: $pair',
          );
        }
      }
    }
  });

  test('UI copy and presentation choices resolve into Arabic instead of falling back to English', () {
    final technical = {
      ...skillIcons
          .where((option) => !option.localized)
          .map((option) => option.label),
      'GitHub',
      'LinkedIn',
      'WhatsApp',
      'Flutter',
      'DevOps',
      'English',
      'mtfooda',
      'A1',
      'A2',
      'B1',
      'B2',
      'C1',
      'C2',
    };
    final copies = <String>{
      ...skillIcons.map((option) => option.label),
      ...CvDesignValue.values.map((control) => control.label),
      ...builtinTemplates.expand(
        (template) => [template.name, template.description],
      ),
    };
    final pattern = RegExp(
      r'''(?:UiText|DesignLabel|_Label|\.ui)\(\s*(?:'((?:\\.|[^'\\])*)'|"((?:\\.|[^"\\])*)")''',
    );
    for (final root in ['lib/features', 'lib/core/widgets']) {
      for (final file
          in Directory(root)
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))) {
        for (final match in pattern.allMatches(file.readAsStringSync())) {
          final copy = (match[1] ?? match[2]!).replaceAll(r"\'", "'");
          if (!copy.contains(r'$') && RegExp('[a-zA-Z]').hasMatch(copy)) {
            copies.add(copy);
          }
        }
      }
    }
    final missing = copies
        .where(
          (copy) =>
              !technical.contains(copy) && AppStrings.ui('ar', copy) == copy,
        )
        .toList();
    expect(missing, isEmpty);
  });

  for (final language in ['en', 'ar']) {
    for (final dark in [false, true]) {
      for (final viewport in [
        const Size(360, 800),
        const Size(412, 915),
        const Size(1440, 900),
      ]) {
        testWidgets(
          'screen walk ${viewport.width.toInt()} $language ${dark ? 'dark' : 'light'} covers every feature and visitor tabs',
          (tester) async {
            tester.view.physicalSize = viewport;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final signedIn = ValueNotifier(true);
            final router = buildRouter(
              isSignedIn: signedIn,
              currentUserId: () => 'owner',
            );
            addTearDown(router.dispose);
            addTearDown(signedIn.dispose);
            final boundaryKey = GlobalKey();
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: MaterialApp.router(
                    builder: (context, child) => AppBackdrop(child: child!),
                    debugShowCheckedModeBanner: false,
                    routerConfig: router,
                    locale: Locale(language),
                    theme: dark ? AppTheme.dark() : AppTheme.light(),
                    supportedLocales: supportedLocales,
                    localizationsDelegates: const [
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                      GlobalCupertinoLocalizations.delegate,
                    ],
                  ),
                ),
              ),
            );
            await _settle(tester);
            for (final entry in <(String, Type)>[
              ('/', DashboardScreen),
              ('/profile', ProfileScreen),
              ('/templates', TemplatesScreen),
              ('/doc/cv', CvDesignSettingsScreen),
              ('/wizard/cv', CvBuilderWizardScreen),
              ('/portfolio', PortfolioBuilderScreen),
              ('/settings', SettingsScreen),
              ('/p/ada', PublicPortfolioView),
            ]) {
              router.go(entry.$1);
              await _settle(tester);
              // The public local resolver enumerates files and records a view.
              // Windows directory streams can require more event-loop turns
              // than a form read, especially after wizard draft writes.
              if (entry.$2 == PublicPortfolioView) {
                for (
                  var attempt = 0;
                  attempt < 3 && find.byType(entry.$2).evaluate().isEmpty;
                  attempt++
                ) {
                  await _settle(tester);
                }
              }
              expect(
                find.byType(entry.$2),
                findsOneWidget,
                reason:
                    '${entry.$1}: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList()}',
              );
              final element = find.byType(entry.$2).evaluate().single;
              expect(
                Directionality.of(element),
                language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
              );
              final scaffold = find
                  .descendant(
                    of: find.byType(entry.$2),
                    matching: find.byType(Scaffold),
                  )
                  .first;
              expect(
                Theme.of(tester.element(scaffold)).brightness,
                dark ? Brightness.dark : Brightness.light,
              );
              expect(tester.takeException(), isNull, reason: entry.$1);
              await _captureAudit(
                tester,
                boundaryKey,
                '${viewport.width.toInt()}-$language-${dark ? 'dark' : 'light'}-${entry.$1.replaceAll('/', '_')}',
              );
              if (entry.$2 == PortfolioBuilderScreen ||
                  entry.$2 == PublicPortfolioView) {
                final bar = find.byType(NavigationBar).last;
                expect(
                  tester.widget<NavigationBar>(bar).destinations.length,
                  5,
                );
                for (final label in [
                  'Projects',
                  'Skills',
                  'Experience',
                  'Credentials',
                ]) {
                  await tester.tap(
                    find.descendant(
                      of: bar,
                      matching: find.text(switch (label) {
                        'Experience' => AppStrings.t(
                          language,
                          'portfolioExperience',
                        ),
                        'Credentials' => AppStrings.t(
                          language,
                          'portfolioCredentials',
                        ),
                        _ => AppStrings.ui(language, label),
                      }),
                    ),
                  );
                  await _settle(tester);
                  expect(
                    tester.takeException(),
                    isNull,
                    reason: '${entry.$1}/$label',
                  );
                  if (label == 'Experience' || label == 'Credentials') {
                    await _captureAudit(
                      tester,
                      boundaryKey,
                      '${viewport.width.toInt()}-$language-${dark ? 'dark' : 'light'}-${entry.$1.replaceAll('/', '_')}-$label',
                    );
                  }
                }
                if (entry.$2 == PublicPortfolioView) {
                  expect(find.byType(PortfolioSettingsTab), findsNothing);
                  expect(
                    find.text(AppStrings.ui(language, 'Edit profile')),
                    findsNothing,
                  );
                }
              }
            }
            signedIn.value = false;
            for (final route in [
              '/login',
              '/register',
              '/forgot-password',
              '/reset-password',
            ]) {
              router.go(route);
              await _settle(tester);
              expect(router.routeInformationProvider.value.uri.path, route);
              expect(tester.takeException(), isNull, reason: route);
              await _captureAudit(
                tester,
                boundaryKey,
                '${viewport.width.toInt()}-$language-${dark ? 'dark' : 'light'}-${route.replaceAll('/', '_')}',
              );
            }
            await tester.pumpWidget(const SizedBox());
            await _settle(tester);
          },
        );
      }
    }
  }

  testWidgets(
    'dashboard and login fit compact phones and wide desktop viewports',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final signedIn = ValueNotifier(true);
      final router = buildRouter(
        isSignedIn: signedIn,
        currentUserId: () => 'owner',
      );
      addTearDown(router.dispose);
      addTearDown(signedIn.dispose);
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              routerConfig: router,
              theme: AppTheme.light(),
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
            ),
          ),
        ),
      );
      for (final size in [const Size(320, 740), const Size(1440, 900)]) {
        tester.view.physicalSize = size;
        signedIn.value = true;
        router.go('/');
        await _settle(tester);
        expect(find.byType(DashboardScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        for (final screen in ['dashboard', 'login']) {
          if (screen == 'login') {
            signedIn.value = false;
            router.go('/login');
            await _settle(tester);
          }
          expect(tester.takeException(), isNull, reason: '$screen at $size');
          await tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(format: ImageByteFormat.png);
            final file = File(
              'build/app-audit/$screen-${size.width.toInt()}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
      await tester.pumpWidget(const SizedBox());
      await _settle(tester);
    },
  );

  testWidgets(
    'changing preferences retains the active screen and restores choices after restart',
    (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CVPortfolioStudio(),
        ),
      );
      await _settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Settings'),
        ),
      );
      await _settle(tester);
      await tester.ensureVisible(find.text('Dark'));
      await _settle(tester);
      await tester.tap(find.text('Dark'));
      await _settle(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
      await tester.ensureVisible(find.text('العربية'));
      await _settle(tester);
      await tester.tap(find.text('العربية'));
      await _settle(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(container.read(localeProvider), 'ar');
      expect(container.read(themeModeProvider), 'dark');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings.locale'), 'ar');
      expect(prefs.getString('settings.themeMode'), 'dark');
      await tester.pumpWidget(const SizedBox());
      container.invalidate(localeProvider);
      container.invalidate(themeModeProvider);
      await container.read(localeProvider.notifier).load();
      await container.read(themeModeProvider.notifier).load();
      expect(container.read(localeProvider), 'ar');
      expect(container.read(themeModeProvider), 'dark');
    },
  );

  testWidgets(
    'narrow Arabic dark screens handle larger text, validation and the keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final signedIn = ValueNotifier(true);
      final router = buildRouter(
        isSignedIn: signedIn,
        currentUserId: () => 'owner',
      );
      addTearDown(router.dispose);
      addTearDown(signedIn.dispose);
      await tester.runAsync(
        () => local.saveCvDraft(
          'owner',
          'cv',
          const CvBuilderDraft(profile: _profile, step: 3),
        ),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            routerConfig: router,
            locale: const Locale('ar'),
            theme: AppTheme.dark(),
            supportedLocales: supportedLocales,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
          ),
        ),
      );
      router.go('/doc/cv');
      await _settle(tester);
      expect(tester.takeException(), isNull);
      router.go('/wizard/cv');
      await _settle(tester);
      final addProject = find.text(AppStrings.t('ar', 'addProject'));
      await tester.ensureVisible(addProject);
      await tester.tap(addProject);
      await _settle(tester);
      expect(find.byType(ProjectEntryDialog), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          AppStrings.ui('ar', 'Project title'),
        ),
        'عنوان English',
      );
      await tester.tap(find.text(AppStrings.ui('ar', 'Save')));
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.t('ar', 'singleLanguageRequired')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pump();
      await tester.tap(find.text(AppStrings.ui('ar', 'Cancel')));
      await _settle(tester);
      router.go('/portfolio');
      await _settle(tester);
      for (final label in ['Projects', 'Skills']) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar).last,
            matching: find.text(AppStrings.ui('ar', label)),
          ),
        );
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: label);
      }
      router.go('/settings?section=portfolio');
      await _settle(tester);
      final private = find.widgetWithText(
        SwitchListTile,
        AppStrings.ui('ar', 'Private (Password)'),
      );
      await tester.ensureVisible(private);
      await _settle(tester);
      await tester.tap(private);
      await _settle(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pump();
      await tester.tap(find.text(AppStrings.ui('ar', 'Save password')));
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings.ui('ar', 'Enter at least 4 characters')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pump();
      await tester.tap(find.text(AppStrings.ui('ar', 'Cancel')));
      await _settle(tester);
      await tester.pumpWidget(const SizedBox());
      await _settle(tester);
    },
  );

  testWidgets(
    'new CV starts empty, restores only its unfinished draft, and clears after Generate',
    (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CVPortfolioStudio(),
        ),
      );
      await _settle(tester);
      Future<void> create() async {
        final button = find.ancestor(
          of: find.text(AppStrings.t('en', 'buildCv')),
          matching: find.byWidgetPredicate((widget) => widget is FilledButton),
        );
        expect(button, findsOneWidget);
        await tester.ensureVisible(button);
        await _settle(tester);
        await tester.tap(button);
        await _settle(tester);
      }

      TextFormField nameField() => tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, AppStrings.t('en', 'fullName')),
      );
      await create();
      expect(nameField().controller!.text, isEmpty);
      await tester.enterText(
        find.widgetWithText(TextFormField, AppStrings.t('en', 'fullName')),
        'Grace Hopper',
      );
      await tester.tap(find.byTooltip(AppStrings.t('en', 'home')));
      await _settle(tester);
      expect(container.read(dashboardTabProvider), 0);
      expect(
        (await tester.runAsync(() => local.loadProfile('owner')))!
            .details
            .fullName,
        'Ada Lovelace',
      );
      await create();
      expect(nameField().controller!.text, 'Grace Hopper');
      await tester.tap(find.text(AppStrings.t('en', 'continue')));
      await _settle(tester);
      expect(find.text(AppStrings.t('en', 'stepExperience')), findsWidgets);
      // The top back goes Home; the bottom Back still returns to the prior step.
      await tester.tap(find.byTooltip(AppStrings.t('en', 'home')));
      await _settle(tester);
      expect(container.read(dashboardTabProvider), 0);
      await create();
      expect(find.text(AppStrings.t('en', 'stepExperience')), findsWidgets);
      await tester.tap(find.text(AppStrings.t('en', 'back')));
      await _settle(tester);
      expect(nameField().controller!.text, 'Grace Hopper');
      await tester.tap(find.text(AppStrings.t('en', 'skip')));
      await _settle(tester);
      await tester.tap(find.text(AppStrings.t('en', 'generateCv')));
      await _settle(tester);
      for (
        var i = 0;
        i < 100 && find.byType(CvDesignSettingsScreen).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      expect(
        find.byType(CvDesignSettingsScreen),
        findsOneWidget,
        reason: find
            .byType(Text)
            .evaluate()
            .map((e) => (e.widget as Text).data)
            .toList()
            .toString(),
      );
      final documents = await tester.runAsync(
        () => local.listDocuments('owner'),
      );
      final cvs = documents!.where((d) => d.type == DocumentType.cv).toList();
      expect(cvs.length, 2);
      expect(
        cvs.singleWhere((d) => d.id == 'cv').profileSnapshot!.details.fullName,
        'Ada Lovelace',
      );
      expect(
        cvs.singleWhere((d) => d.id != 'cv').profileSnapshot!.details.fullName,
        'Grace Hopper',
      );
      expect(
        await tester.runAsync(() => local.loadCvDraft('owner', 'new')),
        isNull,
      );
      expect(
        (await tester.runAsync(() => local.loadProfile('owner')))!
            .projects
            .single
            .id,
        'p',
      );
      await tester.tap(find.byTooltip('Back'));
      await _settle(tester);
      expect(nameField().controller!.text, isEmpty);
      await tester.tap(find.byTooltip(AppStrings.t('en', 'home')));
      await _settle(tester);
      // Editing an existing CV deliberately restores that CV's saved content.
      GoRouter.of(tester.element(find.byType(DashboardScreen)))
          .push('/wizard/cv');
      await _settle(tester);
      expect(nameField().controller!.text, 'Ada Lovelace');
      await tester.tap(find.byTooltip(AppStrings.t('en', 'home')));
      await _settle(tester);
      await tester.pumpWidget(const SizedBox());
      await _settle(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'social tap opens once, long press copies and About does not repeat icon contacts',
    (tester) async {
      final opened = <Uri>[];
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PortfolioContactActions(
              actions: portfolioContacts(_profile.details),
              onOpen: opened.add,
            ),
          ),
        ),
      );
      for (final label in ['GitHub', 'LinkedIn', 'WhatsApp']) {
        final button = find.byTooltip(label);
        final before = opened.length;
        await tester.tap(button);
        await tester.pump();
        expect(opened.length, before + 1);
        await tester.longPress(button);
        await tester.pump();
        expect(opened.length, before + 1);
        expect(
          copied,
          label == 'WhatsApp' ? '+201012345678' : opened.last.toString(),
        );
      }
      expect(opened.last.toString(), 'https://wa.me/201012345678');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PortfolioBuilderScreen()),
        ),
      );
      await _settle(tester);
      expect(find.text('https://github.com/ada'), findsNothing);
      expect(find.text('https://linkedin.com/in/ada'), findsNothing);
      expect(find.text('+20 101 234 5678'), findsNothing);
      expect(find.byTooltip('WhatsApp'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
