/// Web (and any non-`dart:io`) implementation: images are never embedded.
library;

import 'dart:typed_data';

/// Always returns `null`; remote images are not fetched on the web.
Future<Uint8List?> fetchImageBytes(String url) async => null;
