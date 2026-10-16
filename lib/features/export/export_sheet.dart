/// The export workflow: choose a mode, review validation, generate, save/share.
///
/// The sheet never reports success unless the underlying operation actually
/// completed: generation errors, delivery cancellation and delivery failures
/// are surfaced distinctly.
library;

import 'package:flutter/material.dart';

import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/export/export_delivery.dart';
import 'package:cv_portfolio_maker/core/export/export_service.dart';
import 'package:cv_portfolio_maker/core/export/export_validation.dart';
import 'package:cv_portfolio_maker/core/export/image_bytes.dart';
import 'package:cv_portfolio_maker/core/l10n/app_strings.dart';
import 'package:cv_portfolio_maker/core/theme/app_tokens.dart';

/// Shared exporter. Images are fetched natively and embedded when available.
final DocumentExporter documentExporter = DocumentExporter(
  imageLoader: fetchImageBytes,
);

/// Platform delivery for generated files.
const ExportDelivery exportDelivery = ExportDelivery();

/// Maps a delivery outcome to the localisation key shown to the user.
///
/// A pure function so the success/cancel/failure wording is covered by tests
/// rather than only by the widget.
String deliveryMessageKey(DeliveryOutcome outcome) => outcome.completed
    ? 'exportShareSuccess'
    : (outcome.cancelled ? 'exportShareCancelled' : 'exportShareFailed');

/// Opens the export sheet for [document].
Future<void> showExportSheet(
  BuildContext context, {
  required CvDocument document,
  required UserProfile profile,
  ExportMode initialMode = ExportMode.designed,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _ExportSheet(
      document: document,
      profile: profile,
      initialMode: initialMode,
    ),
  );
}

class _ExportSheet extends StatefulWidget {
  const _ExportSheet({
    required this.document,
    required this.profile,
    required this.initialMode,
  });

  final CvDocument document;
  final UserProfile profile;
  final ExportMode initialMode;

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  late ExportMode _mode = widget.initialMode;
  ExportValidationResult? _validation;
  bool _validating = true;
  bool _busy = false;
  String? _errorKey;
  Map<String, String>? _errorArgs;
  String? _statusKey;
  Map<String, String>? _statusArgs;

  @override
  void initState() {
    super.initState();
    _validate();
  }

  Future<void> _validate() async {
    setState(() => _validating = true);
    try {
      final result = await documentExporter.validate(
        document: widget.document,
        profile: widget.profile,
        mode: _mode,
        languageCode: context.languageCode,
      );
      if (!mounted) return;
      setState(() {
        _validation = result;
        _validating = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _validating = false);
    }
  }

  /// Generates the PDF and hands it to the platform.
  Future<void> _run({required bool preview}) async {
    setState(() {
      _busy = true;
      _errorKey = null;
      _errorArgs = null;
      _statusKey = 'exportPreparing';
      _statusArgs = null;
    });

    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await documentExporter.export(
        document: widget.document,
        profile: widget.profile,
        mode: _mode,
        languageCode: context.languageCode,
      );
      if (!mounted) return;
      setState(() {
        _validation = result.validation;
        _statusKey = 'exportReady';
        _statusArgs = {'count': '${result.pageCount}'};
      });

      final outcome = preview
          ? await exportDelivery.preview(result.bytes, result.fileName)
          : await exportDelivery.share(result.bytes, result.fileName);
      if (!mounted) return;

      final messageKey = deliveryMessageKey(outcome);
      messenger.showSnackBar(SnackBar(content: Text(context.tr(messageKey))));
      setState(() {
        _busy = false;
        _statusKey = null;
        _statusArgs = null;
      });
    } on ExportException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusKey = null;
        _statusArgs = null;
        _errorKey = error.messageKey;
        _errorArgs = error.args;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusKey = null;
        _statusArgs = null;
        _errorKey = 'exportErrorGeneric';
        _errorArgs = null;
      });
    }
  }

  /// Generates and delivers the editable DOCX.
  ///
  /// Delivery goes through [ExportDelivery.saveDocument], which keeps the file
  /// typed as WordprocessingML on Android instead of the PDF media type the
  /// shared PDF route advertises.
  Future<void> _runDocx() async {
    setState(() {
      _busy = true;
      _errorKey = null;
      _errorArgs = null;
      _statusKey = 'exportPreparing';
      _statusArgs = null;
    });

    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await documentExporter.exportDocx(
        document: widget.document,
        profile: widget.profile,
        languageCode: context.languageCode,
      );
      if (!mounted) return;
      final outcome = await exportDelivery.saveDocument(
        result.bytes,
        result.fileName,
      );
      if (!mounted) return;
      final messageKey = deliveryMessageKey(outcome);
      messenger.showSnackBar(SnackBar(content: Text(context.tr(messageKey))));
    } on ExportException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorKey = error.messageKey;
        _errorArgs = error.args;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _errorKey = 'exportErrorGeneric');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _statusKey = null;
          _statusArgs = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final validation = _validation;
    final blocked = validation != null && !validation.canExport;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.tr('export'), style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<ExportMode>(
                segments: [
                  ButtonSegment(
                    value: ExportMode.designed,
                    label: Text(context.tr('exportModeDesigned')),
                    icon: const Icon(Icons.palette_outlined),
                  ),
                  ButtonSegment(
                    value: ExportMode.atsFriendly,
                    label: Text(context.tr('exportModeAts')),
                    icon: const Icon(Icons.checklist_outlined),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: _busy
                    ? null
                    : (selection) {
                        setState(() => _mode = selection.first);
                        _validate();
                      },
              ),
              if (_mode == ExportMode.atsFriendly) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  context.tr('exportAtsDisclaimer'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              if (_validating)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: LinearProgressIndicator(),
                )
              else if (validation != null)
                _ValidationList(validation: validation),
              if (_statusKey != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(context.tr(_statusKey!, args: _statusArgs)),
                    ),
                  ],
                ),
              ],
              if (_errorKey != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    context.tr(_errorKey!, args: _errorArgs),
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy || blocked
                          ? null
                          : () => _run(preview: true),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(context.tr('exportPreview')),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy || blocked
                          ? null
                          : () => _run(preview: false),
                      icon: const Icon(Icons.ios_share),
                      label: Text(context.tr('exportSaveShare')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy || blocked ? null : _runDocx,
                  icon: const Icon(Icons.description_outlined),
                  label: Text(context.tr('exportDocx')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders the validation findings with severity styling.
class _ValidationList extends StatelessWidget {
  const _ValidationList({required this.validation});

  final ExportValidationResult validation;

  @override
  Widget build(BuildContext context) {
    if (validation.isClean) return Text(context.tr('noWarnings'));
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final issue in validation.issues)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  switch (issue.level) {
                    ExportIssueLevel.error => Icons.error_outline,
                    ExportIssueLevel.warning => Icons.warning_amber_outlined,
                    ExportIssueLevel.info => Icons.info_outline,
                  },
                  size: 18,
                  color: switch (issue.level) {
                    ExportIssueLevel.error => scheme.error,
                    ExportIssueLevel.warning => scheme.tertiary,
                    ExportIssueLevel.info => scheme.outline,
                  },
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(context.tr(issue.code, args: issue.args))),
              ],
            ),
          ),
      ],
    );
  }
}
