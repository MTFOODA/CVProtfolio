import '../../core/design/app_icons.dart';

import 'package:cv_portfolio_maker/core/l10n/ui_text.dart';
import 'package:url_launcher/url_launcher.dart';

import '../portfolio/public_portfolio_view.dart';

import 'package:flutter/material.dart';

import '../../core/widgets/app_surfaces.dart';

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
  bool _requiresPassword = false;
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
          _requiresPassword = widget.slug != null;
          _errorKey = widget.slug != null ? null : 'notFoundBody';
          _loading = false;
        });
        return;
      }

      final languageCode = resolved.document.isRtl ? 'ar' : 'en';
      final sourceDocument = resolved.document;
      final sourceProfile = resolved.profile;
      ref.invalidate(sharesProvider(sourceDocument.ownerId));
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
      // A protected document is indistinguishable from an unknown slug by
      // design, so the visitor is offered the password prompt rather than
      // told anything about the underlying record.
      setState(() {
        _requiresPassword = widget.slug != null;
        _errorKey = widget.slug != null ? null : 'notFoundBody';
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

  /// Verifies a visitor password and loads the published document on success.
  ///
  /// The check runs in the backend (Postgres `crypt` for Supabase), never in
  /// this widget, so there is no client-side bypass.
  Future<void> _unlock(String password) async {
    final slug = widget.slug;
    if (slug == null) return;
    setState(() {
      _loading = true;
      _errorKey = null;
    });
    try {
      final resolved = await ref
          .read(backendProvider)
          .resolveBySlugWithPassword(slug, password);
      if (!mounted) return;
      if (resolved == null) {
        setState(() {
          _loading = false;
          _requiresPassword = true;
          _errorKey = 'accessDeniedBody';
        });
        return;
      }
      final languageCode = resolved.document.isRtl ? 'ar' : 'en';
      ref.invalidate(sharesProvider(resolved.document.ownerId));
      final document = ResolvedDocument.resolve(
        document: resolved.document,
        profile: resolved.profile,
        defaultTitle: defaultTitleResolver(languageCode),
      );
      setState(() {
        _resolved = document;
        _document = resolved.document;
        _profile = resolved.profile;
        _requiresPassword = false;
        _loading = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _requiresPassword = true;
        _errorKey = 'accessDeniedBody';
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

  Future<void> _openLink(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      /* Report below. */
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: UiText('Could not open this link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: AppLoading());
    }
    if (_requiresPassword) {
      return _PasswordGate(hasError: _errorKey != null, onSubmit: _unlock);
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
                  AppIcons.lock,
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

    if (resolved.document.type == DocumentType.portfolio) {
      return PublicPortfolioView(
        document: _document!,
        profile: _profile!,
        resolved: resolved,
        onOpen: _openLink,
        onDownload: _download,
        downloading: _downloading,
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
                  : const Icon(AppIcons.download),
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

/// Asks the visitor for the portfolio password.
///
/// The outcome is decided by the backend; this widget only collects the value
/// and reports success or failure. It never inspects a stored hash.
class _PasswordGate extends StatefulWidget {
  const _PasswordGate({required this.hasError, required this.onSubmit});

  final bool hasError;
  final Future<void> Function(String) onSubmit;

  @override
  State<_PasswordGate> createState() => _PasswordGateState();
}

class _PasswordGateState extends State<_PasswordGate> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _controller.text;
    if (password.isEmpty || _busy) return;
    setState(() => _busy = true);
    await widget.onSubmit(password);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    AppIcons.lock,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    context.tr('visitorAccess'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    context.tr('accessDeniedBody'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextField(
                    controller: _controller,
                    obscureText: _obscure,
                    autofocus: true,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: context.tr('enterPassword'),
                      hintText: context.tr('visitorPasswordPlaceholder'),
                      errorText: widget.hasError
                          ? context.tr('accessDenied')
                          : null,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? AppIcons.preview : AppIcons.hidden,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.tr('continue')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
