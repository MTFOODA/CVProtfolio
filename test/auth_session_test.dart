import 'dart:async';

import 'package:cv_portfolio_maker/app/providers.dart';
import 'package:cv_portfolio_maker/app/session.dart';
import 'package:cv_portfolio_maker/data/auth/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends Fake implements AuthService {
  final events = StreamController<AuthUser?>.broadcast();
  AuthUser? user;
  bool recovering = false;

  @override
  AuthUser? get currentUser => user;
  @override
  Stream<AuthUser?> get authStateChanges => events.stream;
  @override
  bool get isRecoveringPassword => recovering;
  @override
  Future<AuthUser?> restoreSession() async => user;
  @override
  Future<void> updatePassword(String password) async => recovering = false;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'provider sign-out and recovery events update application routing state',
    () async {
      final auth = _Auth();
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(auth)],
      );
      addTearDown(() async {
        container.dispose();
        await auth.events.close();
      });
      container.listen(sessionProvider2, (_, _) {});
      await container.read(sessionProvider2.future);
      await container.pump();
      const user = AuthUser(id: 'owner', email: 'owner@example.test');
      auth.user = user;
      auth.events.add(user);
      await container.pump();
      expect(container.read(sessionProvider2).value?.id, 'owner');
      auth.recovering = true;
      auth.events.add(user);
      await container.pump();
      expect(container.read(passwordRecoveryProvider), isTrue);
      await container
          .read(sessionProvider2.notifier)
          .updatePassword('new-password');
      expect(container.read(passwordRecoveryProvider), isFalse);
      expect(container.read(sessionProvider2).value?.id, 'owner');
      auth.user = null;
      auth.events.add(null);
      await container.pump();
      expect(container.read(sessionProvider2).value, isNull);
    },
  );
}
