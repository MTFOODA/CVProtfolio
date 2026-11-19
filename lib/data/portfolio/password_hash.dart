/// Hashing for portfolio visitor passwords.
///
/// Two implementations exist by design:
///
///   * **Supabase** hashes and verifies inside Postgres with `pgcrypto`
///     (`crypt`/`gen_salt('bf')`). The plaintext never leaves the request that
///     sets it, and verification happens in a `SECURITY DEFINER` function, so
///     a modified client cannot bypass the check.
///   * **Local mode** hashes on-device with salted SHA-256 because there is no
///     server. This is documented in the README as a single-device feature, not
///     as server-enforced privacy.
///
/// In both cases only a hash is ever persisted; no plaintext password is
/// stored in the document record or in preferences.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Marks a hash produced by [hashPasswordLocally].
const String _localPrefix = 'sha256';

/// Produces a salted SHA-256 hash in `sha256$<salt>$<digest>` form.
String hashPasswordLocally(String password) {
  final random = Random.secure();
  final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
  final salt = base64Url.encode(saltBytes).replaceAll('=', '');
  final digest = sha256.convert(utf8.encode('$salt:$password'));
  return '$_localPrefix\$$salt\$$digest';
}

/// Verifies [password] against [storedHash].
///
/// Returns `false` for malformed or unknown hash formats rather than throwing,
/// so a corrupt record denies access instead of crashing the viewer.
bool verifyPasswordLocally(String password, String storedHash) {
  final parts = storedHash.split(r'$');
  if (parts.length != 3 || parts[0] != _localPrefix) return false;
  final salt = parts[1];
  final expected = parts[2];
  final actual = sha256.convert(utf8.encode('$salt:$password')).toString();
  return _constantTimeEquals(actual, expected);
}

/// Compares two strings without an early exit on the first differing byte.
bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
