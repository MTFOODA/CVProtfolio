/// Shared utilities: ids, share tokens, URL safety and validation helpers.
library;

import 'dart:convert';
import 'dart:math';

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Maximum upload sizes (also enforced by Supabase storage policies).
const int maxImageBytes = 10 * 1024 * 1024;
const int maxVideoBytes = 100 * 1024 * 1024;

/// Allowed image extensions for uploads.
const List<String> allowedImageExtensions = ['jpg', 'jpeg', 'png', 'webp'];

/// Allowed video extensions for uploads.
const List<String> allowedVideoExtensions = ['mp4', 'mov', 'webm'];

/// A new v4 identifier.
String newId() => _uuid.v4();

/// Short URL-safe slug for public links.
String newSlug([String prefix = 'doc']) {
  final rng = Random.secure();
  final bytes = List<int>.generate(9, (_) => rng.nextInt(256));
  final suffix = base64Url.encode(bytes).replaceAll('=', '').toLowerCase();
  return '$prefix-$suffix';
}

/// High-entropy unguessable token: 32 random bytes, base64url encoded.
String newShareToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

/// Trims [raw] and prepends `https://` when no scheme is present.
String? normaliseUrl(String? raw) {
  if (raw == null) return null;
  final value = raw.trim();
  if (value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  return 'https://$value';
}

/// `true` when [url] is an absolute http(s) URL safe to open externally.
bool isSafeExternalUrl(String? url) {
  if (url == null || url.trim().isEmpty) return false;
  final uri = Uri.tryParse(url.trim());
  return uri != null &&
      uri.hasScheme &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
}

/// Minimal email sanity check used for export validation (not for auth).
bool looksLikeEmail(String? value) {
  if (value == null) return false;
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
}

/// Extension of [fileName], lowercased and without the dot.
String fileExtension(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return '';
  return fileName.substring(dot + 1).toLowerCase();
}
