/// Accepts only app-relative destinations, never an external redirect.
String? internalReturnLocation(String? value) {
  if (value == null ||
      !value.startsWith('/') ||
      value.startsWith('//') ||
      value.contains('\\')) {
    return null;
  }
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      {
        '/login',
        '/register',
        '/forgot-password',
        '/reset-password',
      }.contains(uri.path)) {
    return null;
  }
  return uri.toString();
}

/// Returns to this web app without retaining a previous OAuth code or token.
String webAuthRedirect(Uri current, {bool recovery = false}) {
  final destination = internalReturnLocation(current.queryParameters['from']);
  final query = {if (recovery) 'auth': 'recovery', 'from': ?destination};
  return Uri(
    scheme: current.scheme,
    host: current.host,
    port: current.hasPort ? current.port : null,
    path: current.path,
    queryParameters: query.isEmpty ? null : query,
  ).toString();
}

/// Carries the original destination between login, registration and recovery.
String authFlowLocation(String path, Uri current) {
  final destination = internalReturnLocation(current.queryParameters['from']);
  return Uri(
    path: path,
    queryParameters: destination == null ? null : {'from': destination},
  ).toString();
}
