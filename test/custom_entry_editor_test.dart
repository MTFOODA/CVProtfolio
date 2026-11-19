import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/l10n/app_strings.dart';
import 'package:cv_portfolio_maker/core/theme/app_theme.dart';
import 'package:cv_portfolio_maker/core/design/skill_icons.dart';
import 'package:cv_portfolio_maker/data/repositories.dart';
import 'package:cv_portfolio_maker/features/cv_builder/custom_entries_step.dart';
import 'package:cv_portfolio_maker/features/cv_builder/skill_entry_dialog.dart';

class _Media extends Fake implements MediaRepository {}

void main() {
  testWidgets(
    'custom entry validates dates, keeps input on failed save and retries into its draft',
    (tester) async {
      var profile = const UserProfile(
        id: 'owner',
        projects: [ProjectEntry(id: 'retained', title: 'Existing')],
      );
      var fail = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => CustomEntriesStep(
                profile: profile,
                mediaRepository: _Media(),
                onSave: (updated) async {
                  if (fail) throw StateError('Temporary failure');
                  setState(() => profile = updated);
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('add-custom-entry')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('custom-section-category')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Certificates').last);
      await tester.pumpAndSettle();
      Future<void> enter(String key, String value) async {
        final field = find.widgetWithText(
          TextFormField,
          AppStrings.t('en', key),
        );
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await tester.enterText(field, value);
      }

      await enter('sectionName', 'Professional development');
      await enter('credentialTitle', 'Cloud certificate');
      await enter('credentialIssuer', 'Learning institute');
      await enter('startDate', '2024-05-01');
      await enter('endDate', '2023-01-01');
      await enter('credentialId', 'CERT-42');
      await enter('website', 'https://example.test/certificate');
      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.t('en', 'save')),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.t('en', 'endBeforeStart')), findsOneWidget);
      final ongoing = find.byType(CheckboxListTile);
      await tester.ensureVisible(ongoing);
      await tester.pumpAndSettle();
      await tester.tap(ongoing);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.t('en', 'save')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(profile.customSections, isEmpty);
      fail = false;
      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.t('en', 'save')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      final saved = profile.customSections.single.entries.single;
      expect(
        profile.customSections.single.category,
        CustomSectionCategory.certificates,
      );
      expect(profile.customSections.single.title, 'Professional development');
      expect(saved.credentialId, 'CERT-42');
      expect(saved.dateRange.isCurrent, isTrue);
      expect(saved.dateRange.startIso, '2024-05-01');
      expect(saved.url, 'https://example.test/certificate');
      expect(profile.projects.single.id, 'retained');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'typing a technology suggests its icon and saves it without forcing a picker',
    (tester) async {
      SkillEntry? saved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => SkillEntryDialog(
                    existingSkills: const [],
                    onSave: (entry) async {
                      saved = entry;
                    },
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Python');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ActionChip, 'Python'), findsOneWidget);
      expect(find.byIcon(skillIcon('python').icon), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(saved!.name, 'Python');
      expect(saved!.iconId, 'python');
      expect(tester.takeException(), isNull);
    },
  );
}
