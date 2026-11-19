/// Contact links keep their destination separate from the visible CV text.
String? contactWebUrl(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty || value.length > 2048 || RegExp(r'\s').hasMatch(value)) {
    return null;
  }
  final parsed = Uri.tryParse(value);
  if (parsed == null) return null;
  if (parsed.hasScheme && !{'http', 'https'}.contains(parsed.scheme)) {
    return null;
  }
  final uri = Uri.tryParse(parsed.hasScheme ? value : 'https://$value');
  if (uri == null ||
      uri.host.isEmpty ||
      !uri.host.contains('.') ||
      uri.userInfo.isNotEmpty ||
      uri.host.startsWith('.') ||
      uri.host.endsWith('.')) {
    return null;
  }
  if (!uri.host
      .split('.')
      .every(
        (label) =>
            label.length <= 63 &&
            RegExp(r'^[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?$')
                .hasMatch(label),
      )) {
    return null;
  }
  return uri.toString();
}

String contactLinkKind(String? value) {
  final host =
      Uri.tryParse(contactWebUrl(value) ?? '')?.host.toLowerCase() ?? '';
  if (host == 'github.com' || host.endsWith('.github.com')) return 'GitHub';
  if (host == 'linkedin.com' || host.endsWith('.linkedin.com')) {
    return 'LinkedIn';
  }
  return 'Link';
}

String compactContactUrl(String value) => value
    .trim()
    .replaceFirst(RegExp(r'^https?://', caseSensitive: false), '')
    .replaceFirst(RegExp(r'^www\.', caseSensitive: false), '')
    .replaceFirst(RegExp(r'/$'), '');

/// Shared by Flutter and document exporters; no platform dependency.
const contactBrandCodes = {'GitHub': 0xf09b, 'LinkedIn': 0xf08c};
const contactBrandFontFamily = 'Font Awesome 6 Brands Regular';
const contactBrandAsset = 'assets/google_fonts/ContactBrands-Regular.ttf';
