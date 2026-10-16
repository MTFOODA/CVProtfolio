/// Supabase implementation of the persistence contracts.
///
/// Row Level Security is the real authorisation boundary: the client only ever
/// sends the user's session token, and Postgres policies decide which rows are
/// visible or writable. See `supabase/migrations/0001_init.sql`.
///
/// The service-role key is never referenced here; it belongs only to server
/// side Edge Functions.
library;

import 'dart:typed_data';

import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/data/repositories.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Table names, kept in one place to match the SQL migration.
abstract final class Tables {
  static const String profiles = 'profiles';
  static const String documents = 'documents';
  static const String shares = 'document_shares';
}

/// Storage buckets.
abstract final class Buckets {
  static const String media = 'document-media';
}

/// Supabase-backed repositories.
class SupabaseBackend
    implements
        ProfileRepository,
        DocumentRepository,
        ShareRepository,
        MediaRepository,
        AccountRepository {
  SupabaseBackend(this._client);

  final SupabaseClient _client;

  /// The signed-in user's id, or null when unauthenticated.
  String? get _userId => _client.auth.currentUser?.id;

  /// Requires an authenticated session for owner-scoped operations.
  String get _requireUserId {
    final id = _userId;
    if (id == null) {
      throw const UnauthorizedException('You must be signed in');
    }
    return id;
  }

  // ---------------------------------------------------------------- profiles

  @override
  Future<UserProfile?> loadProfile(String userId) async {
    _requireUserId;
    final row = await _client
        .from(Tables.profiles)
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return UserProfile.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<UserProfile> saveProfile(UserProfile profile) async {
    _requireUserId;
    final payload = profile.toJson()
      ..['updated_at'] = DateTime.now().toIso8601String();
    await _client.from(Tables.profiles).upsert(payload);
    return profile;
  }

  // --------------------------------------------------------------- documents

  @override
  Future<List<CvDocument>> listDocuments(String userId) async {
    _requireUserId;
    final rows = await _client
        .from(Tables.documents)
        .select()
        .eq('owner_id', userId)
        .order('updated_at', ascending: false);
    return rows
        .map((row) => CvDocument.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<CvDocument?> loadDocument(String documentId, String userId) async {
    _requireUserId;
    // Scoping by owner_id lets RLS reject cross-user reads outright.
    final row = await _client
        .from(Tables.documents)
        .select()
        .eq('id', documentId)
        .eq('owner_id', userId)
        .maybeSingle();
    return row == null
        ? null
        : CvDocument.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<CvDocument> saveDocument(CvDocument document) async {
    _requireUserId;
    final payload = _documentToRow(document);
    final row = await _client
        .from(Tables.documents)
        .upsert(payload)
        .select()
        .single();
    return CvDocument.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> deleteDocument(String documentId, String userId) async {
    _requireUserId;
    await _client
        .from(Tables.documents)
        .delete()
        .eq('id', documentId)
        .eq('owner_id', userId);
  }

  /// Maps a document to its normalised row representation.
  Map<String, dynamic> _documentToRow(CvDocument document) => {
    'id': document.id,
    'owner_id': document.ownerId,
    'title': document.title,
    'type': document.type.name,
    'design': document.design.toJson(),
    'included_project_ids': document.includedProjectIds,
    'share_mode': document.shareMode.name,
    'published': document.published,
    'public_slug': document.publicSlug,
    'allow_pdf_download': document.allowPdfDownload,
    'is_rtl': document.isRtl,
    'version': document.version,
    'updated_at': DateTime.now().toIso8601String(),
  };

  // ------------------------------------------------------------------ shares

  @override
  Future<List<DocumentShare>> listSharesForOwner(String userId) async {
    _requireUserId;
    // The view is owner-scoped through RLS; only this user's shares return.
    final rows = await _client
        .from(Tables.shares)
        .select('*, documents!inner(owner_id)')
        .eq('documents.owner_id', userId);
    return rows
        .map((row) => DocumentShare.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<DocumentShare> saveShare(DocumentShare share) async {
    _requireUserId;
    final payload = {
      'id': share.id,
      'document_id': share.documentId,
      'mode': share.mode.name,
      'access_token': share.accessToken,
      'slug': share.slug,
      'recipient_label': share.recipientLabel,
      'recipient_email': share.recipientEmail,
      'expires_at': share.expiresAtIso,
      'revoked_at': share.revokedAtIso,
      'view_count': share.viewCount,
    };
    final row = await _client
        .from(Tables.shares)
        .upsert(payload)
        .select()
        .single();
    return DocumentShare.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> revokeShare(String shareId, String userId) async {
    _requireUserId;
    await _client
        .from(Tables.shares)
        .update({'revoked_at': DateTime.now().toIso8601String()})
        .eq('id', shareId);
  }

  @override
  Future<({CvDocument document, UserProfile profile})?> resolveBySlug(
    String slug,
  ) {
    // Resolved without a session: the security-definer RPC validates the slug,
    // publication state and returns only publishable content.
    return _resolveViaRpc('resolve_share_by_slug', {'p_slug': slug});
  }

  @override
  Future<({CvDocument document, UserProfile profile})> resolveByToken(
    String token,
  ) async {
    final resolved = await _resolveViaRpc('resolve_share_by_token', {
      'p_token': token,
    });
    if (resolved == null) {
      throw const ShareNotFoundException('Invalid or expired access token');
    }
    return resolved;
  }

  /// Calls a security-definer RPC and rehydrates the payload.
  ///
  /// The RPC enforces publication, revocation and expiry server-side, so no
  /// client-side check can grant access to private content.
  Future<({CvDocument document, UserProfile profile})?> _resolveViaRpc(
    String fn,
    Map<String, dynamic> params,
  ) async {
    final response = await _client.rpc<dynamic>(fn, params: params);
    if (response == null) return null;
    final map = Map<String, dynamic>.from(response as Map);
    return (
      document: CvDocument.fromJson(Map<String, dynamic>.from(map['document'])),
      profile: UserProfile.fromJson(Map<String, dynamic>.from(map['profile'])),
    );
  }

  @override
  Future<void> recordView(String shareId) async {
    // Best effort; a failed counter must never block viewing.
    try {
      await _client.rpc<dynamic>(
        'record_share_view',
        params: {'p_share_id': shareId},
      );
    } on Object {
      // Ignored intentionally.
    }
  }

  // ------------------------------------------------------------------- media

  @override
  Future<StoredObject> uploadBytes({
    required String userId,
    required String fileName,
    required List<int> bytes,
    required String contentType,
  }) async {
    _requireUserId;
    // Owner-prefixed path lets storage policies authorise by folder.
    final path = '$userId/${DateTime.now().microsecondsSinceEpoch}_$fileName';
    await _client.storage
        .from(Buckets.media)
        .uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    final url = _client.storage.from(Buckets.media).getPublicUrl(path);
    return StoredObject(storagePath: path, url: url, sizeBytes: bytes.length);
  }

  @override
  Future<void> delete(String userId, String storagePath) async {
    _requireUserId;
    await _client.storage.from(Buckets.media).remove([storagePath]);
  }

  @override
  Future<String?> signedUrl(String userId, String storagePath) async {
    _requireUserId;
    return _client.storage
        .from(Buckets.media)
        .createSignedUrl(storagePath, 3600);
  }

  @override
  Future<void> deleteAllForUser(String userId) async {
    _requireUserId;
    try {
      final files = await _client.storage
          .from(Buckets.media)
          .list(path: userId);
      final paths = files.map((f) => '$userId/${f.name}').toList();
      if (paths.isNotEmpty) {
        await _client.storage.from(Buckets.media).remove(paths);
      }
    } on Object {
      // Storage cleanup failures are non-fatal for account deletion.
    }
  }

  // ----------------------------------------------------------------- account

  @override
  Future<void> deleteAccount(String userId) async {
    _requireUserId;
    await deleteAllForUser(userId);
    // Cascading FKs remove documents, sections and shares server-side.
    await _client.rpc<dynamic>('delete_own_account');
  }
}
