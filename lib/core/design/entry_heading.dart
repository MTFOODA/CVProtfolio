import '../domain/document_models.dart';

/// Shared content placement for screen, PDF and Word entry headings.
class EntryHeadingContent {
  const EntryHeadingContent(this.title, this.metadata, this.organization);
  final String title;
  final String metadata;
  final String organization;

  factory EntryHeadingContent.resolve({
    required String title,
    required String metadata,
    String organization = '',
    required PresentationConfig presentation,
  }) {
    String join(String a, String b) => [
      a,
      b,
    ].map((part) => part.trim()).where((part) => part.isNotEmpty).join(' · ');
    return switch (presentation.organizationPosition) {
      'besideTitle' => EntryHeadingContent(
        join(title, organization),
        metadata,
        '',
      ),
      'withDate' => EntryHeadingContent(
        title,
        join(organization, metadata),
        '',
      ),
      _ => EntryHeadingContent(title, metadata, organization.trim()),
    };
  }
}
