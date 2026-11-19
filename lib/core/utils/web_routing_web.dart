import 'package:flutter_web_plugins/url_strategy.dart';

void configureWebRouting() {
  final location = BrowserPlatformLocation();
  final fragment = location.hash;
  // Keep earlier hash bookmarks working; OAuth token fragments are left intact.
  if (fragment.startsWith('#/') &&
      !fragment.startsWith('#//') &&
      !fragment.contains('\\')) {
    try {
      location.replaceState(null, '', fragment.substring(1));
    } catch (_) {
      /* Ignore malformed legacy URLs. */
    }
  }
  usePathUrlStrategy();
}
