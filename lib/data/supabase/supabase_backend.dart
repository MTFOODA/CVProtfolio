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

import '../../core/domain/enums.dart';

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
        CvDraftRepository,
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

  void _requireOwner(String userId) {
    if (_requireUserId != userId) {
      throw const UnauthorizedException('The active account has changed');
    }
  }

  @override
  Future<CvBuilderDraft?> loadCvDraft(String userId, String draftKey) async {
    _requireUserId;
    final row = await _client
        .from('cv_builder_drafts')
        .select('payload')
        .eq('owner_id', userId)
        .eq('draft_key', draftKey)
        .maybeSingle();
    return row == null
        ? null
        : CvBuilderDraft.fromJson(
            Map<String, dynamic>.from(row['payload'] as Map),
          );
  }

  @override
  Future<void> saveCvDraft(
    String userId,
    String draftKey,
    CvBuilderDraft draft,
  ) async {
    _requireUserId;
    await _client.from('cv_builder_drafts').upsert({
      'owner_id': userId,
      'draft_key': draftKey,
      'payload': draft.toJson(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> deleteCvDraft(String userId, String draftKey) async {
    _requireUserId;
    await _client
        .from('cv_builder_drafts')
        .delete()
        .eq('owner_id', userId)
        .eq('draft_key', draftKey);
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
    if (document.type == DocumentType.cv && document.profileSnapshot == null) {
      document = document.copyWith(
        profileSnapshot: await loadProfile(document.ownerId),
      );
    }
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
    'profile_snapshot': document.profileSnapshot?.toJson(),
    'included_project_ids': document.includedProjectIds,
    'share_mode': document.shareMode.name,
    'published': document.published,
    'public_slug': document.publicSlug,
    'allow_pdf_download': document.allowPdfDownload,
    'is_rtl': document.isRtl,
    'version': document.version,
    'updated_at': DateTime.now().toIso8601String(),
  };

  @override
  Future<CvDocument> setAccessPassword({
    required String documentId,
    required String userId,
    required String? password,
  }) async {
    _requireUserId;
    // The hash is produced by Postgres (bcrypt); this client never sees or
    // stores the plaintext beyond this single request.
    if (password == null) {
      await _client.rpc<dynamic>(
        'clear_portfolio_password',
        params: {'p_document_id': documentId},
      );
    } else {
      await _client.rpc<dynamic>(
        'set_portfolio_password',
        params: {'p_document_id': documentId, 'p_password': password},
      );
    }
    final row = await _client
        .from(Tables.documents)
        .select()
        .eq('id', documentId)
        .eq('owner_id', userId)
        .maybeSingle();
    if (row == null) {
      throw const UnauthorizedException('Document not found for this user');
    }
    return CvDocument.fromJson(Map<String, dynamic>.from(row));
  }

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
    // publication state and returns only publishable content. Password-protected
    // documents are refused by the RPC and must use the password resolver.
    return _resolveViaRpc('resolve_share_by_slug', {'p_slug': slug});
  }

  @override
  Future<({CvDocument document, UserProfile profile})?>
  resolveBySlugWithPassword(String slug, String password) {
    // The comparison happens inside the SECURITY DEFINER function; a wrong
    // password returns null exactly like an unknown slug.
    return _resolveViaRpc('resolve_share_with_password', {
      'p_slug': slug,
      'p_password': password,
    });
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
    var document = CvDocument.fromJson(
      Map<String, dynamic>.from(map['document']),
    );
    var profile =
        (document.type == DocumentType.cv ? document.profileSnapshot : null) ??
        UserProfile.fromJson(Map<String, dynamic>.from(map['profile']));
    final hasStoredMedia =
        [
          profile.details.avatarUrl,
          ...profile.projects.expand((p) => p.media),
          ...profile.customSections.expand(
            (section) => section.entries.map((entry) => entry.imageUrl),
          ),
        ].whereType<String>().any(
          (path) =>
              path.startsWith('${profile.id}/') ||
              // Older profiles persisted public or expired signed URLs for the
              // private bucket. The server verifies their origin and signs them again.
              (Uri.tryParse(path)?.path.contains('/object/') == true &&
                  Uri.tryParse(path)?.path.contains('/${Buckets.media}/') ==
                      true),
        );
    if (hasStoredMedia) {
      // A separate server boundary re-verifies the same share credentials before
      // signing media. Never ask visitors to authenticate as the profile owner.
      try {
        final result = await _client.functions.invoke(
          'share-media',
          body: {'resolver': fn, 'params': params},
        );
        final data = result.data;
        if (data is Map && data['urls'] is Map) {
          final urls = Map<String, String>.from(data['urls'] as Map);
          profile = profile.copyWith(
            details: profile.details.copyWith(
              avatarUrl:
                  urls[profile.details.avatarUrl] ?? profile.details.avatarUrl,
            ),
            customSections: [
              for (final section in profile.customSections)
                section.copyWith(
                  entries: [
                    for (final entry in section.entries)
                      entry.copyWith(
                        imageUrl: urls[entry.imageUrl] ?? entry.imageUrl,
                      ),
                  ],
                ),
            ],
            projects: [
              for (final project in profile.projects)
                project.copyWith(
                  media: [for (final path in project.media) urls[path] ?? path],
                ),
            ],
          );
        }
      } catch (_) {
        // Text remains viewable when the media function is unavailable. Media
        // widgets report unavailable playback; storage policies stay private.
      }
    }
    if (document.type == DocumentType.cv && document.profileSnapshot != null) {
      document = document.copyWith(profileSnapshot: profile);
    }
    // Only a successfully resolved share grants a view. Failed passwords,
    // expired links and private drafts never reach this point.
    final shareId = map['shareId'] as String?;
    if (shareId != null) await recordView(shareId);
    return (document: document, profile: profile);
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
    final url = await _client.storage
        .from(Buckets.media)
        .createSignedUrl(path, 3600);
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
    _requireOwner(userId);
    await deleteAllForUser(userId);
    // The storage call can span an account switch. The RPC always deletes
    // the authenticated account, so recheck the intended owner before it.
    _requireOwner(userId);
    // Cascading FKs remove documents, sections and shares server-side.
    await _client.rpc<dynamic>('delete_own_account');
  }
}
