import '../../core/design/app_icons.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/domain/profile_models.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/contact_links.dart';
import '../../core/utils/project_media.dart';
import '../../core/utils/utils.dart';
import '../../core/widgets/date_range_fields.dart';
import '../../core/widgets/form_validation.dart';
import '../../data/repositories.dart';
import '../portfolio/portfolio_widgets.dart';

/// Draft-owned sections; saving never writes the live profile behind the wizard.
class CustomEntriesStep extends StatefulWidget {
  const CustomEntriesStep({
    super.key,
    required this.profile,
    required this.mediaRepository,
    required this.onSave,
  });
  final UserProfile profile;
  final MediaRepository mediaRepository;
  final Future<void> Function(UserProfile) onSave;
  @override
  State<CustomEntriesStep> createState() => _CustomEntriesStepState();
}

class _CustomEntriesStepState extends State<CustomEntriesStep> {
  bool _busy = false;
  Future<void> _write(List<CustomSection> sections) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onSave(widget.profile.copyWith(customSections: sections));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit({CustomSection? section, CustomEntry? entry}) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _CustomEntryDialog(
        section: section,
        initial: entry,
        owner: widget.profile.id,
        repository: widget.mediaRepository,
        onSave: (title, category, updated) async {
          final selected = section ?? CustomSection(id: newId(), title: title);
          final entries = [...selected.entries];
          final index = entries.indexWhere((item) => item.id == updated.id);
          if (index < 0) {
            entries.add(updated);
          } else {
            entries[index] = updated;
          }
          final updatedSection = selected.copyWith(
            title: title,
            entries: entries,
            category: category,
          );
          final sections = [...widget.profile.customSections];
          final sectionIndex = sections.indexWhere(
            (item) => item.id == selected.id,
          );
          if (sectionIndex < 0) {
            sections.add(updatedSection);
          } else {
            sections[sectionIndex] = updatedSection;
          }
          await _write(sections);
        },
      ),
    );
  }

  Future<void> _remove(CustomSection section, CustomEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(context.tr('delete')),
        content: Text(context.tr('credentialDeleteConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(context.tr('delete')),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      await _write([
        for (final item in widget.profile.customSections)
          if (item.id != section.id)
            item
          else
            item.copyWith(
              entries: item.entries
                  .where((value) => value.id != entry.id)
                  .toList(),
            ),
      ]);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr('errorGeneric'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final section in widget.profile.customSections)
        Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  section.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                for (final entry in section.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.title),
                      subtitle: Text(
                        entry.formatMetadata(
                          languageCode: context.languageCode,
                        ),
                      ),
                      leading: const Icon(AppIcons.document),
                      onTap: _busy
                          ? null
                          : () => _edit(section: section, entry: entry),
                      trailing: IconButton(
                        tooltip: context.tr('delete'),
                        icon: const Icon(AppIcons.delete),
                        onPressed: _busy ? null : () => _remove(section, entry),
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _edit(section: section),
                  icon: const Icon(AppIcons.add),
                  label: Text(context.tr('addEntry')),
                ),
              ],
            ),
          ),
        ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: FilledButton.icon(
          key: const ValueKey('add-custom-entry'),
          onPressed: _busy ? null : () => _edit(),
          icon: const Icon(AppIcons.add),
          label: Text(context.tr('addEntry')),
        ),
      ),
    ],
  );
}

class _CustomEntryDialog extends StatefulWidget {
  const _CustomEntryDialog({
    this.section,
    this.initial,
    required this.owner,
    required this.repository,
    required this.onSave,
  });
  final CustomSection? section;
  final CustomEntry? initial;
  final String owner;
  final MediaRepository repository;
  final Future<void> Function(String, CustomSectionCategory, CustomEntry)
  onSave;
  @override
  State<_CustomEntryDialog> createState() => _CustomEntryDialogState();
}

