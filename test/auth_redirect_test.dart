import 'package:cv_portfolio_maker/data/auth/auth_redirect.dart';
import 'package:cv_portfolio_maker/features/auth/auth_error_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('auth callbacks retain only a safe in-app destination', () {
    final uri = Uri.https('app.example.test', '/login', {
      'from': '/wizard/cv-1',
      'code': 'old',
    });
    expect(Uri.parse(webAuthRedirect(uri)).queryParameters, {
      'from': '/wizard/cv-1',
    });
    expect(
      authFlowLocation('/register', uri),
      '/register?from=%2Fwizard%2Fcv-1',
    );
    for (final unsafe in [
      'https://outside.test',
      '//outside.test',
      '/\\outside.test',
      '/login',
      '/reset-password',
    ]) {
      expect(internalReturnLocation(unsafe), isNull, reason: unsafe);
    }
  });
  test(
    'callbacks preserve app origin and path but never reuse auth credentials',
    () {
      final current = Uri.parse(
        'http://localhost:8080/app/?code=old#access_token=secret',
      );
      expect(webAuthRedirect(current), 'http://localhost:8080/app/');
      expect(
        webAuthRedirect(current, recovery: true),
        'http://localhost:8080/app/?auth=recovery',
      );
    },
  );
  test('login errors distinguish credentials, confirmation and Google configuration', () {
    expect(
      authErrorKey(
        const AuthApiException('Invalid login', code: 'invalid_credentials'),
      ),
      'invalidCredentials',
    );
    expect(
      authErrorKey(
        const AuthApiException('Not confirmed', code: 'email_not_confirmed'),
      ),
      'confirmEmailToContinue',
    );
    expect(
      authErrorKey(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.clientConfigurationError,
        ),
      ),
      'authGoogleConfiguration',
    );
  });
}
