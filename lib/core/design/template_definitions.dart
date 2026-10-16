/// Concrete template definitions used by the template catalogue.
///
/// Each function returns a [DocumentDesign] tailored to a document type.
library;

import 'package:cv_portfolio_maker/core/domain/document_models.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';

import 'templates.dart';

/// Clean single column with generous whitespace.
DocumentDesign buildMinimalTemplate(DocumentType type) => DocumentDesign(
  layoutMode: LayoutMode.one,
  templateId: 'minimal',
  sections: defaultSections(isPortfolio: type == DocumentType.portfolio)
      .map((s) => s.copyWith(slot: ColumnSlot.fullWidth))
      .toList(),
  colors: const ColorConfig(
    primary: 0xFF111827,
    secondary: 0xFF4B5563,
    accent: 0xFF111827,
    headingText: 0xFF111827,
    bodyText: 0xFF1F2933,
    divider: 0xFFE5E7EB,
  ),
  typography: const TypographyConfig(
    headingFont: 'inter',
    bodyFont: 'inter',
    bodyFontSize: 10.5,
    headingScale: 1.0,
  ),
  presentation: const PresentationConfig(
    dividerStyle: DividerStyle.thin,
    avatarShape: AvatarShape.circle,
    headerStyle: 'left',
    projectCardStyle: 'flat',
  ),
);

/// Two column layout with an accent sidebar.
DocumentDesign buildModernTemplate(DocumentType type) => DocumentDesign(
  layoutMode: LayoutMode.two,
  templateId: 'modern',
  sections: defaultSections(isPortfolio: type == DocumentType.portfolio),
  colors: const ColorConfig(
    primary: 0xFF0F172A,
    secondary: 0xFF64748B,
    accent: 0xFF2563EB,
    headingText: 0xFF0F172A,
    bodyText: 0xFF1E293B,
    divider: 0xFFCBD5E1,
  ),
  spacing: const SpacingConfig(
    leftColumnRatio: 0.36,
    columnGap: 20,
    sectionSpacing: 18,
  ),
  presentation: const PresentationConfig(
    dividerStyle: DividerStyle.thin,
    avatarShape: AvatarShape.roundedSquare,
    headerStyle: 'split',
    projectCardStyle: 'card',
  ),
);

/// Traditional serif headings with a centred header.
DocumentDesign buildClassicTemplate(DocumentType type) => DocumentDesign(
  layoutMode: LayoutMode.one,
  templateId: 'classic',
  sections: defaultSections(isPortfolio: type == DocumentType.portfolio)
      .map((s) => s.copyWith(slot: ColumnSlot.fullWidth))
      .toList(),
  colors: const ColorConfig(
    primary: 0xFF1C1917,
    secondary: 0xFF57534E,
    accent: 0xFF78350F,
    headingText: 0xFF1C1917,
    bodyText: 0xFF292524,
    divider: 0xFFD6D3D1,
  ),
  typography: const TypographyConfig(
    headingFont: 'merriweather',
    bodyFont: 'lora',
    bodyFontSize: 10.5,
    headingScale: 1.05,
    uppercaseSectionTitles: false,
  ),
  presentation: const PresentationConfig(
    dividerStyle: DividerStyle.thick,
    avatarShape: AvatarShape.square,
    headerStyle: 'center',
    projectCardStyle: 'flat',
  ),
);

/// Conservative styling for corporate roles.
DocumentDesign buildProfessionalTemplate(DocumentType type) => DocumentDesign(
  layoutMode: LayoutMode.one,
  templateId: 'professional',
  sections: defaultSections(isPortfolio: type == DocumentType.portfolio)
      .map((s) => s.copyWith(slot: ColumnSlot.fullWidth))
      .toList(),
  colors: const ColorConfig(
    primary: 0xFF1E3A5F,
    secondary: 0xFF475569,
    accent: 0xFF1E3A5F,
    headingText: 0xFF1E3A5F,
    bodyText: 0xFF1F2933,
    divider: 0xFFCBD5E1,
  ),
  typography: const TypographyConfig(
    headingFont: 'inter',
    bodyFont: 'inter',
    uppercaseSectionTitles: true,
    headingLetterSpacing: 0.8,
  ),
  presentation: const PresentationConfig(
    dividerStyle: DividerStyle.thin,
    avatarShape: AvatarShape.circle,
    headerStyle: 'left',
    contactInline: true,
    projectCardStyle: 'card',
  ),
);

