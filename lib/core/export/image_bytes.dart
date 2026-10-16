/// Fetches image bytes for PDF embedding, per platform.
///
/// `dart:io` is unavailable on the web, so the implementation is selected at
/// compile time. The web build returns `null` (no images embedded) because
/// cross-origin fetches of remote avatars are blocked without CORS headers; the
/// exporter degrades gracefully rather than failing.
library;

export 'image_bytes_stub.dart' if (dart.library.io) 'image_bytes_io.dart';
