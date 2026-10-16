import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cv_portfolio_maker/app/providers.dart';
import 'package:cv_portfolio_maker/app/session.dart';
import 'package:cv_portfolio_maker/core/design/templates.dart';
import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/document_models.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/l10n/app_strings.dart';
import 'package:cv_portfolio_maker/core/render/document_view.dart';
import 'package:cv_portfolio_maker/core/render/resolved_document.dart';
import 'package:cv_portfolio_maker/core/render/section_titles.dart';
import 'package:cv_portfolio_maker/core/theme/app_tokens.dart';
import 'package:cv_portfolio_maker/features/export/export_sheet.dart';

/// Universal layout designer: edits a document's title, sections, column
/// layout and visual design with a live preview backed by [DocumentView].
class DocumentEditorScreen extends ConsumerStatefulWidget {
  const DocumentEditorScreen({super.key, required this.documentId});

  final String documentId;

  @override
  ConsumerState<DocumentEditorScreen> createState() =>
      _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends ConsumerState<DocumentEditorScreen> {
  static const _fonts = <String>[
    'inter',
    'merriweather',
    'lora',
    'poppins',
    'playfairdisplay',
    'jetbrainsmono',
  ];

  static const _swatches = <int>[
    0xFF111827,
    0xFF1F2933,
    0xFF0F172A,
    0xFF18181B,
    0xFF4B5563,
    0xFF2563EB,
    0xFF06B6D4,
    0xFF7C3AED,
    0xFFEC4899,
    0xFFF59E0B,
    0xFF10B981,
    0xFFEF4444,
    0xFF78350F,
    0xFF0EA5E9,
    0xFFFFFFFF,
    0xFFF3F4F6,
    0xFFE5E7EB,
    0xFF000000,
  ];

  CvDocument? _document;
  UserProfile? _profile;
  DocumentDesign _design = const DocumentDesign();
  late final TextEditingController _titleController;

  bool _loading = true;
  bool _saving = false;
  bool _previewMode = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = ref.read(sessionProvider2).value?.id;
    if (userId == null) {
      setState(() {
        _loading = false;
        _loadError = context.tr('errorGeneric');
      });
      return;
    }
    final doc = await ref
        .read(backendProvider)
        .loadDocument(widget.documentId, userId);
    if (!mounted) return;
    if (doc == null) {
      setState(() {
        _loading = false;
        _loadError = context.tr('notFoundTitle');
      });
      return;
    }
    final profile = await ref.read(backendProvider).loadProfile(userId);
    if (!mounted) return;
    setState(() {
      _document = doc;
      _profile = profile;
      _design = doc.design;
      _titleController.text = doc.title;
      _loading = false;
    });
  }

