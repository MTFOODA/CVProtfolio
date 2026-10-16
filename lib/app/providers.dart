/// Read-only access to the active profile, document and repository layer.
///
/// Providers never import Flutter widgets: pure Riverpod state management.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cv_portfolio_maker/core/config/app_config.dart';
import 'package:cv_portfolio_maker/core/domain/document_entity.dart';
import 'package:cv_portfolio_maker/core/domain/profile_models.dart';
import 'package:cv_portfolio_maker/data/auth/auth_service.dart';
import 'package:cv_portfolio_maker/data/local/local_repositories.dart';
import 'package:cv_portfolio_maker/data/local/local_store.dart';
import 'package:cv_portfolio_maker/data/repositories.dart';
import 'package:cv_portfolio_maker/data/supabase/supabase_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

/// Application configuration derived from `--dart-define` values.
final appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError('appConfigProvider must be overridden at startup');
});

/// Authentication service for the active backend.
final authServiceProvider = Provider<AuthService>((ref) {
  throw UnimplementedError('authServiceProvider must be overridden');
});

/// Currently signed-in user, null when signed out.
final authUserProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Restored synchronously-known user (session bootstrap).
final sessionProvider = FutureProvider<AuthUser?>((ref) async {
  return ref.watch(authServiceProvider).restoreSession();
});

/// Shared persistence backend: local store or Supabase.
final backendProvider = Provider<LocalBackendOrSupabase>((ref) {
  throw UnimplementedError('backendProvider must be overridden at startup');
});

/// Convenience accessor bundling every repository interface.
class LocalBackendOrSupabase
    implements
        ProfileRepository,
        DocumentRepository,
        ShareRepository,
        MediaRepository,
        AccountRepository {
  LocalBackendOrSupabase.local(this.local) : supabase = null, isLocal = true;

  LocalBackendOrSupabase.supabase(this.supabase)
    : local = null,
      isLocal = false;

  final LocalBackend? local;
  final SupabaseBackend? supabase;
  final bool isLocal;

  ProfileRepository get profiles =>
      (isLocal ? local! : supabase!) as ProfileRepository;
  DocumentRepository get documents =>
      (isLocal ? local! : supabase!) as DocumentRepository;
  ShareRepository get shares =>
      (isLocal ? local! : supabase!) as ShareRepository;
  MediaRepository get media =>
      (isLocal ? local! : supabase!) as MediaRepository;
  AccountRepository get account =>
      (isLocal ? local! : supabase!) as AccountRepository;

  @override
  Future<void> deleteAccount(String userId) => account.deleteAccount(userId);

  @override
  Future<void> delete(String userId, String storagePath) =>
      media.delete(userId, storagePath);

  @override
  Future<void> deleteAllForUser(String userId) =>
      media.deleteAllForUser(userId);

  @override
  Future<void> deleteDocument(String documentId, String userId) =>
      documents.deleteDocument(documentId, userId);

  @override
  Future<List<CvDocument>> listDocuments(String userId) =>
      documents.listDocuments(userId);

  @override
  Future<List<DocumentShare>> listSharesForOwner(String userId) =>
      shares.listSharesForOwner(userId);

  @override
  Future<CvDocument?> loadDocument(String documentId, String userId) =>
      documents.loadDocument(documentId, userId);

  @override
  Future<UserProfile?> loadProfile(String userId) =>
      profiles.loadProfile(userId);

  @override
  Future<void> recordView(String shareId) => shares.recordView(shareId);

  @override
  Future<({CvDocument document, UserProfile profile})?> resolveBySlug(
    String slug,
  ) => shares.resolveBySlug(slug);

  @override
  Future<({CvDocument document, UserProfile profile})> resolveByToken(
    String token,
  ) => shares.resolveByToken(token);

  @override
  Future<void> revokeShare(String shareId, String userId) =>
      shares.revokeShare(shareId, userId);

  @override
  Future<CvDocument> saveDocument(CvDocument document) =>
      documents.saveDocument(document);

  @override
  Future<UserProfile> saveProfile(UserProfile profile) =>
      profiles.saveProfile(profile);

  @override
  Future<DocumentShare> saveShare(DocumentShare share) =>
      shares.saveShare(share);

  @override
  Future<String?> signedUrl(String userId, String storagePath) =>
      media.signedUrl(userId, storagePath);

  @override
  Future<StoredObject> uploadBytes({
    required String userId,
    required String fileName,
    required List<int> bytes,
    required String contentType,
  }) => media.uploadBytes(
    userId: userId,
    fileName: fileName,
    bytes: bytes,
    contentType: contentType,
  );
}

/// Builds the persistence backend for [config].
Future<LocalBackendOrSupabase> createBackend(AppConfig config) async {
  if (config.isSupabaseConfigured) {
    return LocalBackendOrSupabase.supabase(
      SupabaseBackend(Supabase.instance.client),
    );
  }
  final store = await LocalStore.open();
  return LocalBackendOrSupabase.local(LocalBackend(store));
}

/// The active user's profile (null while signed out or not yet created).
final profileProvider = FutureProvider.family<UserProfile?, String>((
  ref,
  userId,
) async {
  return ref.watch(backendProvider).loadProfile(userId);
});

/// Documents owned by [userId], newest first.
final documentsProvider = FutureProvider.family<List<CvDocument>, String>((
  ref,
  userId,
) async {
  return ref.watch(backendProvider).listDocuments(userId);
});

/// Shares for documents owned by [userId].
final sharesProvider = FutureProvider.family<List<DocumentShare>, String>((
  ref,
  userId,
) async {
  return ref.watch(backendProvider).listSharesForOwner(userId);
});
