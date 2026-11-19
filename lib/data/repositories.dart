/// Persistence contracts for profiles, documents and shares.
///
/// Two implementations exist: [LocalBackend] (device storage, always available)
/// and the Supabase backend. Application code depends only on these
/// interfaces, so swapping backends never touches the UI.
library;

import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';

/// A storage object produced by an upload.
class StoredObject {
  const StoredObject({
    required this.storagePath,
    required this.url,
    this.sizeBytes,
  });

  final String storagePath;
  final String url;
  final int? sizeBytes;
}

/// Raised when an operation is not permitted for the current user.
class UnauthorizedException implements Exception {
  const UnauthorizedException([this.message = 'Not authorised']);
  final String message;

  @override
  String toString() => 'UnauthorizedException: $message';
}

/// Raised when a share token is invalid, expired or revoked.
class ShareNotFoundException implements Exception {
  const ShareNotFoundException([this.message = 'Share not found']);
  final String message;

  @override
  String toString() => 'ShareNotFoundException: $message';
}

/// An unfinished builder session reuses the existing profile model.
class CvBuilderDraft {
  const CvBuilderDraft({
    required this.profile,
    this.step = 0,
    this.pendingDocumentId,
    this.profileMergeBaseline,
    this.profileSyncPending = false,
  });
  final UserProfile profile;
  final int step;
  final String? pendingDocumentId;
  final UserProfile? profileMergeBaseline;
  final bool profileSyncPending;
  Map<String, dynamic> toJson() => {
    'profile': profile.toJson(),
    'step': step,
    'wizardVersion': 2,
    if (profileSyncPending) 'profileSyncPending': true,
    if (profileSyncPending) 'pendingDocumentId': pendingDocumentId,
    if (profileSyncPending)
      'profileMergeBaseline': profileMergeBaseline?.toJson(),
  };
  static int _restoreStep(Map<String, dynamic> json) {
    final raw = json['step'] is num ? (json['step'] as num).toInt() : 0;
    if (json['wizardVersion'] == 2) return raw.clamp(0, 7);
    final legacy = raw.clamp(0, 6);
    return legacy == 6 ? 7 : legacy;
  }

  factory CvBuilderDraft.fromJson(Map<String, dynamic> json) => CvBuilderDraft(
    profile: UserProfile.fromJson(
      Map<String, dynamic>.from(json['profile'] as Map),
    ),
    step: _restoreStep(json),
    pendingDocumentId: json['pendingDocumentId'] as String?,
    profileSyncPending: json['profileSyncPending'] == true,
    profileMergeBaseline: json['profileMergeBaseline'] is Map
        ? UserProfile.fromJson(
            Map<String, dynamic>.from(json['profileMergeBaseline'] as Map),
          )
        : null,
  );
}

abstract interface class CvDraftRepository {
  Future<CvBuilderDraft?> loadCvDraft(String userId, String draftKey);
  Future<void> saveCvDraft(
    String userId,
    String draftKey,
    CvBuilderDraft draft,
  );
  Future<void> deleteCvDraft(String userId, String draftKey);
}

/// Profile persistence.
abstract interface class ProfileRepository {
  /// Loads the profile for [userId], or null when none exists yet.
  Future<UserProfile?> loadProfile(String userId);

  /// Persists the profile, returning the stored copy.
  Future<UserProfile> saveProfile(UserProfile profile);
}

/// Document persistence scoped to an owner.
abstract interface class DocumentRepository {
  /// All documents owned by [userId], newest first.
  Future<List<CvDocument>> listDocuments(String userId);

  /// Loads one document, enforcing ownership.
  ///
  /// Throws [UnauthorizedException] when [userId] does not own the document.
  Future<CvDocument?> loadDocument(String documentId, String userId);

  /// Creates or updates a document and returns the stored copy.
  Future<CvDocument> saveDocument(CvDocument document);

  /// Deletes a document and its share records.
  Future<void> deleteDocument(String documentId, String userId);

  /// Sets (or clears, when [password] is null) the visitor password for a
  /// document the caller owns.
  ///
  /// Only a hash is persisted. The Supabase implementation hashes and verifies
  /// inside Postgres, so the check cannot be bypassed by a modified client.
  Future<CvDocument> setAccessPassword({
    required String documentId,
    required String userId,
    required String? password,
  });
}

/// Share link management and validation.
abstract interface class ShareRepository {
  /// All shares for documents owned by [userId].
  Future<List<DocumentShare>> listSharesForOwner(String userId);

  /// Creates or updates a share record.
  Future<DocumentShare> saveShare(DocumentShare share);

  /// Revokes a share.
  Future<void> revokeShare(String shareId, String userId);

  /// Resolves a public slug. Returns null when unavailable.
  Future<({CvDocument document, UserProfile profile})?> resolveBySlug(
    String slug,
  );

  /// Resolves a restricted token, enforcing expiry and revocation.
  ///
  /// Throws [ShareNotFoundException] when the token is unknown, revoked or
  /// expired. This is the server-side authorisation boundary: clients never
  /// decide access themselves.
  Future<({CvDocument document, UserProfile profile})> resolveByToken(
    String token,
  );

  /// Resolves a password-protected public slug.
  ///
  /// Returns `null` when the password is wrong, the share is unavailable, or
  /// the document is not password protected. The comparison happens in the
  /// backend (Postgres `crypt` for Supabase), never in the widget layer.
  Future<({CvDocument document, UserProfile profile})?>
  resolveBySlugWithPassword(String slug, String password);

  /// Records that a share was viewed.
  Future<void> recordView(String shareId);
}

/// File storage for profile photos and project media.
abstract interface class MediaRepository {
  /// Uploads bytes to a private owner-scoped path.
  Future<StoredObject> uploadBytes({
    required String userId,
    required String fileName,
    required List<int> bytes,
    required String contentType,
  });

  /// Deletes a stored object.
  Future<void> delete(String userId, String storagePath);

  /// A readable URL for a stored object.
  Future<String?> signedUrl(String userId, String storagePath);

  /// Deletes every object under the owner's prefix.
  Future<void> deleteAllForUser(String userId);
}

/// Deletes a user's account and all associated data.
abstract interface class AccountRepository {
  /// Permanently removes profile, documents, shares and stored media.
  Future<void> deleteAccount(String userId);
}
