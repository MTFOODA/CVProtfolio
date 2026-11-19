import '../domain/profile_models.dart';
import 'contact_links.dart';

/// Compact actions rendered inline with a CV project title.
class ProjectHeadingLink {
  const ProjectHeadingLink(
    this.label,
    this.url,
    this.codePoint, {
    this.brand = false,
  });
  final String label;
  final String url;
  final int codePoint;
  final bool brand;
}

List<ProjectHeadingLink> projectHeadingLinks(ProjectEntry project) {
  final seen = <String>{};
  return [
    for (final candidate in [
      ProjectHeadingLink('Demo', project.demoUrl ?? '', 0xe157),
      ProjectHeadingLink(
        'Source',
        project.sourceUrl ?? '',
        0xf09b,
        brand: true,
      ),
      ProjectHeadingLink('Website', project.websiteUrl ?? '', 0xe894),
    ])
      if (contactWebUrl(candidate.url) case final String url)
        if (seen.add(url))
          ProjectHeadingLink(
            candidate.label,
            url,
            candidate.codePoint,
            brand: candidate.brand,
          ),
  ];
}
