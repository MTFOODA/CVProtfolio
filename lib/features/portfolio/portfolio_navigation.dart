import 'package:flutter/material.dart';

import '../../core/design/app_icons.dart';
import '../../core/domain/enums.dart';
import '../../core/domain/profile_models.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/render/resolved_document.dart';

enum PortfolioPage {
  about,
  experience,
  projects,
  skills,
  credentials;

  String label(BuildContext context) => switch (this) {
    about => context.ui('About'),
    experience => context.tr('portfolioExperience'),
    projects => context.ui('Projects'),
    skills => context.ui('Skills'),
    credentials => context.tr('portfolioCredentials'),
  };
  IconData get icon => switch (this) {
    about => AppIcons.person,
    experience => AppIcons.portfolio,
    projects => AppIcons.code,
    skills => AppIcons.skills,
    credentials => AppIcons.certificate,
  };
}

/// Both owner and visitor navigation use the same resolved, authorized content.
class PortfolioContent {
  PortfolioContent(this.resolved, this.profile);
  final ResolvedDocument resolved;
  final UserProfile profile;

  PortfolioPage pageFor(ResolvedSection section) {
    if (section.config.kind == SectionKind.custom) {
      final category = profile.customSections
          .where((item) => item.id == section.config.customSectionId)
          .firstOrNull
          ?.category;
      return switch (category) {
        CustomSectionCategory.experience => PortfolioPage.experience,
        CustomSectionCategory.projects => PortfolioPage.projects,
        CustomSectionCategory.certificates ||
        CustomSectionCategory.courses => PortfolioPage.credentials,
        _ => PortfolioPage.about,
      };
    }
    return switch (section.config.kind) {
      SectionKind.experience => PortfolioPage.experience,
      SectionKind.projects => PortfolioPage.projects,
      SectionKind.skills => PortfolioPage.skills,
      SectionKind.certificates ||
      SectionKind.courses => PortfolioPage.credentials,
      _ => PortfolioPage.about,
    };
  }

  List<ResolvedSection> sections(PortfolioPage page) => resolved.sections
      .where(
        (section) =>
            !section.isPageBreak &&
            !section.isEmpty &&
            pageFor(section) == page,
      )
      .toList();

  List<PortfolioPage> get pages => [
    PortfolioPage.about,
    for (final page in PortfolioPage.values.skip(1))
      if (sections(page).isNotEmpty) page,
  ];
}
