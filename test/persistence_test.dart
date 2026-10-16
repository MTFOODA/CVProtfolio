import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cv_portfolio_maker/core/design/templates.dart';
import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/document_models.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/data/local/local_repositories.dart';
import 'package:cv_portfolio_maker/data/local/local_store.dart';
import 'package:cv_portfolio_maker/data/repositories.dart';

/// Builds a document with optional overrides.
CvDocument makeDoc({
  required String id,
  String owner = 'user-1',
  String title = 'CV',
  DocumentDesign? design,
}) => CvDocument(
  id: id,
  ownerId: owner,
  title: title,
  design: design ?? const DocumentDesign(),
);

void main() {
  late Directory dir;
  late LocalBackend backend;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('cv_store_test');
    backend = LocalBackend(LocalStore.forDirectory(dir));
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  // --------------------------------------------------------------- documents

  group('document persistence', () {
    test('a saved layout configuration is restored after a restart', () async {
      final design = DocumentDesign(
        layoutMode: LayoutMode.mix,
        templateId: 'creative',
        sections: const [
          SectionConfig(
            id: 'experience',
            kind: SectionKind.experience,
            slot: ColumnSlot.left,
            visible: false,
            customTitle: 'Work',
          ),
          SectionConfig(id: 'pb', kind: SectionKind.pageBreak),
        ],
        spacing: const SpacingConfig(leftColumnRatio: 0.6, columnGap: 22),
        colors: const ColorConfig(accent: 0xFF00FF00),
      );

      await backend.saveDocument(makeDoc(id: 'd1', design: design));

      // Simulate an app restart by opening a new backend over the same files.
      final reopened = LocalBackend(LocalStore.forDirectory(dir));
      final loaded = await reopened.loadDocument('d1', 'user-1');

      expect(loaded, isNotNull);
      expect(loaded!.design.layoutMode, LayoutMode.mix);
      expect(loaded.design.templateId, 'creative');
      expect(loaded.design.spacing.leftColumnRatio, 0.6);
      expect(loaded.design.spacing.columnGap, 22);
      expect(loaded.design.colors.accent, 0xFF00FF00);
      expect(loaded.design.sections.map((s) => s.id), ['experience', 'pb']);
      expect(loaded.design.sections.first.slot, ColumnSlot.left);
      expect(loaded.design.sections.first.visible, isFalse);
      expect(loaded.design.sections.first.customTitle, 'Work');
      expect(loaded.design.sections.last.isPageBreak, isTrue);
    });

    test('editing one document leaves the others untouched', () async {
      await backend.saveDocument(makeDoc(id: 'd1', title: 'First'));
      await backend.saveDocument(makeDoc(id: 'd2', title: 'Second'));

      final first = await backend.loadDocument('d1', 'user-1');
      await backend.saveDocument(
        first!.copyWith(
          design: first.design.copyWith(layoutMode: LayoutMode.two),
        ),
      );

      final second = await backend.loadDocument('d2', 'user-1');
      expect(second!.design.layoutMode, LayoutMode.one);
      expect(second.title, 'Second');
    });

    test(
      'selecting a template persists a content-independent design',
      () async {
        final design = designForTemplate('modern', DocumentType.cv);
        await backend.saveDocument(makeDoc(id: 'd1', design: design));

        final loaded = await backend.loadDocument('d1', 'user-1');
        expect(loaded!.design.templateId, 'modern');
        expect(loaded.design.layoutMode, LayoutMode.two);
        expect(loaded.design.colors.accent, design.colors.accent);
      },
    );

    test('ownership is enforced when loading', () async {
      await backend.saveDocument(makeDoc(id: 'd1', owner: 'user-1'));
      expect(await backend.loadDocument('d1', 'user-2'), isNull);
    });

    test('documents are listed newest first', () async {
      await backend.saveDocument(
        makeDoc(id: 'old')
            .copyWith(updatedAtIso: () => '2024-01-01T00:00:00.000Z'),
      );
      await backend.saveDocument(
        makeDoc(id: 'new')
            .copyWith(updatedAtIso: () => '2025-01-01T00:00:00.000Z'),
      );

      final docs = await backend.listDocuments('user-1');
      expect(docs.map((d) => d.id), ['new', 'old']);
    });

    test('saving twice updates in place rather than duplicating', () async {
      await backend.saveDocument(makeDoc(id: 'd1', title: 'One'));
      await backend.saveDocument(makeDoc(id: 'd1', title: 'Two'));

      final docs = await backend.listDocuments('user-1');
      expect(docs.length, 1);
      expect(docs.single.title, 'Two');
    });

    test('deleting a document removes it and its shares', () async {
      await backend.saveDocument(makeDoc(id: 'd1'));
      await backend.saveShare(
        const DocumentShare(
          id: 's1',
          documentId: 'd1',
          mode: ShareMode.publicLink,
          slug: 'abc',
        ),
      );

      await backend.deleteDocument('d1', 'user-1');

      expect(await backend.loadDocument('d1', 'user-1'), isNull);
      expect(await backend.listSharesForOwner('user-1'), isEmpty);
    });

    test('a failed save propagates instead of reporting success', () async {
      final doomedDir = Directory('${dir.path}/gone');
      final failing = LocalBackend(LocalStore.forDirectory(doomedDir));
      doomedDir.deleteSync(recursive: true);

      await expectLater(
        failing.saveDocument(makeDoc(id: 'd1')),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  // ---------------------------------------------------------------- profiles

  group('profile persistence', () {
    test('a saved profile is restored', () async {
      await backend.saveProfile(
        const UserProfile(
          id: 'user-1',
          details: ProfileDetails(
            fullName: 'Ada Lovelace',
            email: 'ada@example.com',
            summary: 'Pioneer',
          ),
          skills: [SkillEntry(id: 's1', name: 'Mathematics')],
        ),
      );

      final loaded = await backend.loadProfile('user-1');
      expect(loaded, isNotNull);
      expect(loaded!.details.fullName, 'Ada Lovelace');
      expect(loaded.details.summary, 'Pioneer');
      expect(loaded.skills.single.name, 'Mathematics');

      // A missing profile is null, not an error.
      expect(await backend.loadProfile('nobody'), isNull);
    });
  });

  // ------------------------------------------------------------------ shares

  group('share resolution and authorization', () {
    setUp(() async {
      await backend.saveProfile(const UserProfile(id: 'user-1'));
    });

    Future<void> seed({required bool published}) async {
      await backend.saveDocument(
        makeDoc(id: 'd1').copyWith(published: published),
      );
    }

    test('a published document resolves through its public slug', () async {
      await seed(published: true);
      await backend.saveShare(
        const DocumentShare(
          id: 's1',
          documentId: 'd1',
          mode: ShareMode.publicLink,
          slug: 'abc123',
        ),
      );

      final resolved = await backend.resolveBySlug('abc123');
      expect(resolved, isNotNull);
      expect(resolved!.document.id, 'd1');
      expect(resolved.profile.id, 'user-1');
    });

    test('an unknown slug resolves to null', () async {
      expect(await backend.resolveBySlug('missing'), isNull);
    });

    test('an unpublished document never resolves publicly', () async {
      await seed(published: false);
      await backend.saveShare(
        const DocumentShare(
          id: 's1',
          documentId: 'd1',
          mode: ShareMode.publicLink,
          slug: 'abc123',
        ),
      );

      await expectLater(
        backend.resolveBySlug('abc123'),
        throwsA(isA<ShareNotFoundException>()),
      );
    });

    test('a valid restricted token resolves', () async {
      await seed(published: true);
      await backend.saveShare(
        const DocumentShare(
          id: 's1',
          documentId: 'd1',
          mode: ShareMode.restrictedRecipient,
          accessToken: 'secret-token',
        ),
      );

      final resolved = await backend.resolveByToken('secret-token');
      expect(resolved.document.id, 'd1');
    });

    test('a revoked token is rejected', () async {
      await seed(published: true);
      await backend.saveShare(
        const DocumentShare(
          id: 's1',
          documentId: 'd1',
          mode: ShareMode.restrictedRecipient,
          accessToken: 'revoked',
          revokedAtIso: '2020-01-01T00:00:00.000Z',
        ),
      );

      await expectLater(
        backend.resolveByToken('revoked'),
        throwsA(isA<ShareNotFoundException>()),
      );
    });

    test('an expired token is rejected', () async {
      await seed(published: true);
      await backend.saveShare(
        const DocumentShare(
          id: 's1',
          documentId: 'd1',
          mode: ShareMode.restrictedRecipient,
          accessToken: 'expired',
          expiresAtIso: '2000-01-01T00:00:00.000Z',
        ),
      );

      await expectLater(
        backend.resolveByToken('expired'),
        throwsA(isA<ShareNotFoundException>()),
      );
    });

    test('an unknown token is rejected', () async {
      await expectLater(
        backend.resolveByToken('nope'),
        throwsA(isA<ShareNotFoundException>()),
      );
    });

    test('revoking a share immediately denies access', () async {
      await seed(published: true);
      await backend.saveShare(
        const DocumentShare(
          id: 's1',
          documentId: 'd1',
          mode: ShareMode.restrictedRecipient,
          accessToken: 'tok',
        ),
      );

      expect((await backend.resolveByToken('tok')).document.id, 'd1');

      await backend.revokeShare('s1', 'user-1');

      await expectLater(
        backend.resolveByToken('tok'),
        throwsA(isA<ShareNotFoundException>()),
      );
    });

    test('shares never leak across owners', () async {
      await backend.saveProfile(const UserProfile(id: 'user-2'));
      await backend.saveDocument(makeDoc(id: 'd2', owner: 'user-2'));
      await backend.saveShare(
        const DocumentShare(
          id: 's2',
          documentId: 'd2',
          mode: ShareMode.publicLink,
          slug: 'other',
        ),
      );

      // user-1 only sees shares for their own documents.
      expect(await backend.listSharesForOwner('user-1'), isEmpty);
      expect((await backend.listSharesForOwner('user-2')).single.id, 's2');
    });

    test('view counts are recorded without granting extra access', () async {
      await seed(published: true);
      await backend.saveShare(
        const DocumentShare(
          id: 's1',
          documentId: 'd1',
          mode: ShareMode.publicLink,
          slug: 'abc',
        ),
      );

      await backend.recordView('s1');
      final shares = await backend.listSharesForOwner('user-1');
      expect(shares.single.viewCount, 1);
    });
  });
}
