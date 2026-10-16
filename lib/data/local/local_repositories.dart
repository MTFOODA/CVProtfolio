/// On-device implementation of the persistence contracts.
///
/// Used when Supabase credentials are absent, and for tests. Ownership checks
/// are still enforced here so the same security expectations hold locally.
library;

import 'dart:io';

import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/data/repositories.dart';

import 'local_store.dart';

/// In-memory + on-disk local backend.
class LocalBackend
    implements
        ProfileRepository,
        DocumentRepository,
        ShareRepository,
        MediaRepository,
        AccountRepository {
  LocalBackend(this._store);

  final LocalStore _store;

  static const String _profileKey = 'profiles';
  static const String _documentKey = 'documents';
  static const String _shareKey = 'shares';

  String _profileScope(String userId) => '${_profileKey}_$userId';
  String _documentScope(String userId) => '${_documentKey}_$userId';

  /// Exposes the store root so share resolution can scan all documents.
  Directory get rootDirectory => _store.rootDirectory;

  // ---------------------------------------------------------------- profiles

  @override
  Future<UserProfile?> loadProfile(String userId) async {
    final map = await _store.readMap(_profileScope(userId));
    return map == null ? null : UserProfile.fromJson(map);
  }

  @override
  Future<UserProfile> saveProfile(UserProfile profile) async {
    await _store.writeMap(_profileScope(profile.id), profile.toJson());
    return profile;
  }

  // --------------------------------------------------------------- documents

  @override
  Future<List<CvDocument>> listDocuments(String userId) async {
    final rows = await _store.readList(_documentScope(userId));
    final documents = rows.map(CvDocument.fromJson).toList()
      ..sort((a, b) => (b.updatedAtIso ?? '').compareTo(a.updatedAtIso ?? ''));
    return documents;
  }

  @override
  Future<CvDocument?> loadDocument(String documentId, String userId) async {
    for (final document in await listDocuments(userId)) {
      if (document.id == documentId) return document;
    }
    return null;
  }

  @override
  Future<CvDocument> saveDocument(CvDocument document) async {
    final documents = await _store.readList(_documentScope(document.ownerId));
    final index = documents.indexWhere((d) => d['id'] == document.id);
    final json = document.toJson();
    if (index >= 0) {
      documents[index] = json;
    } else {
      documents.add(json);
    }
    await _store.writeList(_documentScope(document.ownerId), documents);
    return document;
  }

  @override
  Future<void> deleteDocument(String documentId, String userId) async {
    final documents = await _store.readList(_documentScope(userId));
    documents.removeWhere((d) => d['id'] == documentId);
    await _store.writeList(_documentScope(userId), documents);

    final shares = await _store.readList(_shareKey);
    shares.removeWhere((s) => s['documentId'] == documentId);
    await _store.writeList(_shareKey, shares);
  }

  // ------------------------------------------------------------------ shares

  @override
  Future<List<DocumentShare>> listSharesForOwner(String userId) async {
    final ownedIds = (await listDocuments(userId)).map((d) => d.id).toSet();
    return (await _store.readList(_shareKey))
        .map(DocumentShare.fromJson)
        .where((s) => ownedIds.contains(s.documentId))
        .toList();
  }

  @override
  Future<DocumentShare> saveShare(DocumentShare share) async {
    final rows = await _store.readList(_shareKey);
    final index = rows.indexWhere((s) => s['id'] == share.id);
    final json = share.toJson();
    if (index >= 0) {
      rows[index] = json;
    } else {
      rows.add(json);
    }
    await _store.writeList(_shareKey, rows);
    return share;
  }

  @override
  Future<void> revokeShare(String shareId, String userId) async {
    for (final share in await listSharesForOwner(userId)) {
      if (share.id != shareId) continue;
      await saveShare(
        share.copyWith(revokedAtIso: DateTime.now().toIso8601String()),
      );
      return;
    }
  }

  @override
  Future<void> recordView(String shareId) async {
    final rows = await _store.readList(_shareKey);
    final index = rows.indexWhere((s) => s['id'] == shareId);
    if (index < 0) return;
    final share = DocumentShare.fromJson(rows[index]);
    rows[index] = share.copyWith(viewCount: share.viewCount + 1).toJson();
    await _store.writeList(_shareKey, rows);
  }

  // -------------------------------------------------- public share resolution

  @override
  Future<({CvDocument document, UserProfile profile})?> resolveBySlug(
    String slug,
  ) async {
    for (final share in await _allShares()) {
      if (share.slug != slug) continue;
      return _resolveShare(share);
    }
    return null;
  }

  @override
  Future<({CvDocument document, UserProfile profile})> resolveByToken(
    String token,
  ) async {
    for (final share in await _allShares()) {
      if (share.accessToken != token) continue;
      final resolved = await _resolveShare(share);
      if (resolved == null) {
        throw const ShareNotFoundException('Share is not available');
      }
      return resolved;
    }
    throw const ShareNotFoundException('Invalid access token');
  }

  /// Every share record.
  Future<List<DocumentShare>> _allShares() async =>
      (await _store.readList(_shareKey)).map(DocumentShare.fromJson).toList();

  /// The authorisation boundary: revoked, expired or unpublished are denied.
  ///
  /// Clients never make this decision; only this layer grants public access.
  Future<({CvDocument document, UserProfile profile})?> _resolveShare(
    DocumentShare share,
  ) async {
    if (!share.grantsAccessAt(DateTime.now())) {
      throw const ShareNotFoundException('Share is expired or revoked');
    }

    final document = await _findDocument(share.documentId);
    if (document == null) {
      throw const ShareNotFoundException('Document missing');
    }
    if (!document.published) {
      throw const ShareNotFoundException('Document is not published');
    }

    final profileMap = await _store.readMap(_profileScope(document.ownerId));
    if (profileMap == null) {
      throw const ShareNotFoundException('Profile missing');
    }
    return (document: document, profile: UserProfile.fromJson(profileMap));
  }

  /// Locates a document across all owners (public resolution only).
  Future<CvDocument?> _findDocument(String documentId) async {
    final dir = rootDirectory;
    if (!dir.existsSync()) return null;
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (!name.startsWith(_documentKey)) continue;
      final rows = await _store.readList(name.replaceAll('.json', ''));
      for (final row in rows) {
        if (row['id'] == documentId) return CvDocument.fromJson(row);
      }
    }
    return null;
  }

  // ------------------------------------------------------------------- media

  @override
  Future<StoredObject> uploadBytes({
    required String userId,
    required String fileName,
    required List<int> bytes,
    required String contentType,
  }) async {
    final dir = await _store.mediaDir();
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '$userId/$safeName';
    final file = File('${dir.path}/$path');
    await file.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return StoredObject(
      storagePath: path,
      url: 'file://${file.path}',
      sizeBytes: bytes.length,
    );
  }

  @override
  Future<void> delete(String userId, String storagePath) async {
    final dir = await _store.mediaDir();
    final file = File('${dir.path}/$storagePath');
    if (file.existsSync()) await file.delete();
  }

  @override
  Future<String?> signedUrl(String userId, String storagePath) async {
    final dir = await _store.mediaDir();
    final file = File('${dir.path}/$storagePath');
    return file.existsSync() ? 'file://${file.path}' : null;
  }

  @override
  Future<void> deleteAllForUser(String userId) async {
    final dir = await _store.mediaDir();
    final userDir = Directory('${dir.path}/$userId');
    if (userDir.existsSync()) await userDir.delete(recursive: true);
  }

  // ----------------------------------------------------------------- account

  @override
  Future<void> deleteAccount(String userId) async {
    await deleteAllForUser(userId);
    await _store.remove(_profileScope(userId));

    final ownedRows = await _store.readList(_documentScope(userId));
    final ownedIds = ownedRows.map((d) => d['id'] as String).toSet();
    await _store.remove(_documentScope(userId));

    final shares = await _store.readList(_shareKey);
    shares.removeWhere((s) => ownedIds.contains(s['documentId']));
    await _store.writeList(_shareKey, shares);
  }
}
