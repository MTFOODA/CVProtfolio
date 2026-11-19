import 'dart:js_interop';

import 'auth_redirect.dart';

@JS('window.history.state')
external JSAny? get _historyState;

@JS('window.history.replaceState')
external void _replaceState(JSAny? state, String title, String url);

// A completed recovery must not reopen on the next browser refresh.
void clearRecoveryUrl() {
  if (Uri.base.queryParameters['auth'] == 'recovery') {
    _replaceState(_historyState, '', webAuthRedirect(Uri.base));
  }
}
