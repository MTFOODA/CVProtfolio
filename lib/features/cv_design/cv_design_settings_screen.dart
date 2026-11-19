import '../../core/design/app_icons.dart';
import '../../core/theme/app_tokens.dart';

import 'package:cv_portfolio_maker/core/l10n/ui_text.dart';
import 'package:cv_portfolio_maker/core/l10n/app_strings.dart';

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/domain/document_entity.dart';
import '../../core/domain/document_models.dart';
import '../../core/domain/profile_models.dart';
import '../../core/render/document_view.dart';
import '../../core/render/resolved_document.dart';
import '../../core/render/section_titles.dart';
import 'design_controls.dart';

class CvDesignSettingsScreen extends StatefulWidget {
  const CvDesignSettingsScreen({
    super.key,
    required this.document,
    required this.profile,
    required this.design,
    required this.onSave,
    this.onExport,
    this.additionalControls,
    this.titleController,
  });
  final CvDocument document;
  final UserProfile profile;

  /// The editor owns the single mutable draft; this screen only listens to it.
  final ValueNotifier<DocumentDesign> design;
  final Future<bool> Function() onSave;
  final Future<void> Function()? onExport;
  final Widget? additionalControls;
  final TextEditingController? titleController;
  @override
  State<CvDesignSettingsScreen> createState() => _CvDesignSettingsScreenState();
}

class _CvDesignSettingsScreenState extends State<CvDesignSettingsScreen> {
  late DocumentDesign _saved = widget.design.value;
  late String? _savedTitle = widget.titleController?.text;
  @override
  void initState() {
    super.initState();
    widget.titleController?.addListener(_titleChanged);
  }

  void _titleChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.titleController?.removeListener(_titleChanged);
    super.dispose();
  }

  bool _saving = false;
  bool _preview = false;
  bool _leaving = false;
  bool get _dirty =>
      jsonEncode(widget.design.value.toJson()) != jsonEncode(_saved.toJson()) ||
      widget.titleController?.text != _savedTitle;
  Future<bool> _save() async {
    if (_saving) return false;
    setState(() => _saving = true);
    var ok = false;
    try {
      ok = await widget.onSave();
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: UiText(
            'Could not save. Your design changes are still here. Please retry.',
          ),
        ),
      );
    }
    if (!mounted) return ok;
    setState(() {
      _saving = false;
      if (ok) {
        _saved = widget.design.value;
        _savedTitle = widget.titleController?.text;
      }
    });
    return ok;
  }

  Future<void> _export() async {
    if (_saving || widget.onExport == null) return;
    setState(() => _saving = true);
    try {
      await widget.onExport!();
      // The owner saves before opening the existing export sheet.
      if (mounted) {
        _saved = widget.document.design;
        _savedTitle = widget.document.title;
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _back() async {
    if (_saving || _leaving) return;
    if (!_dirty) {
      Navigator.pop(context);
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const UiText('Save design changes?'),
        content: const UiText('Save these changes to this CV before leaving.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const UiText('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const UiText('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const UiText('Save'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'save' && !await _save()) return;
    if (!mounted) return;
    if (choice == 'discard') {
      widget.design.value = _saved;
      if (widget.titleController != null) {
        widget.titleController!.text = _savedTitle ?? '';
      }
    }
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final theme = base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(scrolledUnderElevation: 0),
    );
    return Theme(
      data: theme,
      child: ValueListenableBuilder<DocumentDesign>(
        valueListenable: widget.design,
        builder: (context, design, _) => PopScope(
          canPop: (!_dirty || _leaving) && !_saving,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _back();
          },
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                tooltip: context.ui('Back'),
                onPressed: _saving ? null : _back,
                icon: const Icon(AppIcons.back),
              ),
              title: const UiText(
                'CV Design Settings',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: AppTypography.semibold,
                ),
              ),
              actions: [
                if (widget.onExport != null)
                  IconButton(
                    tooltip: context.ui('Export PDF / Word'),
                    onPressed: _saving ? null : _export,
                    icon: const Icon(AppIcons.download),
                  ),
                IconButton(
                  tooltip: context.ui(_preview ? 'Customize CV' : 'Preview CV'),
                  onPressed: () => setState(() => _preview = !_preview),
                  icon: Icon(_preview ? AppIcons.customize : AppIcons.preview),
                ),
                IconButton(
                  tooltip: context.ui(_saving ? 'Saving' : 'Save design'),
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(AppIcons.check),
                ),
              ],
            ),
            body: SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, size) {
                  final settings = SingleChildScrollView(
                    key: PageStorageKey(
                      'cv-design-controls-${widget.document.id}',
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 580),
                        child: AbsorbPointer(
                          absorbing: _saving,
                          child: Column(
                            children: [
                              CvDesignControls(
                                design: design,
                                onChanged: (value) =>
                                    widget.design.value = value,
                              ),
                              if (widget.additionalControls != null)
                                widget.additionalControls!,
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                  final preview = _Preview(
                    document: widget.document.copyWith(design: design),
                    profile: widget.profile,
                  );
                  if (size.maxWidth >= 1000) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 430, child: settings),
                        Expanded(child: preview),
                      ],
                    );
                  }
                  return _preview ? preview : settings;
                },
              ),
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _preview = !_preview),
                        icon: Icon(
                          _preview ? AppIcons.customize : AppIcons.preview,
                        ),
                        label: UiText(_preview ? 'Customize CV' : 'Preview CV'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saving || !_dirty ? null : _save,
                        child: UiText(
                          _saving
                              ? 'Saving...'
                              : _dirty
                              ? 'Save changes'
                              : 'Saved',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.document, required this.profile});
  final CvDocument document;
  final UserProfile profile;
  @override
  Widget build(BuildContext context) {
    final resolved = ResolvedDocument.resolve(
      document: document,
      profile: profile,
      defaultTitle: defaultTitleResolver(document.isRtl ? 'ar' : 'en'),
    );
    // A fixed paper width keeps point sizes and margins accurate on phones.
    final page = document.design.page;
    final (shortSide, longSide) = switch (page.pageSize) {
      'letter' => (612.0, 792.0),
      'legal' => (612.0, 1008.0),
      _ => (595.28, 841.89),
    };
    final width = page.portrait ? shortSide : longSide;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        key: PageStorageKey('cv-design-preview-${document.id}'),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: UiText(
                'Live preview · pinch to zoom; exports paginate automatically',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ),
            SizedBox(
              width: constraints.maxWidth - 24,
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: width,
                    child: Directionality(
                      textDirection: document.design.isRtl
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      child: DocumentView(resolved: resolved),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
