/// The CV / Portfolio document entity and its share records.
///
/// Hand-written immutable models (no code generation).
library;

import 'package:cv_portfolio_maker/core/domain/document_models.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';

/// A user-owned CV or portfolio.
class CvDocument {
  const CvDocument({
    required this.id,
    required this.ownerId,
    required this.title,
    this.type = DocumentType.cv,
    this.design = const DocumentDesign(),
    this.includedProjectIds,
    this.shareMode = ShareMode.privateDraft,
    this.published = false,
    this.publicSlug,
    this.allowPdfDownload = true,
    this.isRtl = false,
    this.createdAtIso,
    this.updatedAtIso,
    this.version = 1,
  });

  final String id;

  /// Owning user id. Never exposed in public payloads.
  final String ownerId;
  final String title;
  final DocumentType type;

  /// Section + design configuration.
  final DocumentDesign design;

  /// Profile entry ids this document includes. `null` means "all visible".
  final List<String>? includedProjectIds;

  final ShareMode shareMode;
  final bool published;

  /// Slug used in public URLs (only for published documents).
  final String? publicSlug;

  /// Whether viewers may download the PDF.
  final bool allowPdfDownload;

  /// The document's own language/direction, independent of the UI locale.
  final bool isRtl;

  final String? createdAtIso;
  final String? updatedAtIso;

  /// Bumped on every save; used for conflict detection.
  final int version;

  CvDocument copyWith({
    String? id,
    String? ownerId,
    String? title,
    DocumentType? type,
    DocumentDesign? design,
    List<String>? Function()? includedProjectIds,
    ShareMode? shareMode,
    bool? published,
    String? Function()? publicSlug,
    bool? allowPdfDownload,
    bool? isRtl,
    String? Function()? createdAtIso,
    String? Function()? updatedAtIso,
    int? version,
  }) => CvDocument(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    title: title ?? this.title,
    type: type ?? this.type,
    design: design ?? this.design,
    includedProjectIds: includedProjectIds == null
        ? this.includedProjectIds
        : includedProjectIds(),
    shareMode: shareMode ?? this.shareMode,
    published: published ?? this.published,
    publicSlug: publicSlug == null ? this.publicSlug : publicSlug(),
    allowPdfDownload: allowPdfDownload ?? this.allowPdfDownload,
    isRtl: isRtl ?? this.isRtl,
    createdAtIso: createdAtIso == null ? this.createdAtIso : createdAtIso(),
    updatedAtIso: updatedAtIso == null ? this.updatedAtIso : updatedAtIso(),
    version: version ?? this.version,
  );

  factory CvDocument.fromJson(Map<String, dynamic> json) => CvDocument(
    id: '${json['id'] ?? ''}',
    ownerId: '${json['ownerId'] ?? json['owner_id'] ?? ''}',
    title: '${json['title'] ?? ''}',
    type: DocumentType.values.asNameMap()['${json['type']}'] ?? DocumentType.cv,
    design: json['design'] is Map
        ? DocumentDesign.fromJson(
            Map<String, dynamic>.from(json['design'] as Map),
          )
        : const DocumentDesign(),
    includedProjectIds:
        (json['includedProjectIds'] ?? json['included_project_ids']) is List
        ? List<String>.from(
            ((json['includedProjectIds'] ?? json['included_project_ids'])
                    as List)
                .map((e) => '$e'),
          )
        : null,
    shareMode:
        ShareMode.values
            .asNameMap()['${json['shareMode'] ?? json['share_mode']}'] ??
        ShareMode.privateDraft,
    published: (json['published'] as bool?) ?? false,
    publicSlug: (json['publicSlug'] ?? json['public_slug']) as String?,
    allowPdfDownload:
        (json['allowPdfDownload'] ?? json['allow_pdf_download'] as bool?) ??
        true,
    isRtl: (json['isRtl'] ?? json['is_rtl'] as bool?) ?? false,
    createdAtIso: (json['createdAtIso'] ?? json['created_at']) as String?,
    updatedAtIso: (json['updatedAtIso'] ?? json['updated_at']) as String?,
    version: (json['version'] as num?)?.toInt() ?? 1,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerId': ownerId,
    'title': title,
    'type': type.name,
    'design': design.toJson(),
    'includedProjectIds': includedProjectIds,
    'shareMode': shareMode.name,
    'published': published,
    'publicSlug': publicSlug,
    'allowPdfDownload': allowPdfDownload,
    'isRtl': isRtl,
    'createdAtIso': createdAtIso,
    'updatedAtIso': updatedAtIso,
    'version': version,
  };
}

