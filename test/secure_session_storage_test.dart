import 'package:cv_portfolio_maker/data/auth/secure_session_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'migrates the previous session then removes the plaintext copy',
    () async {
      SharedPreferences.setMockInitialValues({'session-key': 'legacy-session'});
      FlutterSecureStorage.setMockInitialValues({});
      final storage = SecureSessionStorage('session-key');
      await storage.initialize();
      expect(await storage.accessToken(), 'legacy-session');
      expect(
        (await SharedPreferences.getInstance()).getString('session-key'),
        isNull,
      );
      await storage.persistSession('rotated-session');
      expect(await storage.accessToken(), 'rotated-session');
      await storage.removePersistedSession();
      expect(await storage.hasAccessToken(), isFalse);
    },
  );
  test(
    'does not replace a newer encrypted session with an old plaintext one',
    () async {
      SharedPreferences.setMockInitialValues({'session-key': 'old-session'});
      FlutterSecureStorage.setMockInitialValues({'session-key': 'new-session'});
      final storage = SecureSessionStorage('session-key');
      await storage.initialize();
      expect(await storage.accessToken(), 'new-session');
      expect(
        (await SharedPreferences.getInstance()).containsKey('session-key'),
        isFalse,
      );
    },
  );
}