/// Bold colours with a mixed, asymmetric layout.
DocumentDesign buildCreativeTemplate(DocumentType type) => DocumentDesign(
  layoutMode: LayoutMode.mix,
  templateId: 'creative',
  sections: defaultSections(isPortfolio: type == DocumentType.portfolio),
  colors: const ColorConfig(
    primary: 0xFF7C3AED,
    secondary: 0xFF6B7280,
    accent: 0xFFEC4899,
    headingText: 0xFF4C1D95,
    bodyText: 0xFF1F2933,
    divider: 0xFFDDD6FE,
  ),
  spacing: const SpacingConfig(
    leftColumnRatio: 0.42,
    columnGap: 22,
    sectionSpacing: 20,
  ),
  typography: const TypographyConfig(
    headingFont: 'poppins',
    bodyFont: 'inter',
    headingScale: 1.1,
  ),
  presentation: const PresentationConfig(
    dividerStyle: DividerStyle.gradient,
    avatarShape: AvatarShape.circle,
    headerStyle: 'center',
    projectCardStyle: 'gallery',
    projectImageAspectRatio: 1.4,
  ),
);

/// Dense, technical, project-forward single column.
DocumentDesign buildDeveloperTemplate(DocumentType type) => DocumentDesign(
  layoutMode: LayoutMode.one,
  templateId: 'developer',
  sections: defaultSections(isPortfolio: type == DocumentType.portfolio)
      .map((s) => s.copyWith(slot: ColumnSlot.fullWidth))
      .toList(),
  colors: const ColorConfig(
    primary: 0xFF0F172A,
    secondary: 0xFF64748B,
    accent: 0xFF0EA5E9,
    headingText: 0xFF0F172A,
    bodyText: 0xFF1E293B,
    divider: 0xFFCBD5E1,
  ),
  typography: const TypographyConfig(
    headingFont: 'jetbrainsmono',
    bodyFont: 'inter',
    bodyFontSize: 10,
    uppercaseSectionTitles: true,
    headingScale: 0.95,
  ),
  spacing: const SpacingConfig(
    pageMargin: 36,
    sectionSpacing: 14,
    itemSpacing: 6,
  ),
  presentation: const PresentationConfig(
    dividerStyle: DividerStyle.dotted,
    avatarShape: AvatarShape.roundedSquare,
    headerStyle: 'split',
    projectCardStyle: 'card',
  ),
);

/// Gallery-first portfolio with large cover images.
DocumentDesign buildDesignerTemplate(DocumentType type) => DocumentDesign(
  layoutMode: LayoutMode.two,
  templateId: 'designer',
  sections: defaultSections(isPortfolio: type == DocumentType.portfolio),
  colors: const ColorConfig(
    primary: 0xFF18181B,
    secondary: 0xFF71717A,
    accent: 0xFFF59E0B,
    headingText: 0xFF18181B,
    bodyText: 0xFF27272A,
    divider: 0xFFE4E4E7,
  ),
  spacing: const SpacingConfig(
    leftColumnRatio: 0.32,
    columnGap: 24,
    sectionSpacing: 20,
  ),
  typography: const TypographyConfig(
    headingFont: 'playfairdisplay',
    bodyFont: 'inter',
    headingScale: 1.15,
    headingLetterSpacing: 0,
  ),
  presentation: const PresentationConfig(
    dividerStyle: DividerStyle.none,
    avatarShape: AvatarShape.roundedSquare,
    avatarSize: 88,
    headerStyle: 'center',
    projectCardStyle: 'gallery',
    projectImageAspectRatio: 1.25,
  ),
);
