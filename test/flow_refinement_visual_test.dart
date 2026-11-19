import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cv_portfolio_maker/app/providers.dart';
import 'package:cv_portfolio_maker/core/config/app_config.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/l10n/app_strings.dart';
import 'package:cv_portfolio_maker/core/theme/app_theme.dart';
import 'package:cv_portfolio_maker/core/widgets/app_surfaces.dart';
import 'package:cv_portfolio_maker/data/auth/local_auth_service.dart';
import 'package:cv_portfolio_maker/data/local/local_repositories.dart';
import 'package:cv_portfolio_maker/data/local/local_store.dart';
import 'package:cv_portfolio_maker/data/repositories.dart';
import 'package:cv_portfolio_maker/features/cv_builder/cv_builder_wizard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final cache = File(Platform.resolvedExecutable).parent.parent.parent;
    final material = File(
      '${cache.path}/material_fonts/materialicons-regular.otf',
    );
    if (material.existsSync()) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(material.readAsBytes().then(ByteData.sublistView))).load();
    }
    for (final font in {
      'inter': 'Inter-Regular.ttf',
      'interBold': 'Inter-Bold.ttf',
      'tajawal': 'Tajawal-Regular.ttf',
      'CvBrandIcons': 'ContactBrands-Regular.ttf',
    }.entries) {
      await (FontLoader(
        font.key,
      )..addFont(rootBundle.load('assets/google_fonts/${font.value}'))).load();
    }
  });

  for (final width in [360.0, 1440.0]) {
    for (final language in ['en', 'ar']) {
      for (final dark in [false, true]) {
        testWidgets(
          'populated wizard spacing and custom steps $width $language $dark',
          (tester) async {
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            SharedPreferences.setMockInitialValues({});
            final auth = LocalAuthService();
            final user = await auth.signInLocally();
            final dir = await tester.runAsync(
              () => Directory.systemTemp.createTemp('wizard_visual_'),
            );
            final local = LocalBackend(LocalStore.forDirectory(dir!));
            final profile = UserProfile(
              id: user.id,
              details: const ProfileDetails(fullName: 'Ada Lovelace'),
              experiences: const [
                ExperienceEntry(
                  id: 'e',
                  position: 'Application Support Engineer',
                  company: 'Example Technology Company',
                  dateRange: DateRange(startIso: '2024-01-01', isCurrent: true),
                ),
              ],
              education: const [
                EducationEntry(
                  id: 'ed',
                  qualification: 'Bachelor of Engineering',
                  institution: 'Example University',
                  dateRange: DateRange(startIso: '2018-09', endIso: '2022-06'),
                ),
              ],
              projects: const [
                ProjectEntry(
                  id: 'p1',
                  title: 'Restaurant management system',
                  technologies: ['React', 'Python'],
                  dateRange: DateRange(startIso: '2023-01', endIso: '2024-01'),
                ),
                ProjectEntry(
                  id: 'p2',
                  title: 'CV and Portfolio Studio',
                  technologies: ['Flutter', 'Supabase'],
                ),
                ProjectEntry(
                  id: 'p3',
                  title: 'Personal finance tracker',
                  technologies: ['Dart', 'PostgreSQL'],
                ),
              ],
              customSections: const [
                CustomSection(
                  id: 'custom',
                  title: 'Professional development',
                  entries: [
                    CustomEntry(
                      id: 'cert',
                      title: 'Cloud architecture certificate',
                      issuer: 'Learning institute',
                      dateRange: DateRange(
                        startIso: '2024-05',
                        isCurrent: true,
                      ),
                      credentialId: 'CERT-42',
                      url: 'https://example.test/certificate',
                      content: 'Architecture, delivery and practical projects.',
                    ),
                  ],
                ),
              ],
            );
            await tester.runAsync(() => local.saveProfile(profile));
            final container = ProviderContainer(
              overrides: [
                backendProvider.overrideWithValue(
                  LocalBackendOrSupabase.local(local),
                ),
                authServiceProvider.overrideWithValue(auth),
                appConfigProvider.overrideWithValue(
                  const AppConfig(
                    supabaseUrl: '',
                    supabaseAnonKey: '',
                    googleWebClientId: '',
                    googleIosClientId: '',
                    shareBaseUrl: 'https://example.test',
                  ),
                ),
              ],
            );
            Future<void> settle() async {
              for (var i = 0; i < 12; i++) {
                await tester.pump(const Duration(milliseconds: 100));
                await tester.runAsync(
                  () => Future<void>.delayed(const Duration(milliseconds: 15)),
                );
              }
            }

            for (final step in [3, 6, 7]) {
              await tester.runAsync(
                () => local.saveCvDraft(
                  user.id,
                  'new',
                  CvBuilderDraft(profile: profile, step: step),
                ),
              );
              final key = GlobalKey();
              await tester.pumpWidget(
                UncontrolledProviderScope(
                  container: container,
                  child: RepaintBoundary(
                    key: key,
                    child: MaterialApp(
                      debugShowCheckedModeBanner: false,
                      builder: (context, child) => AppBackdrop(child: child!),
                      theme: dark ? AppTheme.dark() : AppTheme.light(),
                      locale: Locale(language),
                      supportedLocales: const [Locale('en'), Locale('ar')],
                      localizationsDelegates: const [
                        GlobalMaterialLocalizations.delegate,
                        GlobalWidgetsLocalizations.delegate,
                        GlobalCupertinoLocalizations.delegate,
                      ],
                      home: CvBuilderWizardScreen(key: ValueKey(step)),
                    ),
                  ),
                ),
              );
              await settle();
              expect(find.byType(LinearProgressIndicator), findsOneWidget);
              expect(
                tester
                    .widget<LinearProgressIndicator>(
                      find.byType(LinearProgressIndicator),
                    )
                    .value,
                (step + 1) / 8,
              );
              expect(tester.takeException(), isNull);
              if (step == 3) {
                final first = find.widgetWithText(
                  Card,
                  'Restaurant management system',
                );
                final second = find.widgetWithText(
                  Card,
                  'CV and Portfolio Studio',
                );
                final a = tester.getRect(
                  find
                      .descendant(of: first, matching: find.byType(Material))
                      .first,
                );
                final b = tester.getRect(
                  find
                      .descendant(of: second, matching: find.byType(Material))
                      .first,
                );
                expect(b.top - a.bottom, greaterThanOrEqualTo(16));
              }
              if (step == 6) {
                expect(find.text('Professional development'), findsOneWidget);
              }
              if (step == 7) {
                expect(
                  find.text(AppStrings.t(language, 'certificates')),
                  findsNothing,
                );
                final a = tester.getRect(
                  find.text('Application Support Engineer'),
                );
                final value = find.textContaining('Example Technology Company');
                final b = tester.getRect(value);
                if (width < 480) {
                  expect(b.top - a.bottom, greaterThanOrEqualTo(8));
                } else {
                  expect(
                    language == 'ar' ? a.left - b.right : b.left - a.right,
                    greaterThanOrEqualTo(16),
                  );
                }
              }
              await tester.runAsync(() async {
                final boundary =
                    key.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final picture = await boundary.toImage();
                final bytes = await picture.toByteData(
                  format: ImageByteFormat.png,
                );
                final file = File(
                  'build/flow-refinement-audit/${width.toInt()}-$language-${dark ? 'dark' : 'light'}-step$step.png',
                );
                await file.parent.create(recursive: true);
                await file.writeAsBytes(bytes!.buffer.asUint8List());
                picture.dispose();
              });
            }
            await tester.pumpWidget(const SizedBox());
            await settle();
            container.dispose();
            await tester.runAsync(() => dir.delete(recursive: true));
          },
        );
      }
    }
  }
}