  /// Persists the current editor state.
  ///
  /// Returns `true` only when the write actually succeeded; callers must not
  /// report success otherwise.
  Future<bool> _save() async {
    final doc = _document;
    if (doc == null) return false;
    setState(() => _saving = true);

    final title = _titleController.text.trim();
    final updated = doc.copyWith(
      title: title.isEmpty ? doc.title : title,
      design: _design,
      updatedAtIso: () => DateTime.now().toIso8601String(),
      version: doc.version + 1,
    );

    try {
      final saved = await ref.read(backendProvider).saveDocument(updated);
      if (!mounted) return true;
      setState(() {
        _document = saved;
        _design = saved.design;
        _saving = false;
      });
      ref.invalidate(documentsProvider);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('saved'))));
      return true;
    } on Object {
      if (!mounted) return false;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('errorGeneric'))));
      return false;
    }
  }

  /// Saves, then opens the export sheet.
  ///
  /// Saving first guarantees the generated file matches the persisted document
  /// and that export never silently applies an unsaved draft.
  Future<void> _openExport() async {
    final doc = _document;
    if (doc == null) return;
    final saved = await _save();
    if (!saved || !mounted) return;
    final document = _document;
    if (document == null) return;
    await showExportSheet(
      context,
      document: document,
      profile: _profile ?? UserProfile(id: document.ownerId),
    );
  }

  /// Rebuilds the preview using the current, unsaved [DocumentDesign].
  ResolvedDocument? _previewResolved() {
    final doc = _document;
    final profile = _profile;
    if (doc == null) return null;
    final previewDoc = doc.copyWith(design: _design);
    final previewProfile = profile ?? UserProfile(id: doc.ownerId);
    return ResolvedDocument.resolve(
      document: previewDoc,
      profile: previewProfile,
      defaultTitle: defaultTitleResolver(context.languageCode),
    );
  }

  void _setLayoutMode(LayoutMode mode) {
    setState(() => _design = _design.copyWith(layoutMode: mode));
  }

  void _setSections(List<SectionConfig> sections) {
    setState(() => _design = _design.copyWith(sections: sections));
  }

  void _updateSection(int index, SectionConfig Function(SectionConfig) fn) {
    final sections = List<SectionConfig>.of(_design.sections);
    sections[index] = fn(sections[index]);
    _setSections(sections);
  }

  void _moveSection(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _design.sections.length) return;
    final sections = List<SectionConfig>.of(_design.sections);
    final item = sections.removeAt(index);
    sections.insert(target, item);
    _setSections(sections);
  }

  /// Adds a section to the document configuration.
  ///
  /// Entry-backed sections may appear at most once (their entries already live
  /// in the profile); page breaks and custom sections can repeat.
  void _addSection(SectionKind kind) {
    String id;
    String? customSectionId;

    if (kind == SectionKind.custom) {
      final used = _design.sections
          .map((s) => s.customSectionId)
          .whereType<String>()
          .toSet();
      final available = (_profile?.customSections ?? const <CustomSection>[])
          .where((c) => !used.contains(c.id))
          .toList();
      if (available.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr('noCustomSections'))));
        return;
      }
      customSectionId = available.first.id;
      id = 'custom_$customSectionId';
    } else if (kind == SectionKind.pageBreak) {
      id = 'pagebreak_${DateTime.now().microsecondsSinceEpoch}';
    } else {
      id = kind.name;
    }

    if (_design.sections.any((s) => s.id == id)) return;

    final slot = _design.layoutMode == LayoutMode.one
        ? ColumnSlot.fullWidth
        : ColumnSlot.left;
    setState(
      () => _design = _design.copyWith(
        sections: [
          ..._design.sections,
          SectionConfig(
            id: id,
            kind: kind,
            slot: slot,
            customSectionId: customSectionId,
          ),
        ],
      ),
    );
  }

  /// Removes a section from the document configuration.
  ///
  /// Only the *configuration* is removed; the underlying profile content is
  /// untouched and can be re-added later.
  void _removeSection(int index) {
    final sections = List<SectionConfig>.of(_design.sections)..removeAt(index);
    _setSections(sections);
  }

  void _resetToTemplate() {
    final doc = _document;
    if (doc == null) return;
    setState(() => _design = designForTemplate(_design.templateId, doc.type));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_loadError!)),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_document!.title),
        actions: [
          IconButton(
            icon: Icon(
              _previewMode ? Icons.edit_outlined : Icons.visibility_outlined,
            ),
            tooltip: _previewMode ? context.tr('edit') : context.tr('preview'),
            onPressed: () => setState(() => _previewMode = !_previewMode),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: context.tr('export'),
            onPressed: _saving ? null : _openExport,
          ),
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? context.tr('saving') : context.tr('save')),
          ),
        ],
      ),
      body: _previewMode ? _buildPreview() : _buildEditor(),
    );
  }

  Widget _buildPreview() {
    final resolved = _previewResolved();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: resolved == null
              ? const SizedBox.shrink()
              : DocumentView(resolved: resolved),
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final controls = _buildControls();
        if (constraints.maxWidth >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 420, child: controls),
              const VerticalDivider(width: 1),
              Expanded(child: _buildPreview()),
            ],
          );
        }
        return controls;
      },
    );
  }

  Widget _buildControls() {
    final resolver = defaultTitleResolver(context.languageCode);
    return ReorderableListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      buildDefaultDragHandles: true,
      onReorderItem: _reorderSections,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('documentTitle'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(hintText: context.tr('documentTitle')),
          ),
          _sectionHeader(context, 'layout'),
          _buildLayoutControls(context),
          _sectionHeader(context, 'sectionLayout'),
        ],
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, 'addSection'),
          _buildAddSectionChips(context, resolver),
          _sectionHeader(context, 'designControls'),
          _buildDesignControls(context),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
      children: [
        for (var i = 0; i < _design.sections.length; i++)
          _buildSectionTile(
            context,
            i,
            resolver,
            key: ValueKey('section-${_design.sections[i].id}'),
          ),
      ],
    );
  }

  /// Applies a drag-and-drop reorder.
  ///
  /// [ReorderableListView.onReorderItem] already adjusts [newIndex] for the
  /// removed item, so no `-1` correction is applied here.
  void _reorderSections(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    if (oldIndex < 0 || oldIndex >= _design.sections.length) return;
    if (newIndex < 0 || newIndex >= _design.sections.length) return;
    setState(() {
      final sections = List<SectionConfig>.of(_design.sections);
      final item = sections.removeAt(oldIndex);
      sections.insert(newIndex, item);
      _design = _design.copyWith(sections: sections);
    });
  }

  /// Quick-add chips for every section kind a document may contain.
  Widget _buildAddSectionChips(
    BuildContext context,
    String Function(SectionKind) resolver,
  ) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final kind in addableSections)
          ActionChip(
            avatar: Icon(_sectionIcon(kind), size: 16),
            label: Text(resolver(kind)),
            onPressed: () => _addSection(kind),
          ),
      ],
    );
  }

  static IconData _sectionIcon(SectionKind kind) => switch (kind) {
    SectionKind.pageBreak => Icons.insert_page_break_outlined,
    SectionKind.custom => Icons.tune,
    SectionKind.projects => Icons.folder_outlined,
    SectionKind.skills => Icons.star_outline,
    SectionKind.languages => Icons.translate,
    SectionKind.certificates => Icons.workspace_premium_outlined,
    SectionKind.courses => Icons.menu_book_outlined,
    SectionKind.awards => Icons.emoji_events_outlined,
    SectionKind.volunteer => Icons.volunteer_activism_outlined,
    SectionKind.publications => Icons.article_outlined,
    SectionKind.references => Icons.people_outline,
    SectionKind.education => Icons.school_outlined,
    _ => Icons.work_outline,
  };

  Widget _sectionHeader(BuildContext context, String labelKey) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Text(
        context.tr(labelKey),
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  Widget _buildLayoutControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<LayoutMode>(
          segments: [
            ButtonSegment(
              value: LayoutMode.one,
              label: Text(context.tr('oneColumn')),
            ),
            ButtonSegment(
              value: LayoutMode.two,
              label: Text(context.tr('twoColumns')),
            ),
            ButtonSegment(
              value: LayoutMode.mix,
              label: Text(context.tr('mixedLayout')),
            ),
          ],
          selected: {_design.layoutMode},
          onSelectionChanged: (s) => _setLayoutMode(s.first),
        ),
        if (_design.layoutMode != LayoutMode.one) ...[
          const SizedBox(height: AppSpacing.md),
          _SliderRow(
            label: context.tr('columns'),
            value: _design.spacing.leftColumnRatio,
            min: 0.25,
            max: 0.75,
            divisions: 10,
            display: '${(_design.spacing.leftColumnRatio * 100).round()}%',
            onChanged: (v) => setState(
              () => _design = _design.copyWith(
                spacing: _design.spacing.copyWith(leftColumnRatio: v),
              ),
            ),
          ),
          _SliderRow(
            label: context.tr('columnGap'),
            value: _design.spacing.columnGap,
            min: 8,
            max: 48,
            divisions: 20,
            display: '${_design.spacing.columnGap.round()}',
            onChanged: (v) => setState(
              () => _design = _design.copyWith(
                spacing: _design.spacing.copyWith(columnGap: v),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionTile(
    BuildContext context,
    int index,
    String Function(SectionKind) resolver, {
    Key? key,
  }) {
    final section = _design.sections[index];
    // Column placement is meaningless in a single-column layout.
    final canPlace = _design.layoutMode != LayoutMode.one;
    return Card(
      key: key,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    resolver(section.kind),
                    style: section.visible
                        ? Theme.of(context).textTheme.bodyLarge
                        : Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).disabledColor,
                          ),
                  ),
                ),
                Tooltip(
                  message: canPlace ? '' : context.tr('columnPlacementHint'),
                  child: DropdownButton<ColumnSlot>(
                    value: section.slot,
                    onChanged: canPlace
                        ? (slot) {
                            if (slot != null) {
                              _updateSection(
                                index,
                                (s) => s.copyWith(slot: slot),
                              );
                            }
                          }
                        : null,
                    items: const [
                      DropdownMenuItem(
                        value: ColumnSlot.fullWidth,
                        child: Text('Full'),
                      ),
                      DropdownMenuItem(
                        value: ColumnSlot.left,
                        child: Text('Left'),
                      ),
                      DropdownMenuItem(
                        value: ColumnSlot.right,
                        child: Text('Right'),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: section.visible,
                  onChanged: (_) => _updateSection(
                    index,
                    (s) => s.copyWith(visible: !s.visible),
                  ),
                ),
                Tooltip(
                  message: context.tr('dragToReorder'),
                  child: Icon(
                    Icons.drag_indicator,
                    color: Theme.of(context).disabledColor,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: index > 0 ? () => _moveSection(index, -1) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: index < _design.sections.length - 1
                      ? () => _moveSection(index, 1)
                      : null,
                ),
                IconButton(
                  tooltip: context.tr('removeSection'),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _removeSection(index),
                ),
              ],
            ),
            if (section.kind != SectionKind.pageBreak)
              TextFormField(
                key: ValueKey(section.id),
                initialValue: section.customTitle ?? '',
                decoration: InputDecoration(
                  hintText: context.tr('sectionTitle'),
                  isDense: true,
                ),
                onChanged: (value) => _updateSection(
                  index,
                  (s) => s.copyWith(customTitle: () => value),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesignControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildColorControls(context),
        const SizedBox(height: AppSpacing.lg),
        _buildTypographyControls(context),
        const SizedBox(height: AppSpacing.lg),
        _buildSpacingControls(context),
        const SizedBox(height: AppSpacing.lg),
        _buildPagePresentationControls(context),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: _resetToTemplate,
          icon: const Icon(Icons.restart_alt),
          label: Text(context.tr('resetToTemplate')),
        ),
      ],
    );
  }

  Widget _buildColorControls(BuildContext context) {
    final colors = _design.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('colors'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        _ColorPicker(
          label: context.tr('primaryColor'),
          value: colors.primary,
          onChanged: (v) => setState(
            () =>
                _design = _design.copyWith(colors: colors.copyWith(primary: v)),
          ),
        ),
        _ColorPicker(
          label: context.tr('accentColor'),
          value: colors.accent,
          onChanged: (v) => setState(
            () =>
                _design = _design.copyWith(colors: colors.copyWith(accent: v)),
          ),
        ),
        _ColorPicker(
          label: context.tr('paperColor'),
          value: colors.paper,
          onChanged: (v) => setState(
            () => _design = _design.copyWith(colors: colors.copyWith(paper: v)),
          ),
        ),
        _ColorPicker(
          label: 'Text',
          value: colors.headingText,
          onChanged: (v) => setState(
            () => _design = _design.copyWith(
              colors: colors.copyWith(headingText: v, bodyText: v),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypographyControls(BuildContext context) {
    final typography = _design.typography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('typography'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        _DropdownRow(
          label: context.tr('fontFamily'),
          value: typography.headingFont,
          options: _fonts,
          onChanged: (v) => setState(
            () => _design = _design.copyWith(
              typography: typography.copyWith(headingFont: v, bodyFont: v),
            ),
          ),
        ),
        _SliderRow(
          label: 'Heading size',
          value: typography.headingFontSize,
          min: 14,
          max: 40,
          divisions: 26,
          display: '${typography.headingFontSize.round()}',
          onChanged: (v) => setState(
            () => _design = _design.copyWith(
              typography: typography.copyWith(headingFontSize: v),
            ),
          ),
        ),
        _SliderRow(
          label: 'Body size',
          value: typography.bodyFontSize,
          min: 8,
          max: 16,
          divisions: 16,
          display: typography.bodyFontSize.toStringAsFixed(1),
          onChanged: (v) => setState(
            () => _design = _design.copyWith(
              typography: typography.copyWith(bodyFontSize: v),
            ),
          ),
        ),
        _SliderRow(
          label: 'Line height',
          value: typography.bodyLineHeight,
          min: 1.0,
          max: 2.0,
          divisions: 20,
          display: typography.bodyLineHeight.toStringAsFixed(2),
          onChanged: (v) => setState(
            () => _design = _design.copyWith(
              typography: typography.copyWith(bodyLineHeight: v),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpacingControls(BuildContext context) {
    final spacing = _design.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('spacing'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        _SliderRow(
          label: context.tr('margins'),
          value: spacing.pageMargin,
          min: 12,
          max: 80,
          divisions: 34,
          display: '${spacing.pageMargin.round()}',
          onChanged: (v) => setState(
            () => _design = _design.copyWith(
              spacing: spacing.copyWith(pageMargin: v),
            ),
          ),
        ),
        _SliderRow(
          label: context.tr('sectionSpacing'),
          value: spacing.sectionSpacing,
          min: 4,
          max: 48,
          divisions: 22,
          display: '${spacing.sectionSpacing.round()}',
          onChanged: (v) => setState(
            () => _design = _design.copyWith(
              spacing: spacing.copyWith(sectionSpacing: v),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPagePresentationControls(BuildContext context) {
    final page = _design.page;
    final presentation = _design.presentation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('pageSize'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        _DropdownRow(
          label: context.tr('pageSize'),
          value: page.pageSize,
          options: const ['a4', 'letter', 'legal'],
          onChanged: (v) => setState(
            () => _design = _design.copyWith(page: page.copyWith(pageSize: v)),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('pageNumbers')),
          value: page.showPageNumbers,
          onChanged: (v) => setState(
            () => _design = _design.copyWith(
              page: page.copyWith(showPageNumbers: v),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          context.tr('divider'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        _DropdownRow(
          label: context.tr('divider'),
          value: presentation.dividerStyle.name,
          options: DividerStyle.values.map((e) => e.name).toList(),
          onChanged: (v) => setState(
            () => _design = _design.copyWith(
              presentation: presentation.copyWith(
                dividerStyle: DividerStyle.values.byName(v),
              ),
            ),
          ),
        ),
        _DropdownRow(
          label: context.tr('avatarShape'),
          value: presentation.avatarShape.name,
          options: AvatarShape.values.map((e) => e.name).toList(),
          onChanged: (v) => setState(
            () => _design = _design.copyWith(
              presentation: presentation.copyWith(
                avatarShape: AvatarShape.values.byName(v),
              ),
            ),
          ),
        ),
        _DropdownRow(
          label: 'Header',
          value: presentation.headerStyle,
          options: const ['left', 'center', 'split'],
          onChanged: (v) => setState(
            () => _design = _design.copyWith(
              presentation: presentation.copyWith(headerStyle: v),
            ),
          ),
        ),
        _DropdownRow(
          label: 'Projects',
          value: presentation.projectCardStyle,
          options: const ['card', 'flat', 'gallery'],
          onChanged: (v) => setState(
            () => _design = _design.copyWith(
              presentation: presentation.copyWith(projectCardStyle: v),
            ),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Contact inline'),
          value: presentation.contactInline,
          onChanged: (v) => setState(
            () => _design = _design.copyWith(
              presentation: presentation.copyWith(contactInline: v),
            ),
          ),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label)),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          SizedBox(width: 44, child: Text(display, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label)),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final swatch in _DocumentEditorScreenState._swatches)
                  GestureDetector(
                    onTap: () => onChanged(swatch),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Color(swatch),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: swatch == value
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownRow extends StatelessWidget {
  const _DropdownRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label)),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: options.contains(value) ? value : options.first,
              isExpanded: true,
              items: [
                for (final o in options)
                  DropdownMenuItem(value: o, child: Text(o)),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}
