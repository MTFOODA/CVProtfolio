import '../../core/design/app_icons.dart';
import '../../core/widgets/date_range_fields.dart';
import '../../core/widgets/form_validation.dart';
import '../../core/widgets/description_items_editor.dart';

import 'package:cv_portfolio_maker/core/l10n/ui_text.dart';
import 'package:cv_portfolio_maker/core/l10n/app_strings.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/domain/profile_models.dart';
import '../../core/utils/project_media.dart';
import '../../core/utils/contact_links.dart';
import '../../core/utils/utils.dart';
import '../../data/repositories.dart';

class ProjectEntryDialog extends StatefulWidget {
  const ProjectEntryDialog({
    super.key,
    this.initial,
    required this.ownerId,
    required this.mediaRepository,
    required this.onSave,
  });
  final ProjectEntry? initial;
  final String ownerId;
  final MediaRepository mediaRepository;
  final Future<void> Function(ProjectEntry) onSave;
  @override
  State<ProjectEntryDialog> createState() => _ProjectEntryDialogState();
}

class _ProjectEntryDialogState extends State<ProjectEntryDialog> {
  final _form = GlobalKey<FormState>();
  late DateRange _range = widget.initial?.dateRange ?? const DateRange();
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _summary = TextEditingController(text: widget.initial?.summary);
  final _descriptionEditor = GlobalKey<DescriptionItemsEditorState>();
  late List<DescriptionItem> _descriptionItems = [
    ...?widget.initial?.resolvedDescriptions,
  ];
  late final _technologies = TextEditingController(
    text: widget.initial?.technologies.join(', '),
  );
  late final _demo = TextEditingController(text: widget.initial?.demoUrl);
  late final _source = TextEditingController(text: widget.initial?.sourceUrl);
  late List<String> _media = [...?widget.initial?.media];
  PlatformFile? _file;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    for (final controller in [
      _title,
      _summary,
      _technologies,
      _demo,
      _source,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(bool video) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: video
            ? allowedVideoExtensions
            : allowedImageExtensions,
      );
      if (!mounted || file == null) return;
      final error = projectMediaError(file);
      setState(() {
        _error = error;
        if (error == null) _file = file;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open the file. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (!(_descriptionEditor.currentState?.commitPending() ?? true)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_file != null) {
        final path = await uploadProjectMedia(
          file: _file!,
          repository: widget.mediaRepository,
          ownerId: widget.ownerId,
        );
        _media = [path, ..._media.skip(1)];
        // Reuse the upload if saving the profile fails and is retried.
        _file = null;
      }
      await widget.onSave(
        (widget.initial ?? ProjectEntry(id: newId())).copyWith(
          dateRange: _range,
          title: _title.text.trim(),
          summary: _summary.text.trim(),
          description: _descriptionItems.map((e) => e.formatted).join('\n'),
          descriptionItems: _descriptionItems,
          technologies: _technologies.text
              .split(RegExp(r'[,\u060c]'))
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toSet()
              .toList(),
          demoUrl: _demo.text.trim().isEmpty ? '' : contactWebUrl(_demo.text)!,
          sourceUrl: _source.text.trim().isEmpty
              ? ''
              : contactWebUrl(_source.text)!,
          media: _media,
        ),
      );
      if (mounted) Navigator.pop(context);
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not save the project or upload its media. Your changes are still here. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _url(String? value) =>
      (value ?? '').trim().isEmpty || contactWebUrl(value) != null
      ? null
      : context.ui('Enter a valid http or https URL.');

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: UiText(widget.initial == null ? 'Add project' : 'Edit project'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: AbsorbPointer(
            absorbing: _busy,
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _title,
                    decoration: InputDecoration(
                      labelText: context.ui('Project title'),
                    ),
                    validator: (v) =>
                        context.validateText(v, required: true, max: 160),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _summary,
                    validator: context.validateText,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: context.ui('Short summary'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DescriptionItemsEditor(
                    key: _descriptionEditor,
                    items: _descriptionItems,
                    onChanged: (items) =>
                        setState(() => _descriptionItems = items),
                  ),
                  const SizedBox(height: 12),
                  DateRangeFields(
                    value: _range,
                    onChanged: (value) => _range = value,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _technologies,
                    decoration: InputDecoration(
                      labelText: context.ui('Technologies'),
                      hintText: context.ui('Separate with commas'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _demo,
                    keyboardType: TextInputType.url,
                    textDirection: TextDirection.ltr,
                    validator: _url,
                    decoration: InputDecoration(
                      labelText: context.ui('Live demo URL (optional)'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _source,
                    keyboardType: TextInputType.url,
                    textDirection: TextDirection.ltr,
                    validator: _url,
                    decoration: InputDecoration(
                      labelText: context.ui('GitHub / repository URL'),
                      hintText: 'https://github.com/username/project',
                    ),
                  ),
                  const SizedBox(height: 20),
                  UiText(
                    'Portfolio cover',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  const UiText(
                    'Choose an image (up to 10 MB) or demo video (up to 100 MB). MP4 is recommended for playback across devices.',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _pick(false),
                        icon: const Icon(AppIcons.image),
                        label: const UiText('Image'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _pick(true),
                        icon: const Icon(AppIcons.videocam),
                        label: const UiText('Demo video'),
                      ),
                    ],
                  ),
                  if (_file != null || _media.isNotEmpty)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isProjectVideo(_file?.name ?? _media.first)
                            ? AppIcons.movie
                            : AppIcons.image,
                      ),
                      title: Text(
                        _file?.name ??
                            Uri.decodeComponent(_media.first.split('/').last),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: UiText(
                        _file == null ? 'Saved cover' : 'Uploads when you save',
                      ),
                      trailing: IconButton(
                        tooltip: context.ui('Remove cover'),
                        onPressed: () => setState(() {
                          _file = null;
                          _media = [];
                        }),
                        icon: const Icon(AppIcons.close),
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: UiText(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
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
          child: const UiText('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const UiText('Save'),
        ),
      ],
    ),
  );
}
