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
  _Client(this.auth);
  @override
  final GoTrueClient auth;
}

class _Backend extends SupabaseBackend {
  _Backend(super.client, this.onCleanup);
  final void Function() onCleanup;
  @override
  Future<void> deleteAllForUser(String userId) async => onCleanup();
}

void main() {
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
