import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/data/local/local_repositories.dart';
import 'package:cv_portfolio_maker/data/local/local_store.dart';
import 'package:cv_portfolio_maker/data/portfolio/password_hash.dart';
import 'package:cv_portfolio_maker/data/repositories.dart';

void main() {
  group('local password hashing', () {
    test('never stores the plaintext', () {
      final hash = hashPasswordLocally('hunter2');
      expect(hash, isNot(contains('hunter2')));
      expect(hash, startsWith('sha256\$'));
    });

    test('accepts the correct password and rejects others', () {
      final hash = hashPasswordLocally('hunter2');
      expect(verifyPasswordLocally('hunter2', hash), isTrue);
      expect(verifyPasswordLocally('Hunter2', hash), isFalse);
      expect(verifyPasswordLocally('', hash), isFalse);
    });

    test('uses a fresh salt for every hash', () {
      expect(
        hashPasswordLocally('same') == hashPasswordLocally('same'),
        isFalse,
      );
    });

    test('malformed hashes deny access instead of throwing', () {
      expect(verifyPasswordLocally('x', ''), isFalse);
      expect(verifyPasswordLocally('x', 'bcrypt\$not-ours'), isFalse);
      expect(verifyPasswordLocally('x', 'sha256\$only\$two\$extra'), isFalse);
    });
  });

  group('password-protected portfolio resolution', () {
    late Directory dir;
    late LocalBackend backend;

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('cv_password_test');
      backend = LocalBackend(LocalStore.forDirectory(dir));

      await backend.saveProfile(const UserProfile(id: 'owner-1'));
      await backend.saveDocument(
        const CvDocument(
          id: 'doc-1',
          ownerId: 'owner-1',
          title: 'Portfolio',
          type: DocumentType.portfolio,
          published: true,
          shareMode: ShareMode.publicLink,
          publicSlug: 'my-portfolio',
        ),
      );
      await backend.saveShare(
        const DocumentShare(
          id: 'share-1',
          documentId: 'doc-1',
          mode: ShareMode.publicLink,
          slug: 'my-portfolio',
        ),
      );
    });

    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('an unprotected document resolves by slug', () async {
      final resolved = await backend.resolveBySlug('my-portfolio');
      expect(resolved?.document.id, 'doc-1');
      expect((await backend.listSharesForOwner('owner-1')).single.viewCount, 1);
    });

    test('setting a password stores only a hash', () async {
      final saved = await backend.setAccessPassword(
        documentId: 'doc-1',
        userId: 'owner-1',
        password: 'open-sesame',
      );

      expect(saved.accessPasswordHash, isNotNull);
      expect(saved.accessPasswordHash, isNot(contains('open-sesame')));
      expect(saved.accessPasswordHash, startsWith('sha256\$'));
    });

    test('plain slug resolution refuses a protected document', () async {
      await backend.setAccessPassword(
        documentId: 'doc-1',
        userId: 'owner-1',
        password: 'open-sesame',
      );

      // The denial is explicit and matches the unpublished-document path, so
      // the viewer can offer the password prompt instead of leaking content.
      await expectLater(
        backend.resolveBySlug('my-portfolio'),
        throwsA(isA<ShareNotFoundException>()),
      );
    });

    test(
      'the password-gated resolver accepts only the right password',
      () async {
        await backend.setAccessPassword(
          documentId: 'doc-1',
          userId: 'owner-1',
          password: 'open-sesame',
        );

        expect(
          await backend.resolveBySlugWithPassword('my-portfolio', 'wrong'),
          isNull,
        );
        expect(
          (await backend.listSharesForOwner('owner-1')).single.viewCount,
          0,
        );
        final resolved = await backend.resolveBySlugWithPassword(
          'my-portfolio',
          'open-sesame',
        );
        expect(resolved?.document.id, 'doc-1');
        expect(
          (await backend.listSharesForOwner('owner-1')).single.viewCount,
          1,
        );
      },
    );

    test('clearing the password restores plain resolution', () async {
      await backend.setAccessPassword(
        documentId: 'doc-1',
        userId: 'owner-1',
        password: 'open-sesame',
      );
      await backend.setAccessPassword(
        documentId: 'doc-1',
        userId: 'owner-1',
        password: null,
      );

      expect(await backend.resolveBySlug('my-portfolio'), isNotNull);
      expect(
        await backend.resolveBySlugWithPassword('my-portfolio', 'open-sesame'),
        isNull,
      );
    });

    test('a non-owner cannot set the password', () async {
      await expectLater(
        backend.setAccessPassword(
          documentId: 'doc-1',
          userId: 'intruder',
          password: 'hijack',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
