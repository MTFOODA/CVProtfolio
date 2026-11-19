import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../core/design/templates.dart';
import '../core/domain/document_entity.dart';
import '../core/domain/enums.dart';
import '../core/domain/profile_models.dart';
import 'repositories.dart';

/// Pair identity is stable across retries and devices. Sharing and styling stay
/// on the portfolio; only the associated CV's saved content is synchronized.
Future<CvDocument> syncCvPortfolio(
  DocumentRepository backend,
  CvDocument cv, {
  List<CvDocument>? documents,
}) async {
  final all = documents ?? await backend.listDocuments(cv.ownerId);
  final cvs = all.where((d) => d.type == DocumentType.cv).toList()
    ..sort(
      (a, b) => (a.createdAtIso ?? a.id).compareTo(b.createdAtIso ?? b.id),
    );
  final portfolios = all.where((d) => d.type == DocumentType.portfolio);
  var existing = portfolios
      .where((d) => d.design.sourceCvId == cv.id)
      .firstOrNull;
  // Keep the existing shared URL when upgrading an account's first portfolio.
  if (existing == null && (cvs.isEmpty || cvs.first.id == cv.id)) {
    existing = portfolios.where((d) => d.design.sourceCvId == null).firstOrNull;
  }
  final profile =
      cv.profileSnapshot ??
      await (backend as ProfileRepository).loadProfile(cv.ownerId) ??
      UserProfile(id: cv.ownerId);
  final draft =
      existing ??
      CvDocument(
        id: const Uuid().v5(
          Namespace.url.value,
          'cv-portfolio:${cv.ownerId}:${cv.id}',
        ),
        ownerId: cv.ownerId,
        title: cv.title,
        type: DocumentType.portfolio,
        design: designForTemplate(
          'minimal',
          DocumentType.portfolio,
        ).copyWith(templateId: 'ocean'),
      );
  final updated = draft.copyWith(
    title: cv.title,
    profileSnapshot: profile,
    includedProjectIds: () => cv.includedProjectIds,
    isRtl: cv.isRtl,
    design: draft.design.copyWith(sourceCvId: cv.id),
  );
  if (existing != null &&
      jsonEncode(existing.toJson()) == jsonEncode(updated.toJson())) {
    return existing;
  }
  return backend.saveDocument(updated);
}

/// Upgrade existing CVs as well as newly saved ones, preserving an account's
/// existing portfolio URL on its original CV.
Future<CvDocument> syncOwnerCvPortfolios(
  DocumentRepository backend,
  CvDocument selected,
  List<CvDocument> documents, {
  bool Function()? isActive,
}) async {
  final current = [...documents];
  CvDocument? result;
  for (final cv in documents.where((d) => d.type == DocumentType.cv)) {
    if (isActive?.call() == false) {
      throw const UnauthorizedException('The active account has changed');
    }
    final paired = await syncCvPortfolio(backend, cv, documents: current);
    current.removeWhere((d) => d.id == paired.id);
    current.add(paired);
    if (cv.id == selected.id) result = paired;
  }
  return result!;
}
