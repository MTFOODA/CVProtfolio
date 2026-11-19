import 'package:cv_portfolio_maker/core/design/app_icons.dart';

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cv_portfolio_maker/core/design/skill_icons.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/utils/project_media.dart';
import 'package:cv_portfolio_maker/core/utils/utils.dart';
import 'package:cv_portfolio_maker/data/local/local_repositories.dart';
import 'package:cv_portfolio_maker/data/local/local_store.dart';
import 'package:cv_portfolio_maker/features/cv_builder/project_entry_dialog.dart';
import 'package:cv_portfolio_maker/features/cv_builder/skill_entry_dialog.dart';
import 'package:cv_portfolio_maker/features/portfolio/portfolio_tabs.dart';
import 'package:cv_portfolio_maker/features/portfolio/portfolio_widgets.dart';

final class _PickedFile extends PlatformFile {
  _PickedFile(this.name, this.data, {this.reportedSize});
  @override
  final String name;
  final Uint8List data;
  final int? reportedSize;
  @override
  Uri get uri => Uri.file('/$name');
  @override
  Never get xFile => throw UnimplementedError();
  @override
  int lengthSync() => reportedSize ?? data.length;
  @override
  Future<int> length() async => lengthSync();
  @override
  Future<Uint8List> readAsBytes() async => data;
  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(data);
}

class _Picker extends FilePickerPlatform {
  _Picker(this.file);
  final PlatformFile file;
  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => file;
}

