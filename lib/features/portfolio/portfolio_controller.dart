import '../../data/portfolio_documents.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/session.dart';
import '../../core/design/templates.dart';
import '../../core/design/portfolio_themes.dart';
import '../../core/domain/document_entity.dart';
import '../../core/domain/enums.dart';
import '../../core/utils/utils.dart';
import '../../data/repositories.dart';

final portfolioProvider =
    AsyncNotifierProvider<PortfolioController, CvDocument?>(
      PortfolioController.new,
    );

final portfolioCvIdProvider = NotifierProvider<PortfolioCvSelection, String?>(
  PortfolioCvSelection.new,
);

class PortfolioCvSelection extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(sessionProvider2.select((value) => value.value?.id));
    return null;
  }

  void select(String id) => state = id;
}

/// Owns the selected CV's independent portfolio settings and share identity.
class PortfolioController extends AsyncNotifier<CvDocument?> {
  String? _creatingFor;
  Future<CvDocument>? _creating;
  bool _active(String owner) =>
      ref.mounted && ref.read(sessionProvider2).value?.id == owner;
  void _requireOwner(String owner) {
    if (!_active(owner)) {
      throw const UnauthorizedException('The active account has changed');
    }
  }

  @override
  Future<CvDocument?> build() async {
    final user = await ref.watch(sessionProvider2.future);
    if (user == null) return null;
    final selectedCvId = ref.watch(portfolioCvIdProvider);
    final documents = await ref.watch(documentsProvider(user.id).future);
    if (!_active(user.id)) return null;
    final cvs = documents.where((d) => d.type == DocumentType.cv).toList();
    if (cvs.isNotEmpty) {
      final cv =
          cvs.where((d) => d.id == selectedCvId).firstOrNull ?? cvs.first;
      final key = '${user.id}:${cv.id}';
      final pending = _creatingFor == key ? _creating : null;
      final request =
          pending ??
          syncOwnerCvPortfolios(
            ref.read(backendProvider),
            cv,
            documents,
            isActive: () => _active(user.id),
          );
      _creatingFor = key;
      _creating = request;
      try {
        final paired = await request;
        if (_active(user.id) &&
            cvs.any(
              (cv) => !documents.any(
                (d) =>
                    d.type == DocumentType.portfolio &&
                    d.design.sourceCvId == cv.id,
              ),
            )) {
          ref.invalidate(documentsProvider(user.id));
        }
        return paired.copyWith(
          design: paired.design.copyWith(
            templateId: portfolioThemeById(paired.design.templateId).id,
            sections: paired.design.sections.isEmpty
                ? defaultSections(isPortfolio: true)
                : paired.design.sections,
          ),
        );
      } finally {
        if (identical(_creating, request)) {
          _creating = null;
          _creatingFor = null;
        }
      }
    }
    for (final document in documents) {
      if (document.type == DocumentType.portfolio) {
        if (_creatingFor == user.id) {
          _creatingFor = null;
          _creating = null;
        }
        return document.copyWith(
          design: document.design.copyWith(
            templateId: portfolioThemeById(document.design.templateId).id,
            sections: document.design.sections.isEmpty
                ? defaultSections(isPortfolio: true)
                : document.design.sections,
          ),
        );
      }
    }
    final pending = _creatingFor == user.id ? _creating : null;
    final request =
        pending ??
        ref
            .read(backendProvider)
            .saveDocument(
              CvDocument(
                id: newId(),
                ownerId: user.id,
                title: 'My Portfolio',
                type: DocumentType.portfolio,
                design: designForTemplate(
                  'minimal',
                  DocumentType.portfolio,
                ).copyWith(templateId: 'ocean'),
              ),
            );
    _creatingFor = user.id;
    _creating = request;
    final CvDocument created;
    try {
      created = await request;
    } catch (_) {
      if (identical(_creating, request)) {
        _creating = null;
        _creatingFor = null;
      }
      rethrow;
    }
    // Keep the dashboard and a subsequent reload aware of the new draft.
    if (_active(user.id)) ref.invalidate(documentsProvider(user.id));
    return created;
  }

  Future<void> save(CvDocument updated) async {
    _requireOwner(updated.ownerId);
    final previous = state;
    state = AsyncData(updated);
    try {
      final saved = await ref
          .read(backendProvider)
          .saveDocument(
            updated.copyWith(
              updatedAtIso: () => DateTime.now().toIso8601String(),
            ),
          );
      if (_active(updated.ownerId) && state.value?.id == updated.id) {
        state = AsyncData(saved);
        ref.invalidate(documentsProvider(updated.ownerId));
      }
    } catch (_) {
      if (_active(updated.ownerId) && state.value?.id == updated.id) {
        state = previous;
      }
      rethrow;
    }
  }

  Future<void> publish() async {
    final document = state.requireValue!;
    _requireOwner(document.ownerId);
    final backend = ref.read(backendProvider);
    final slug = document.publicSlug ?? newSlug('pf');
    final shares = await backend.listSharesForOwner(document.ownerId);
    _requireOwner(document.ownerId);
    if (!shares.any(
      (s) =>
          s.documentId == document.id &&
          s.slug == slug &&
          s.mode == ShareMode.publicLink &&
          s.isActive,
    )) {
      await backend.saveShare(
        DocumentShare(
          id: newId(),
          documentId: document.id,
          slug: slug,
          mode: ShareMode.publicLink,
          createdAtIso: DateTime.now().toIso8601String(),
        ),
      );
    }
    await save(
      document.copyWith(
        published: true,
        shareMode: ShareMode.publicLink,
        publicSlug: () => slug,
      ),
    );
    if (_active(document.ownerId)) {
      ref.invalidate(sharesProvider(document.ownerId));
    }
  }

  Future<void> setPassword(String? password) async {
    final document = state.requireValue!;
    _requireOwner(document.ownerId);
    final saved = await ref
        .read(backendProvider)
        .setAccessPassword(
          documentId: document.id,
          userId: document.ownerId,
          password: password,
        );
    if (_active(document.ownerId) && state.value?.id == document.id) {
      state = AsyncData(saved);
      ref.invalidate(documentsProvider(document.ownerId));
    }
  }
}

/// Only absolute web links may leave the app. Never launch script/file URLs.
Uri? portfolioWebUri(String? value) {
  final uri = Uri.tryParse(value?.trim() ?? '');
  if (uri == null ||
      !['https', 'http'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

/// Local drafts and placeholder deployment hosts cannot produce share links.
String? portfolioShareUrl(
  CvDocument document,
  String base, {
  required bool local,
}) {
  final uri = portfolioWebUri(base);
  final slug = document.publicSlug?.trim() ?? '';
  if (local ||
      !document.published ||
      document.shareMode != ShareMode.publicLink ||
      slug.isEmpty ||
      uri == null ||
      uri.host.endsWith('.example.com') ||
      uri.host == 'example.com') {
    return null;
  }
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    pathSegments: [...uri.pathSegments.where((s) => s.isNotEmpty), 'p', slug],
  ).toString();
}