/// Extension helpers for [CvDocument].
extension CvDocumentX on CvDocument {
  /// `true` when anyone with the URL may read this document.
  bool get isPubliclyReadable =>
      published && shareMode == ShareMode.publicLink && publicSlug != null;

  /// `true` when the document is reachable only by its owner.
  bool get isPrivate => !published || shareMode == ShareMode.privateDraft;
}

/// A share record: a public slug or a restricted recipient token.
class DocumentShare {
  const DocumentShare({
    required this.id,
    required this.documentId,
    this.mode = ShareMode.publicLink,
    this.accessToken,
    this.slug,
    this.recipientLabel,
    this.recipientEmail,
    this.expiresAtIso,
    this.revokedAtIso,
    this.viewCount = 0,
    this.createdAtIso,
  });

  final String id;
  final String documentId;
  final ShareMode mode;
  final String? accessToken;
  final String? slug;
  final String? recipientLabel;
  final String? recipientEmail;
  final String? expiresAtIso;
  final String? revokedAtIso;
  final int viewCount;
  final String? createdAtIso;

  DocumentShare copyWith({
    String? id,
    String? documentId,
    ShareMode? mode,
    String? accessToken,
    String? slug,
    String? recipientLabel,
    String? recipientEmail,
    String? expiresAtIso,
    String? revokedAtIso,
    int? viewCount,
    String? createdAtIso,
  }) => DocumentShare(
    id: id ?? this.id,
    documentId: documentId ?? this.documentId,
    mode: mode ?? this.mode,
    accessToken: accessToken ?? this.accessToken,
    slug: slug ?? this.slug,
    recipientLabel: recipientLabel ?? this.recipientLabel,
    recipientEmail: recipientEmail ?? this.recipientEmail,
    expiresAtIso: expiresAtIso ?? this.expiresAtIso,
    revokedAtIso: revokedAtIso ?? this.revokedAtIso,
    viewCount: viewCount ?? this.viewCount,
    createdAtIso: createdAtIso ?? this.createdAtIso,
  );

  factory DocumentShare.fromJson(Map<String, dynamic> json) => DocumentShare(
    id: '${json['id'] ?? ''}',
    documentId: '${json['documentId'] ?? json['document_id'] ?? ''}',
    mode:
        ShareMode.values.asNameMap()['${json['mode'] ?? json['share_mode']}'] ??
        ShareMode.publicLink,
    accessToken: json['accessToken'] ?? json['access_token'] as String?,
    slug: json['slug'] ?? json['public_slug'] as String?,
    recipientLabel:
        json['recipientLabel'] ?? json['recipient_label'] as String?,
    recipientEmail:
        json['recipientEmail'] ?? json['recipient_email'] as String?,
    expiresAtIso: json['expiresAtIso'] ?? json['expires_at'] as String?,
    revokedAtIso: json['revokedAtIso'] ?? json['revoked_at'] as String?,
    viewCount: (json['viewCount'] ?? json['view_count'] as num?)?.toInt() ?? 0,
    createdAtIso: json['createdAtIso'] ?? json['created_at'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'documentId': documentId,
    'mode': mode.name,
    'accessToken': accessToken,
    'slug': slug,
    'recipientLabel': recipientLabel,
    'recipientEmail': recipientEmail,
    'expiresAtIso': expiresAtIso,
    'revokedAtIso': revokedAtIso,
    'viewCount': viewCount,
    'createdAtIso': createdAtIso,
  };
}

/// Extension helpers for [DocumentShare].
extension DocumentShareX on DocumentShare {
  /// Whether this share currently grants read access.
  ///
  /// Time is injectable so tests can verify expiry deterministically.
  bool grantsAccessAt(DateTime now) {
    if (revokedAtIso != null) return false;
    final expiry = expiresAtIso == null
        ? null
        : DateTime.tryParse(expiresAtIso!);
    if (expiry != null && now.isAfter(expiry)) return false;
    return true;
  }

  /// Whether this share grants access right now.
  bool get isActive => grantsAccessAt(DateTime.now());

  /// Builds the public URL for this share.
  String buildUrl(String baseUrl) {
    if (mode == ShareMode.publicLink) {
      return '$baseUrl/p/${slug ?? ''}';
    }
    return '$baseUrl/s/${accessToken ?? ''}';
  }
}