void main() {
  late Directory dir;
  late LocalBackend backend;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('portfolio_content_');
    backend = LocalBackend(LocalStore.forDirectory(dir));
  });
  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  test('old profiles retain default icons; chosen icons and media survive reopening', () async {
    expect(
      SkillEntry.fromJson({'id': 'old', 'name': 'Writing'}).iconId,
      'general',
    );
    expect(skillIcon('unknown').id, 'general');
    expect(skillIcons.map((i) => i.id).toSet().length, skillIcons.length);
    expect(skillIcons.length, greaterThan(30));
    final media = await uploadProjectMedia(
      file: _PickedFile('cover.mp4', Uint8List.fromList([1, 2, 3])),
      repository: backend,
      ownerId: 'owner',
    );
    expect(media, startsWith('owner/'));
    expect(isProjectVideo(media), isTrue);
    await backend.saveProfile(
      UserProfile(
        id: 'owner',
        skills: const [
          SkillEntry(
            id: 's',
            name: 'Flutter',
            iconId: 'flutter',
            proficiency: 4,
          ),
        ],
        projects: [
          ProjectEntry(
            id: 'p',
            media: [media],
            sourceUrl: 'https://github.com/u/p',
          ),
        ],
      ),
    );
    final reopened = await LocalBackend(LocalStore.forDirectory(dir))
        .loadProfile('owner');
    expect(reopened!.skills.single.iconId, 'flutter');
    expect(reopened.skills.single.proficiency, 4);
    expect(reopened.projects.single.media.single, media);
    expect(reopened.projects.single.sourceUrl, 'https://github.com/u/p');
    final url = await backend.signedUrl('owner', media);
    final localUri = RegExp(r'^file://[A-Za-z]:').hasMatch(url!)
        ? Uri.file(url.substring(7), windows: true)
        : Uri.parse(url);
    expect(File.fromUri(localUri).readAsBytesSync(), [1, 2, 3]);
  });

  test(
    'upload validates types, actual size, unique paths and handles images',
    () async {
      expect(
        projectMediaError(_PickedFile('cover.exe', Uint8List(1))),
        isNotNull,
      );
      expect(
        projectMediaError(
          _PickedFile(
            'cover.png',
            Uint8List(1),
            reportedSize: maxImageBytes + 1,
          ),
        ),
        isNotNull,
      );
      expect(
        projectMediaError(
          _PickedFile(
            'demo.mp4',
            Uint8List(1),
            reportedSize: maxVideoBytes + 1,
          ),
        ),
        isNotNull,
      );
      expect(
        projectMediaError(_PickedFile('empty.png', Uint8List(0))),
        isNotNull,
      );
      final file = _PickedFile('cover.png', Uint8List.fromList([1, 2]));
      final a = await uploadProjectMedia(
        file: file,
        repository: backend,
        ownerId: 'owner',
      );
      final b = await uploadProjectMedia(
        file: file,
        repository: backend,
        ownerId: 'owner',
      );
      expect(a, isNot(b));
      expect(isProjectVideo(a), isFalse);
      expect(isProjectVideo('https://host/demo.MP4?token=secret'), isTrue);
    },
  );

  testWidgets(
    'project editor keeps demo and repository independent and can clear them',
    (tester) async {
      ProjectEntry? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => ProjectEntryDialog(
                    ownerId: 'owner',
                    mediaRepository: backend,
                    initial: const ProjectEntry(
                      id: 'p',
                      title: 'Saved project',
                      description: 'Original description',
                      demoUrl: 'https://demo.test',
                      sourceUrl: 'https://github.com/u/p',
                      media: ['owner/cover.png'],
                    ),
                    onSave: (entry) async => saved = entry,
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
      final description = find.widgetWithText(TextField, 'Entry text');
      await tester.ensureVisible(description);
      await tester.enterText(
        description,
        'Another description without a heading',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Live demo URL (optional)'),
        '',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'GitHub / repository URL'),
        'ftp://unsafe.test/repo',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.text('Enter a valid http or https URL.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'GitHub / repository URL'),
        'github.com/new/repo',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved!.id, 'p');
      expect(saved!.demoUrl, '');
      expect(saved!.sourceUrl, 'https://github.com/new/repo');
      expect(saved!.media, ['owner/cover.png']);
      expect(saved!.resolvedDescriptions.map((e) => e.formatted), [
        'Original description',
        'Another description without a heading',
      ]);
      expect(saved!.resolvedDescriptions.last.label, '');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'project editor uploads selected video on save and retains changes on failure',
    (tester) async {
      final oldPicker = FilePickerPlatform.instance;
      FilePickerPlatform.instance = _Picker(
        _PickedFile('demo.mp4', Uint8List.fromList([1, 2, 3])),
      );
      addTearDown(() => FilePickerPlatform.instance = oldPicker);
      ProjectEntry? saved;
      var fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProjectEntryDialog(
              ownerId: 'owner',
              mediaRepository: backend,
              initial: const ProjectEntry(id: 'p', title: 'Demo project'),
              onSave: (entry) async {
                saved = entry;
                if (fail) throw StateError('offline');
              },
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Demo video'));
      await tester.tap(find.text('Demo video'));
      await tester.pumpAndSettle();
      expect(find.text('demo.mp4'), findsOneWidget);
      await tester.tap(find.text('Save'));
      // Let real file I/O progress between fake widget-clock frames.
      for (var i = 0; i < 100 && saved == null; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 15)),
        );
      }
      expect(saved, isNotNull);
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not save the project'), findsOneWidget);
      final uploaded = saved!.media.single;
      expect(isProjectVideo(uploaded), isTrue);
      fail = false;
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved!.media.single, uploaded);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'skill picker saves selected icon and preserves identity and category on edit',
    (tester) async {
      SkillEntry? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SkillEntryDialog(
              initial: const SkillEntry(
                id: 's',
                name: 'Dart',
                category: 'Development',
                proficiency: 3,
              ),
              existingSkills: const ['Writing'],
              onSave: (entry) async => saved = entry,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Icon: General'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search icons'),
        'Flutter',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flutter').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved!.iconId, 'flutter');
      expect(saved!.id, 's');
      expect(saved!.category, 'Development');
      expect(saved!.proficiency, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'portfolio renders each visible skill as an independent card with its icon',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PortfolioSkillsTab(
              skills: const [
                SkillEntry(
                  id: 'a',
                  name: 'Dart',
                  iconId: 'code',
                  proficiency: 3,
                ),
                SkillEntry(
                  id: 'b',
                  name: 'Flutter',
                  iconId: 'flutter',
                  proficiency: 4,
                ),
                SkillEntry(id: 'c', name: 'Hidden', visible: false),
              ],
              hidden: false,
              onEdit: () {},
            ),
          ),
        ),
      );
      expect(find.byType(PortfolioCard), findsNWidgets(2));
      expect(find.byIcon(AppIcons.code), findsOneWidget);
      expect(find.byIcon(skillIcon('flutter').icon), findsOneWidget);
      expect(find.text('Hidden'), findsNothing);
    },
  );

  testWidgets(
    'GitHub logo opens the saved repository and invalid URLs are hidden',
    (tester) async {
      Uri? opened;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PortfolioProjectCard(
                  project: const ProjectEntry(
                    id: 'p',
                    title: 'Project',
                    sourceUrl: 'https://github.com/u/repo',
                    demoUrl: 'javascript:alert(1)',
                  ),
                  ownerId: 'owner',
                  onOpen: (uri) => opened = uri,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Live Demo'), findsNothing);
      expect(
        find.byIcon(const IconData(0xf09b, fontFamily: 'CvBrandIcons')),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('GitHub'));
      await tester.tap(find.text('GitHub'));
      expect(opened.toString(), 'https://github.com/u/repo');
    },
  );
}
