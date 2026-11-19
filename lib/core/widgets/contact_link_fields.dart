import '../design/app_icons.dart';
import 'form_validation.dart';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../utils/contact_links.dart';

/// The URL remains a destination; display text never replaces the saved URL.
class ContactLinkFields extends StatelessWidget {
  const ContactLinkFields({
    super.key,
    required this.label,
    required this.url,
    required this.displayName,
    this.hint,
  });
  final String label;
  final TextEditingController url;
  final TextEditingController displayName;
  final String? hint;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextFormField(
        controller: url,
        keyboardType: TextInputType.url,
        autocorrect: false,
        textDirection: TextDirection.ltr,
        decoration: InputDecoration(
          labelText: context.ui(label),
          hintText: hint ?? 'https://…',
        ),
        validator: (value) {
          if (value?.trim().isEmpty ?? true) return null;
          if (contactWebUrl(value) == null) {
            return context.tr('invalidContactUrl');
          }
          if ({'GitHub', 'LinkedIn'}.contains(label) &&
              contactLinkKind(value) != label) {
            return context.tr('invalidSocialUrl', args: {'service': label});
          }
          return null;
        },
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: displayName,
        maxLength: 80,
        decoration: InputDecoration(
          labelText: context.tr('contactDisplayName'),
          hintText: context.ui('mtfooda'),
          helperText: context.tr('contactDisplayNameHint'),
          counterText: '',
        ),
        validator: (value) =>
            (value?.trim().isNotEmpty ?? false) && url.text.trim().isEmpty
            ? context.tr('contactUrlRequired')
            : context.validateText(value, max: 80),
      ),
    ],
  );
}

class ContactLinkDraft {
  ContactLinkDraft([String destination = '', String label = ''])
    : url = TextEditingController(text: destination),
      name = TextEditingController(text: label);
  final TextEditingController url;
  final TextEditingController name;
  void dispose() {
    url.dispose();
    name.dispose();
  }
}

/// Transient form controllers; persisted data stays in ProfileDetails.
class ContactLinksController extends ChangeNotifier {
  final rows = <ContactLinkDraft>[];
  void load(List<String> urls, Map<String, String> labels) {
    for (final row in rows) {
      row.dispose();
    }
    rows.clear();
    for (final url in urls) {
      rows.add(ContactLinkDraft(url, labels[url] ?? ''));
    }
    notifyListeners();
  }

  void add() {
    rows.add(ContactLinkDraft());
    notifyListeners();
  }

  void remove(ContactLinkDraft row) {
    rows.remove(row);
    notifyListeners();
    // Dispose after the TextFormFields have left the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
  }

  List<String> get urls => rows
      .map((r) => r.url.text.trim())
      .where((url) => url.isNotEmpty)
      .toSet()
      .toList();
  Map<String, String> get labels => {
    for (final row in rows)
      if (row.url.text.trim().isNotEmpty && row.name.text.trim().isNotEmpty)
        row.url.text.trim(): row.name.text.trim(),
  };
  @override
  void dispose() {
    for (final row in rows) {
      row.dispose();
    }
    super.dispose();
  }
}

class ContactLinksEditor extends StatelessWidget {
  const ContactLinksEditor({super.key, required this.controller});
  final ContactLinksController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in controller.rows)
          Padding(
            key: ObjectKey(row),
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                ContactLinkFields(
                  label: context.tr('links'),
                  url: row.url,
                  displayName: row.name,
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: () => controller.remove(row),
                    icon: const Icon(AppIcons.delete),
                    label: Text(context.tr('removeContactLink')),
                  ),
                ),
              ],
            ),
          ),
        OutlinedButton.icon(
          onPressed: controller.add,
          icon: const Icon(AppIcons.addLink),
          label: Text(context.tr('addContactLink')),
        ),
      ],
    ),
  );
}
