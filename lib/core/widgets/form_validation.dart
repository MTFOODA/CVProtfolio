import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../utils/input_validation.dart';

extension FormValidation on BuildContext {
  String? validateName(String? value) =>
      validationMessage(InputValidation.name(value));
  String? validationMessage(String? key) => key == null ? null : tr(key);
  String? validateText(
    String? value, {
    bool required = false,
    int max = 4000,
  }) => validationMessage(
    InputValidation.text(value, required: required, max: max),
  );
  String? validateEmail(String? value) =>
      validationMessage(InputValidation.email(value));
  String? validatePhone(String? value) =>
      validationMessage(InputValidation.phone(value));
}
