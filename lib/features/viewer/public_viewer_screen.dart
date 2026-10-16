import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cv_portfolio_maker/app/providers.dart';
import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/core/export/export_service.dart';
import 'package:cv_portfolio_maker/core/l10n/app_strings.dart';
import 'package:cv_portfolio_maker/core/render/document_view.dart';
import 'package:cv_portfolio_maker/core/render/resolved_document.dart';
import 'package:cv_portfolio_maker/core/render/section_titles.dart';
import 'package:cv_portfolio_maker/core/theme/app_tokens.dart';
import 'package:cv_portfolio_maker/data/repositories.dart';
import 'package:cv_portfolio_maker/features/export/export_sheet.dart';

/// Read-only public viewer for a published document.
///
/// Access is only granted through [ShareRepository.resolveBySlug] or
/// [ShareRepository.resolveByToken], which enforce publication, revocation and
/// expiry server-side. Rendering is delegated to the shared [DocumentView] so
/// the public page shows exactly the owner's saved layout and design.
class PublicViewerScreen extends ConsumerStatefulWidget {
  const PublicViewerScreen({super.key, this.slug, this.token});

  final String? slug;
  final String? token;

  @override
  ConsumerState<PublicViewerScreen> createState() => _PublicViewerScreenState();
}

class _PublicViewerScreenState extends ConsumerState<PublicViewerScreen> {
  ResolvedDocument? _resolved;
  CvDocument? _document;
  UserProfile? _profile;
  bool _loading = true;
  bool _downloading = false;
  String? _errorKey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorKey = null;
    });
    try {
      final backend = ref.read(backendProvider);
      final ({CvDocument document, UserProfile profile})? resolved;
      if (widget.slug != null) {
        resolved = await backend.resolveBySlug(widget.slug!);
      } else if (widget.token != null) {
        resolved = await backend.resolveByToken(widget.token!);
      } else {
        resolved = null;
      }

      if (resolved == null) {
        if (!mounted) return;
        setState(() {
          _errorKey = 'notFoundBody';
          _loading = false;
        });
        return;
      }

      final languageCode = resolved.document.isRtl ? 'ar' : 'en';
      final sourceDocument = resolved.document;
      final sourceProfile = resolved.profile;
      final document = ResolvedDocument.resolve(
        document: sourceDocument,
        profile: sourceProfile,
        defaultTitle: defaultTitleResolver(languageCode),
      );
      if (!mounted) return;
      setState(() {
        _resolved = document;
        _document = sourceDocument;
        _profile = sourceProfile;
        _loading = false;
      });
    } on ShareNotFoundException {
      if (!mounted) return;
      setState(() {
        _errorKey = 'notFoundBody';
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _errorKey = 'errorGeneric';
        _loading = false;
      });
    }
  }

  /// Generates and delivers the published PDF, when the owner allows it.
  ///
  /// Uses the same authorised document and profile returned by the share
  /// resolution, so a viewer can never reach anything beyond the published
  /// document.
  Future<void> _download() async {
    final document = _document;
    final profile = _profile;
    if (document == null || profile == null) return;
    setState(() => _downloading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await documentExporter.export(
        document: document,
        profile: profile,
        mode: ExportMode.designed,
        languageCode: document.isRtl ? 'ar' : 'en',
      );
      final outcome = await exportDelivery.share(result.bytes, result.fileName);
      if (!mounted) return;
      final key = outcome.completed
          ? 'exportShareSuccess'
          : (outcome.cancelled ? 'exportShareCancelled' : 'exportShareFailed');
      messenger.showSnackBar(SnackBar(content: Text(context.tr(key))));
    } on ExportException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr(error.messageKey, args: error.args))),
      );
    } on Object {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('exportErrorGeneric'))),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final resolved = _resolved;
    if (_errorKey != null || resolved == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  context.tr(_errorKey ?? 'notFoundBody'),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(resolved.document.title),
        actions: [
          if (resolved.document.allowPdfDownload)
            IconButton(
              tooltip: context.tr('downloadPdf'),
              icon: _downloading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              onPressed: _downloading ? null : _download,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: DocumentView(resolved: resolved),
          ),
        ),
      ),
    );
  }
}
