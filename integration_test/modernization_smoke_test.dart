import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cv_portfolio_maker/main.dart';
import 'package:cv_portfolio_maker/app/providers.dart';
import 'package:cv_portfolio_maker/core/config/app_config.dart';
import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/export/export_service.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/l10n/app_strings.dart';
import 'package:cv_portfolio_maker/data/auth/local_auth_service.dart';
import 'package:cv_portfolio_maker/data/local/local_store.dart';
import 'package:cv_portfolio_maker/data/local/local_repositories.dart';
import 'package:cv_portfolio_maker/features/settings/credentials_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native Android: login, wizard, preferences, credentials and exports remain functional',
    (tester) async {
      // Test-owned offline identity and temp directory; no hosted user is touched.
      SharedPreferences.setMockInitialValues({});
      final directory = await Directory.systemTemp.createTemp(
        'cv_modernization_native_',
      );
      final captures = Directory(
        '${(await getApplicationSupportDirectory()).path}/modernization-qa',
      );
      await captures.create(recursive: true);
      Future<void> capture(String name) async {
        final bytes = await binding.takeScreenshot(name);
        await File('${captures.path}/$name.png').writeAsBytes(bytes);
        debugPrint('QA_SCREENSHOT=${captures.path}/$name.png');
      }

      final local = LocalBackend(LocalStore.forDirectory(directory));
      final auth = LocalAuthService();
      const profile = UserProfile(
        id: 'local-user',
        details: ProfileDetails(
          fullName: 'Integration Tester',
          email: 'tester@example.test',
        ),
      );
      await local.saveProfile(profile);
      final document = await local.saveDocument(
        const CvDocument(
          id: 'native-cv',
          ownerId: 'local-user',
          title: 'Native CV',
          profileSnapshot: profile,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(
                supabaseUrl: '',
                supabaseAnonKey: '',
                googleWebClientId: '',
                googleIosClientId: '',
                shareBaseUrl: 'https://example.test',
              ),
            ),
            backendProvider.overrideWithValue(
              LocalBackendOrSupabase.local(local),
            ),
            authServiceProvider.overrideWithValue(auth),
          ],
          child: const CVPortfolioStudio(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Explore without an account'));
      await tester.tap(find.text('Explore without an account'));
      await tester.pumpAndSettle();
      expect(find.text('Integration'), findsOneWidget);
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await capture('android-dashboard');

      await tester.tap(find.byType(NavigationDestination).at(1));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name'),
        'Native Tester',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Experience'), findsWidgets);
      await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_back).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NavigationDestination).last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Dark'));
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('العربية'));
      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();
      expect(
        Directionality.of(tester.element(find.byType(NavigationBar))),
        TextDirection.rtl,
      );
      await capture('android-settings-ar-dark');
      final certificates = find.widgetWithText(
        ActionChip,
        AppStrings.t('ar', 'certificates'),
      );
      await tester.ensureVisible(certificates);
      await tester.tap(certificates);
      await tester.pumpAndSettle();
      expect(find.byType(CredentialsScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('add-credential')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          AppStrings.t('ar', 'credentialTitle'),
        ),
        'شهادة اختبار',
      );
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          AppStrings.t('ar', 'credentialIssuer'),
        ),
        'جهة الاختبار',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.t('ar', 'save')),
      );
      await tester.pumpAndSettle();
      expect(
        (await local.loadProfile('local-user'))!.certificates.single.name,
        'شهادة اختبار',
      );
      expect(
        (await local.loadDocument(
          'native-cv',
          'local-user',
        ))!.profileSnapshot!.certificates,
        isEmpty,
      );
      await capture('android-certificates-ar-dark');
      final exporter = DocumentExporter();
      final pdf = await exporter.export(
        document: document,
        profile: profile,
        mode: ExportMode.atsFriendly,
        languageCode: 'en',
      );
      final docx = await exporter.exportDocx(
        document: document,
        profile: profile,
        languageCode: 'en',
      );
      expect(String.fromCharCodes(pdf.bytes.take(4)), '%PDF');
      expect(String.fromCharCodes(docx.bytes.take(2)), 'PK');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await directory.delete(recursive: true);
    },
  );
}
