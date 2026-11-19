import '../domain/document_models.dart';
import '../domain/enums.dart';

import 'dart:convert';

import '../domain/profile_models.dart';

/// New CVs add their content without erasing Portfolio data. Editing a saved
/// CV applies only the fields/entries that actually changed in that CV.
UserProfile mergeCvIntoProfile(
  UserProfile existing,
  UserProfile cv, {
  UserProfile? previous,
}) {
  List<T> merge<T>(
    List<T> before,
    List<T> after,
    List<T>? previousEntries,
    String Function(T) id,
    Map<String, dynamic> Function(T) json,
  ) {
    final incoming = after.map(id).toSet();
    final original = {
      for (final item in previousEntries ?? <T>[]) id(item): item,
    };
    final removed = original.keys
        .where((key) => !incoming.contains(key))
        .toSet();
    final changed = after.where(
      (item) =>
          !original.containsKey(id(item)) ||
          jsonEncode(json(original[id(item)] as T)) != jsonEncode(json(item)),
    );
    return {
      for (final item in before)
        if (!removed.contains(id(item))) id(item): item,
      for (final item in changed) id(item): item,
    }.values.toList();
  }

  String? value(String? next, String? current, String? original) {
    if (previous != null) return next == original ? current : next ?? '';
    return next?.trim().isNotEmpty == true ? next : current;
  }

  final old = existing.details;
  final next = cv.details;
  final previousLinks = previous?.details.links.toSet() ?? <String>{};
  final removedLinks = previousLinks.difference(next.links.toSet());
  final links = {
    ...old.links.where((url) => !removedLinks.contains(url)),
    ...next.links.where((url) => !previousLinks.contains(url)),
  };
  final labels = {...old.linkLabels};
  for (final url in previous?.details.linkLabels.keys ?? <String>[]) {
    if (!next.linkLabels.containsKey(url)) labels.remove(url);
  }
  for (final entry in next.linkLabels.entries) {
    if (previous?.details.linkLabels[entry.key] != entry.value) {
      labels[entry.key] = entry.value;
    }
  }
  labels.removeWhere(
    (url, _) =>
        !links.contains(url) && url != next.website && url != old.website,
  );
  return existing.copyWith(
    details: old.copyWith(
      fullName: value(next.fullName, old.fullName, previous?.details.fullName),
      professionalTitle: value(
        next.professionalTitle,
        old.professionalTitle,
        previous?.details.professionalTitle,
      ),
      email: value(next.email, old.email, previous?.details.email),
      phone: value(next.phone, old.phone, previous?.details.phone),
      location: value(next.location, old.location, previous?.details.location),
      summary: value(next.summary, old.summary, previous?.details.summary),
      website: value(next.website, old.website, previous?.details.website),
      avatarUrl: value(
        next.avatarUrl,
        old.avatarUrl,
        previous?.details.avatarUrl,
      ),
      links: links.toList(),
      linkLabels: labels,
    ),
    experiences: merge(
      existing.experiences,
      cv.experiences,
      previous?.experiences,
      (e) => e.id,
      (e) => e.toJson(),
    ),
    education: merge(
      existing.education,
      cv.education,
      previous?.education,
      (e) => e.id,
      (e) => e.toJson(),
    ),
    skills: merge(
      existing.skills,
      cv.skills,
      previous?.skills,
      (e) => e.id,
      (e) => e.toJson(),
    ),
    languages: merge(
      existing.languages,
      cv.languages,
      previous?.languages,
      (e) => e.id,
      (e) => e.toJson(),
    ),
    certificates: merge(
      existing.certificates,
      cv.certificates,
      previous?.certificates,
      (e) => e.id,
      (e) => e.toJson(),
    ),
    courses: merge(
      existing.courses,
      cv.courses,
      previous?.courses,
      (e) => e.id,
      (e) => e.toJson(),
    ),
    awards: merge(
      existing.awards,
      cv.awards,
      previous?.awards,
      (e) => e.id,
      (e) => e.toJson(),
    ),
    volunteer: merge(
      existing.volunteer,
      cv.volunteer,
      previous?.volunteer,
      (e) => e.id,
      (e) => e.toJson(),
    ),
    publications: merge(
      existing.publications,
      cv.publications,
      previous?.publications,
      (e) => e.id,
      (e) => e.toJson(),
    ),
    references: merge(
      existing.references,
      cv.references,
      previous?.references,
      (e) => e.id,
      (e) => e.toJson(),
    ),
    projects: merge(
      existing.projects,
      cv.projects,
      previous?.projects,
      (e) => e.id,
      (e) => e.toJson(),
    ),
    customSections: merge(
      existing.customSections,
      cv.customSections,
      previous?.customSections,
      (e) => e.id,
      (e) => e.toJson(),
    ),
    updatedAtIso: DateTime.now().toIso8601String(),
  );
}

/// Adds newly authored sections without changing saved visibility/order choices.
DocumentDesign withProfileCustomSections(
  DocumentDesign design,
  UserProfile profile,
) {
  final ids = design.sections.map((section) => section.customSectionId).toSet();
  final missing = profile.customSections
      .where((section) => !ids.contains(section.id))
      .toList();
  if (missing.isEmpty) return design;
  return design.copyWith(
    sections: [
      ...design.sections,
      for (final section in missing)
        SectionConfig(
          id: 'custom-${section.id}',
          kind: SectionKind.custom,
          customSectionId: section.id,
        ),
    ],
  );
}
