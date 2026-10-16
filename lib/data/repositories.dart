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
