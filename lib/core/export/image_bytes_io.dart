/// Native implementation: fetches image bytes over HTTP(S).
///
/// Bounded in both time and size so a slow or oversized image can never hang an
/// export or exhaust memory. Any failure yields `null`, which the exporter
/// treats as "no image" rather than an error.
library;

import 'dart:io';
import 'dart:typed_data';

/// The largest image the exporter will download (8 MiB).
const int maxImageBytes = 8 * 1024 * 1024;

/// Downloads [url], returning `null` when unavailable or unsupported.
Future<Uint8List?> fetchImageBytes(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https' && uri.scheme != 'file') {
    return null;
  }

  if (uri.scheme == 'file') {
    try {
      final file = File.fromUri(uri);
      if (!file.existsSync()) return null;
      final length = file.lengthSync();
      if (length <= 0 || length > maxImageBytes) return null;
      return await file.readAsBytes();
    } on Object {
      return null;
    }
  }

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) return null;

    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
      if (builder.length > maxImageBytes) {
        await response.drain<void>();
        return null;
      }
    }
    final bytes = builder.takeBytes();
    return bytes.isEmpty ? null : bytes;
  } on Object {
    return null;
  } finally {
    client.close(force: true);
  }
}
