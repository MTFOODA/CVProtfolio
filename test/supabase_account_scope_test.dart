import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cv_portfolio_maker/data/repositories.dart';
import 'package:cv_portfolio_maker/data/supabase/supabase_backend.dart';

User user(String id) => User.fromJson({
  'id': id,
  'aud': 'authenticated',
  'email': '$id@example.test',
  'created_at': '2026-01-01T00:00:00Z',
  'app_metadata': <String, dynamic>{},
  'user_metadata': <String, dynamic>{},
})!;

class _Auth extends Fake implements GoTrueClient {
  User? user;
  @override
  User? get currentUser => user;
}

class _Client extends Fake implements SupabaseClient {
  _Client(this.auth, {this.media});
  final SupabaseStorageClient? media;
  @override
  final GoTrueClient auth;
  @override
  SupabaseStorageClient get storage => media!;
}

class _Files extends Fake implements StorageFileApi {
  int calls = 0;
  bool fail = false;
  @override
  Future<String> createSignedUrl(
    String path,
    int expiresIn, {
    TransformOptions? transform,
    DownloadBehavior? download,
    String? cacheNonce,
  }) async {
    calls++;
    if (fail) throw StateError('offline');
    return 'https://storage.test/$path?token=$calls';
  }
}

class _Storage extends Fake implements SupabaseStorageClient {
  _Storage(this.files);
  final _Files files;
  @override
  StorageFileApi from(String id) => files;
}

class _Backend extends SupabaseBackend {
  _Backend(super.client, this.onCleanup);
  final void Function() onCleanup;
  @override
  Future<void> deleteAllForUser(String userId) async => onCleanup();
}

void main() {
  test('image URL requests share an in-flight request and cached URL without bypassing ownership', () async {
    final auth = _Auth()..user = user('owner');
    final files = _Files();
    final backend = SupabaseBackend(_Client(auth, media: _Storage(files)));
    final urls = await Future.wait(
      List.generate(10, (_) => backend.signedUrl('owner', 'owner/photo.jpg')),
    );
    expect(urls.toSet().length, 1);
    expect(files.calls, 1);
    expect(await backend.signedUrl('owner', 'owner/photo.jpg'), urls.first);
    expect(files.calls, 1);
    auth.user = user('other');
    await expectLater(
      backend.signedUrl('owner', 'owner/photo.jpg'),
      throwsA(isA<UnauthorizedException>()),
    );
    await expectLater(
      backend.signedUrl('other', 'owner/photo.jpg'),
      throwsA(isA<UnauthorizedException>()),
    );
    expect(files.calls, 1);
  });

  test('failed image URL lookups are retried rather than cached', () async {
    final files = _Files()..fail = true;
    final backend = SupabaseBackend(
      _Client(_Auth()..user = user('owner'), media: _Storage(files)),
    );
    await expectLater(
      backend.signedUrl('owner', 'owner/photo.jpg'),
      throwsStateError,
    );
    files.fail = false;
    expect(await backend.signedUrl('owner', 'owner/photo.jpg'), isNotNull);
    expect(files.calls, 2);
  });
  test('account deletion rejects a stale owner before cleanup', () async {
    final auth = _Auth()..user = user('other');
    var cleaned = false;
    final backend = _Backend(_Client(auth), () => cleaned = true);
    await expectLater(
      backend.deleteAccount('owner'),
      throwsA(isA<UnauthorizedException>()),
    );
    expect(cleaned, isFalse);
  });
  test(
    'account switch during storage cleanup cannot delete the new account',
    () async {
      final auth = _Auth()..user = user('owner');
      final backend = _Backend(_Client(auth), () => auth.user = user('other'));
      await expectLater(
        backend.deleteAccount('owner'),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(auth.currentUser?.id, 'other');
    },
  );
}
