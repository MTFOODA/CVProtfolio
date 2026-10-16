import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cv_portfolio_maker/data/auth/local_auth_service.dart';

void main() {
  test('signs in locally and exposes the current user', () async {
    SharedPreferences.setMockInitialValues({});
    final auth = LocalAuthService();
    final user = await auth.signInLocally(email: 'ada@example.com');

    expect(user.email, 'ada@example.com');
    expect(user.id, isNotEmpty);
    expect(auth.currentUser?.id, user.id);
  });

  test('restores a persisted session', () async {
    SharedPreferences.setMockInitialValues({});
    final first = LocalAuthService();
    final user = await first.signInLocally(email: 'ada@example.com');

    final second = LocalAuthService();
    final restored = await second.restoreSession();

    expect(restored?.id, user.id);
    expect(restored?.email, 'ada@example.com');
  });

  test('signOut clears the persisted session', () async {
    SharedPreferences.setMockInitialValues({});
    final auth = LocalAuthService();
    await auth.signInLocally();
    await auth.signOut();

    expect(await auth.restoreSession(), isNull);
    expect(auth.currentUser, isNull);
  });
}
