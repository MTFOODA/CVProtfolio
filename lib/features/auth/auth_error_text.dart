import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/l10n/app_strings.dart';
import '../../data/auth/auth_service.dart';

String authErrorKey(Object? error) {
  if (error is supabase.AuthApiException) {
    return switch (error.code) {
      'invalid_credentials' => 'invalidCredentials',
      'email_not_confirmed' => 'confirmEmailToContinue',
      'user_already_exists' || 'email_exists' => 'authAccountExists',
      'weak_password' => 'weakPassword',
      'same_password' => 'authUseDifferentPassword',
      'over_email_send_rate_limit' ||
      'over_request_rate_limit' => 'authRateLimited',
      'email_address_not_authorized' => 'authEmailDeliveryUnavailable',
      'otp_expired' || 'session_not_found' => 'authRecoveryExpired',
      _ => 'errorGeneric',
    };
  }
  if (error is GoogleSignInException) {
    return switch (error.code) {
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        'authGoogleConfiguration',
      _ => 'errorGeneric',
    };
  }
  if (error is AuthException) {
    if (error.message == 'Google sign-in requires Supabase') {
      return 'authOnlineUnavailable';
    }
    if (error.message.contains('GOOGLE_')) return 'authGoogleConfiguration';
    if (error.message.contains('not supported')) return 'authGoogleUnsupported';
    if (error.message.contains('requires Supabase')) {
      return 'authRecoveryUnavailable';
    }
  }
  return 'errorGeneric';
}

String authErrorText(BuildContext context, Object? error) =>
    context.tr(authErrorKey(error));
