import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/domain/document_entity.dart';
import '../core/domain/enums.dart';
import '../data/local/export_counter.dart';

final downloadCountProvider = FutureProvider.family<int, String>(
  (ref, userId) => readExportCount(userId),
);

/// Historical opens of links belonging to this account's current portfolios.
int portfolioViewTotal(
  String userId,
  List<CvDocument> documents,
  List<DocumentShare> shares,
) {
  final portfolioIds = documents
      .where((d) => d.ownerId == userId && d.type == DocumentType.portfolio)
      .map((d) => d.id)
      .toSet();
  return shares
      .where((s) => portfolioIds.contains(s.documentId))
      .fold(0, (total, share) => total + share.viewCount);
}
