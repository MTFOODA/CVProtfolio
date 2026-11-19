import 'contact_links.dart';
import 'utils.dart';

String westernDigits(String text) {
  const arabic = '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹';
  return text.split('').map((c) {
    final index = arabic.indexOf(c);
    return index < 0 ? c : '${index % 10}';
  }).join();
}

String? internationalPhone(String? input) {
  var value = westernDigits(input?.trim() ?? '')
      .replaceAll(RegExp(r'[\s()\-.]'), '');
  if (value.startsWith('00')) value = '+${value.substring(2)}';
  return RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(value) ? value : null;
}

/// Returns localisation keys; no form duplicates the validation rules.
abstract final class InputValidation {
  static String? name(String? input) {
    final error = text(input, required: true, max: 160);
    if (error != null) return error;
    if (!RegExp(r'\p{L}', unicode: true).hasMatch(input!)) return 'invalidName';
    return RegExp(
          r"^[\p{L}\p{M} .'’\-]+$",
          unicode: true,
        ).hasMatch(input.trim())
        ? null
        : 'invalidName';
  }

  static String? text(String? input, {bool required = false, int max = 4000}) {
    final value = input?.trim() ?? '';
    if (value.isEmpty) return required ? 'required' : null;
    if (value.length > max) return 'inputTooLong';
    final arabic = RegExp(
      r'[\u0620-\u063F\u0641-\u064A\u066E-\u06D3\u06FA-\u06FC\u0750-\u077F\u08A0-\u08C9]',
    ).hasMatch(value);
    final latin = RegExp(r'[A-Za-z\u00C0-\u024F]').hasMatch(value);
    if (arabic && latin) return 'singleLanguageRequired';
    if (RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]').hasMatch(value)) {
      return 'invalidText';
    }
    return null;
  }

  static String? email(String? input, {bool required = false}) {
    final value = input?.trim() ?? '';
    if (value.isEmpty) return required ? 'required' : null;
    if (value.length > 254 || !looksLikeEmail(value) || value.contains('..')) {
      return 'invalidEmail';
    }
    final parts = value.split('@');
    if (parts.first.length > 64 ||
        parts.first.startsWith('.') ||
        parts.first.endsWith('.')) {
      return 'invalidEmail';
    }
    final labels = parts.last.split('.');
    return labels.every(
              (label) =>
                  label.length <= 63 &&
                  RegExp(r'^[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?$')
                      .hasMatch(label),
            ) &&
            labels.last.length >= 2
        ? null
        : 'invalidEmail';
  }

  static String? phone(String? input) =>
      (input?.trim() ?? '').isEmpty || internationalPhone(input) != null
      ? null
      : 'invalidPhone';
  static String? url(String? input) =>
      (input?.trim() ?? '').isEmpty || contactWebUrl(input) != null
      ? null
      : 'invalidContactUrl';

  /// Grades remain text: e.g. Excellent, جيد جدًا, A+, 3.8 / 4.
  static String? grade(String? input) => text(input, max: 80);
}