class _CustomEntryDialogState extends State<_CustomEntryDialog> {
  final _form = GlobalKey<FormState>();
  late final _section = TextEditingController(text: widget.section?.title);
  late CustomSectionCategory _category =
      widget.section?.category ?? CustomSectionCategory.custom;
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _issuer = TextEditingController(text: widget.initial?.issuer);
  late final _id = TextEditingController(text: widget.initial?.credentialId);
  late final _url = TextEditingController(text: widget.initial?.url);
  late final _content = TextEditingController(text: widget.initial?.content);
  late DateRange _range = widget.initial?.dateRange ?? const DateRange();
  late String _image = widget.initial?.imageUrl ?? '';
  PlatformFile? _file;
  bool _busy = false;
  bool _failed = false;
  @override
  void dispose() {
    for (final controller in [_section, _title, _issuer, _id, _url, _content]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: allowedImageExtensions,
      );
      if (!mounted || file == null) return;
      final error = projectMediaError(file);
      if (error != null) throw FormatException(error);
      setState(() => _file = file);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      if (_file != null) {
        _image = await uploadProjectMedia(
          file: _file!,
          repository: widget.repository,
          ownerId: widget.owner,
        );
        _file = null; // A failed draft write retries the same uploaded image.
      }
      await widget.onSave(
        _section.text.trim(),
        _category,
        (widget.initial ?? CustomEntry(id: newId(), title: '')).copyWith(
          title: _title.text.trim(),
          issuer: _issuer.text.trim(),
          dateRange: _range,
          credentialId: _id.text.trim(),
          url: _url.text.trim().isEmpty ? '' : contactWebUrl(_url.text)!,
          content: _content.text.trim(),
          imageUrl: _image,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(context.tr(widget.initial == null ? 'addEntry' : 'edit')),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: AbsorbPointer(
            absorbing: _busy,
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_failed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Text(context.tr('errorGeneric')),
                    ),
                  DropdownButtonFormField<CustomSectionCategory>(
                    key: const ValueKey('custom-section-category'),
                    initialValue: _category,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: context.tr('sectionCategory'),
                    ),
                    items: [
                      for (final category in CustomSectionCategory.values)
                        DropdownMenuItem(
                          value: category,
                          child: Text(context.tr(category.labelKey)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      final priorLabel = context.tr(_category.labelKey);
                      if (_section.text.trim().isEmpty ||
                          _section.text.trim() == priorLabel) {
                        _section.text = value == CustomSectionCategory.custom
                            ? ''
                            : context.tr(value.labelKey);
                      }
                      setState(() => _category = value);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final field in [
                    (_section, 'sectionName', true),
                    (_title, 'credentialTitle', true),
                    (_issuer, 'credentialIssuer', false),
                  ]) ...[
                    TextFormField(
                      controller: field.$1,
                      decoration: InputDecoration(
                        labelText: context.tr(field.$2),
                      ),
                      validator: (value) => context.validateText(
                        value,
                        required: field.$3,
                        max: 200,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  DateRangeFields(
                    value: _range,
                    onChanged: (value) => _range = value,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _id,
                    decoration: InputDecoration(
                      labelText: context.tr('credentialId'),
                    ),
                    validator: (value) => context.validateText(value, max: 200),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _url,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: context.tr('website'),
                    ),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ||
                            contactWebUrl(value) != null
                        ? null
                        : context.tr('credentialInvalidUrl'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _content,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: context.tr('entryDescription'),
                    ),
                    validator: context.validateText,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_image.isNotEmpty)
                    SizedBox(
                      height: 120,
                      child: PortfolioImage(
                        source: _image,
                        ownerId: widget.owner,
                        fallback: const Icon(AppIcons.image),
                      ),
                    ),
                  if (_file != null) Text(_file!.name),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pick,
                        icon: const Icon(AppIcons.image),
                        label: Text(context.tr('entryImage')),
                      ),
                      if (_image.isNotEmpty || _file != null)
                        TextButton(
                          onPressed: () => setState(() {
                            _image = '';
                            _file = null;
                          }),
                          child: Text(context.tr('removeImage')),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(context.tr('cancel')),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(context.tr('save')),
        ),
      ],
    ),
  );
}
