/// Document and layout configuration models.
///
/// A [CvDocument] stores *configuration* (which sections appear, where, and how
/// they look). Content itself lives in [UserProfile], so several documents can
/// reuse the same profile with different presentation.
/// Hand-written document design + entity models (no code generation).
library;

import 'package:cv_portfolio_maker/core/domain/enum_converters.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';

/// Per-section visibility and ordering configuration.
class SectionConfig {
  const SectionConfig({
    required this.id,
    this.kind = SectionKind.profile,
    this.customTitle,
    this.visible = true,
    this.slot = ColumnSlot.fullWidth,
    this.fieldVisibility = const <String, bool>{},
    this.hiddenEntryIds = const <String>[],
    this.entryOrder,
    this.pageBreakBefore = false,
    this.customSectionId,
  });

  final String id;
  final SectionKind kind;
  final String? customTitle;
  final bool visible;
  final ColumnSlot slot;
  final Map<String, bool> fieldVisibility;
  final List<String> hiddenEntryIds;
  final List<String>? entryOrder;
  final bool pageBreakBefore;
  final String? customSectionId;

  bool get isPageBreak => kind == SectionKind.pageBreak;

  String resolvedTitle(String Function(SectionKind) defaultTitle) {
    final custom = customTitle?.trim();
    return (custom == null || custom.isEmpty) ? defaultTitle(kind) : custom;
  }

  List<T> applyOrder<T>(List<T> items, String Function(T) idOf) {
    if (entryOrder == null || entryOrder!.isEmpty) return items;
    final byId = {for (final item in items) idOf(item): item};
    final ordered = <T>[];
    for (final id in entryOrder!) {
      final item = byId.remove(id);
      if (item != null) ordered.add(item);
    }
    ordered.addAll(byId.values);
    return ordered;
  }

  SectionConfig copyWith({
    String? id,
    SectionKind? kind,
    String? Function()? customTitle,
    bool? visible,
    ColumnSlot? slot,
    Map<String, bool>? fieldVisibility,
    List<String>? hiddenEntryIds,
    List<String>? Function()? entryOrder,
    bool? pageBreakBefore,
    String? Function()? customSectionId,
  }) => SectionConfig(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    customTitle: customTitle == null ? this.customTitle : customTitle(),
    visible: visible ?? this.visible,
    slot: slot ?? this.slot,
    fieldVisibility: fieldVisibility ?? this.fieldVisibility,
    hiddenEntryIds: hiddenEntryIds ?? this.hiddenEntryIds,
    entryOrder: entryOrder == null ? this.entryOrder : entryOrder(),
    pageBreakBefore: pageBreakBefore ?? this.pageBreakBefore,
    customSectionId: customSectionId == null
        ? this.customSectionId
        : customSectionId(),
  );

  factory SectionConfig.fromJson(Map<String, dynamic> json) {
    final rawFields = json['fieldVisibility'];
    return SectionConfig(
      id: '${json['id'] ?? ''}',
      kind: SectionKindX.fromKey('${json['kind'] ?? 'profile'}'),
      customTitle: json['customTitle'] as String?,
      visible: json['visible'] as bool? ?? true,
      slot:
          ColumnSlot.values.asNameMap()['${json['slot']}'] ??
          ColumnSlot.fullWidth,
      fieldVisibility: rawFields is Map
          ? Map<String, bool>.from(
              rawFields.map((k, v) => MapEntry('$k', v == true)),
            )
          : const <String, bool>{},
      hiddenEntryIds: json['hiddenEntryIds'] is List
          ? List<String>.from((json['hiddenEntryIds'] as List).map((e) => '$e'))
          : const <String>[],
      entryOrder: json['entryOrder'] is List
          ? List<String>.from((json['entryOrder'] as List).map((e) => '$e'))
          : null,
      pageBreakBefore: json['pageBreakBefore'] as bool? ?? false,
      customSectionId: json['customSectionId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.key,
    'customTitle': customTitle,
    'visible': visible,
    'slot': slot.name,
    'fieldVisibility': fieldVisibility,
    'hiddenEntryIds': hiddenEntryIds,
    'entryOrder': entryOrder,
    'pageBreakBefore': pageBreakBefore,
    'customSectionId': customSectionId,
  };
}

/// Typography configuration shared by every rendering target.
class TypographyConfig {
  const TypographyConfig({
    this.headingFont = 'inter',
    this.bodyFont = 'inter',
    this.bodyFontSize = 10.5,
    this.headingFontSize = 18.0,
    this.sectionTitleFontSize = 14.0,
    this.headingScale = 1.0,
    this.bodyLineHeight = 1.35,
    this.headingLineHeight = 1.2,
    this.uppercaseSectionTitles = false,
    this.headingLetterSpacing = 0.2,
  });

  final String headingFont;
  final String bodyFont;
  final double bodyFontSize;
  final double headingFontSize;
  final double sectionTitleFontSize;
  final double headingScale;
  final double bodyLineHeight;
  final double headingLineHeight;
  final bool uppercaseSectionTitles;
  final double headingLetterSpacing;

  TypographyConfig copyWith({
    String? headingFont,
    String? bodyFont,
    double? bodyFontSize,
    double? headingFontSize,
    double? sectionTitleFontSize,
    double? headingScale,
    double? bodyLineHeight,
    double? headingLineHeight,
    bool? uppercaseSectionTitles,
    double? headingLetterSpacing,
  }) => TypographyConfig(
    headingFont: headingFont ?? this.headingFont,
    bodyFont: bodyFont ?? this.bodyFont,
    bodyFontSize: bodyFontSize ?? this.bodyFontSize,
    headingFontSize: headingFontSize ?? this.headingFontSize,
    sectionTitleFontSize: sectionTitleFontSize ?? this.sectionTitleFontSize,
    headingScale: headingScale ?? this.headingScale,
    bodyLineHeight: bodyLineHeight ?? this.bodyLineHeight,
    headingLineHeight: headingLineHeight ?? this.headingLineHeight,
    uppercaseSectionTitles:
        uppercaseSectionTitles ?? this.uppercaseSectionTitles,
    headingLetterSpacing: headingLetterSpacing ?? this.headingLetterSpacing,
  );

  factory TypographyConfig.fromJson(
    Map<String, dynamic> json,
  ) => TypographyConfig(
    headingFont: '${json['headingFont'] ?? 'inter'}',
    bodyFont: '${json['bodyFont'] ?? 'inter'}',
    bodyFontSize: (json['bodyFontSize'] as num?)?.toDouble() ?? 10.5,
    headingFontSize: (json['headingFontSize'] as num?)?.toDouble() ?? 18.0,
    sectionTitleFontSize:
        (json['sectionTitleFontSize'] as num?)?.toDouble() ?? 14.0,
    headingScale: (json['headingScale'] as num?)?.toDouble() ?? 1.0,
    bodyLineHeight: (json['bodyLineHeight'] as num?)?.toDouble() ?? 1.35,
    headingLineHeight: (json['headingLineHeight'] as num?)?.toDouble() ?? 1.2,
    uppercaseSectionTitles: json['uppercaseSectionTitles'] as bool? ?? false,
    headingLetterSpacing:
        (json['headingLetterSpacing'] as num?)?.toDouble() ?? 0.2,
  );

  Map<String, dynamic> toJson() => {
    'headingFont': headingFont,
    'bodyFont': bodyFont,
    'bodyFontSize': bodyFontSize,
    'headingFontSize': headingFontSize,
    'sectionTitleFontSize': sectionTitleFontSize,
    'headingScale': headingScale,
    'bodyLineHeight': bodyLineHeight,
    'headingLineHeight': headingLineHeight,
    'uppercaseSectionTitles': uppercaseSectionTitles,
    'headingLetterSpacing': headingLetterSpacing,
  };
}

/// Colour palette for a document, stored as ARGB integers.
class ColorConfig {
  const ColorConfig({
    this.primary = 0xFF1F2933,
    this.secondary = 0xFF52606D,
    this.accent = 0xFF2563EB,
    this.paper = 0xFFFFFFFF,
    this.background = 0xFFFFFFFF,
    // Headings (the name, section titles) default to the body colour: nothing
    // in the renderers paints a dark band behind them, so a white default would
    // make the name invisible on the default white paper.
    this.headingText = 0xFF1F2933,
    this.bodyText = 0xFF1F2933,
    this.divider = 0xFFCBD2D9,
  });

  final int primary;
  final int secondary;
  final int accent;
  final int paper;
  final int background;
  final int headingText;
  final int bodyText;
  final int divider;

  ColorConfig copyWith({
    int? primary,
    int? secondary,
    int? accent,
    int? paper,
    int? background,
    int? headingText,
    int? bodyText,
    int? divider,
  }) => ColorConfig(
    primary: primary ?? this.primary,
    secondary: secondary ?? this.secondary,
    accent: accent ?? this.accent,
    paper: paper ?? this.paper,
    background: background ?? this.background,
    headingText: headingText ?? this.headingText,
    bodyText: bodyText ?? this.bodyText,
    divider: divider ?? this.divider,
  );

  factory ColorConfig.fromJson(Map<String, dynamic> json) => ColorConfig(
    primary: (json['primary'] as num?)?.toInt() ?? 0xFF1F2933,
    secondary: (json['secondary'] as num?)?.toInt() ?? 0xFF52606D,
    accent: (json['accent'] as num?)?.toInt() ?? 0xFF2563EB,
    paper: (json['paper'] as num?)?.toInt() ?? 0xFFFFFFFF,
    background: (json['background'] as num?)?.toInt() ?? 0xFFFFFFFF,
    headingText: (json['headingText'] as num?)?.toInt() ?? 0xFF1F2933,
    bodyText: (json['bodyText'] as num?)?.toInt() ?? 0xFF1F2933,
    divider: (json['divider'] as num?)?.toInt() ?? 0xFFCBD2D9,
  );

  Map<String, dynamic> toJson() => {
    'primary': primary,
    'secondary': secondary,
    'accent': accent,
    'paper': paper,
    'background': background,
    'headingText': headingText,
    'bodyText': bodyText,
    'divider': divider,
  };
}

/// Spacing, margins and geometry.
class SpacingConfig {
  const SpacingConfig({
    this.pageMargin = 40.0,
    this.pagePadding = 0.0,
    this.sectionSpacing = 16.0,
    this.itemSpacing = 8.0,
    this.paragraphSpacing = 6.0,
    this.columnGap = 16.0,
    this.leftColumnRatio = 0.38,
    this.isRtl = false,
  });

  /// Extra inner padding for the document surface.
  final double pageMargin;
  final double pagePadding;
  final double sectionSpacing;
  final double itemSpacing;
  final double paragraphSpacing;
  final double columnGap;

  /// Relative width of the left column (0.2 - 0.8).
  final double leftColumnRatio;

  /// Renders the document right-to-left.
  final bool isRtl;

  SpacingConfig copyWith({
    double? pageMargin,
    double? pagePadding,
    double? sectionSpacing,
    double? itemSpacing,
    double? paragraphSpacing,
    double? columnGap,
    double? leftColumnRatio,
    bool? isRtl,
  }) => SpacingConfig(
    pageMargin: pageMargin ?? this.pageMargin,
    pagePadding: pagePadding ?? this.pagePadding,
    sectionSpacing: sectionSpacing ?? this.sectionSpacing,
    itemSpacing: itemSpacing ?? this.itemSpacing,
    paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
    columnGap: columnGap ?? this.columnGap,
    leftColumnRatio: leftColumnRatio ?? this.leftColumnRatio,
    isRtl: isRtl ?? this.isRtl,
  );

  factory SpacingConfig.fromJson(Map<String, dynamic> json) => SpacingConfig(
    pageMargin: (json['pageMargin'] as num?)?.toDouble() ?? 40.0,
    pagePadding: (json['pagePadding'] as num?)?.toDouble() ?? 0.0,
    sectionSpacing: (json['sectionSpacing'] as num?)?.toDouble() ?? 16.0,
    itemSpacing: (json['itemSpacing'] as num?)?.toDouble() ?? 8.0,
    paragraphSpacing: (json['paragraphSpacing'] as num?)?.toDouble() ?? 6.0,
    columnGap: (json['columnGap'] as num?)?.toDouble() ?? 16.0,
    leftColumnRatio: (json['leftColumnRatio'] as num?)?.toDouble() ?? 0.38,
    isRtl: json['isRtl'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'pageMargin': pageMargin,
    'pagePadding': pagePadding,
    'sectionSpacing': sectionSpacing,
    'itemSpacing': itemSpacing,
    'paragraphSpacing': paragraphSpacing,
    'columnGap': columnGap,
    'leftColumnRatio': leftColumnRatio,
    'isRtl': isRtl,
  };
}

/// Page geometry and header/footer behaviour.
class PageConfig {
  const PageConfig({
    this.pageSize = 'a4',
    this.portrait = true,
    this.showPageNumbers = true,
    this.showHeader = false,
    this.headerText,
    this.showFooter = false,
    this.footerText,
  });

  /// Page size key: `a4`, `letter` or `legal`.
  final String pageSize;
  final bool portrait;
  final bool showPageNumbers;
  final bool showHeader;
  final String? headerText;
  final bool showFooter;
  final String? footerText;

  PageConfig copyWith({
    String? pageSize,
    bool? portrait,
    bool? showPageNumbers,
    bool? showHeader,
    String? headerText,
    bool? showFooter,
    String? footerText,
  }) => PageConfig(
    pageSize: pageSize ?? this.pageSize,
    portrait: portrait ?? this.portrait,
    showPageNumbers: showPageNumbers ?? this.showPageNumbers,
    showHeader: showHeader ?? this.showHeader,
    headerText: headerText ?? this.headerText,
    showFooter: showFooter ?? this.showFooter,
    footerText: footerText ?? this.footerText,
  );

  factory PageConfig.fromJson(Map<String, dynamic> json) => PageConfig(
    pageSize: '${json['pageSize'] ?? 'a4'}',
    portrait: json['portrait'] as bool? ?? true,
    showPageNumbers: json['showPageNumbers'] as bool? ?? true,
    showHeader: json['showHeader'] as bool? ?? false,
    headerText: json['headerText'] as String?,
    showFooter: json['showFooter'] as bool? ?? false,
    footerText: json['footerText'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'pageSize': pageSize,
    'portrait': portrait,
    'showPageNumbers': showPageNumbers,
    'showHeader': showHeader,
    'headerText': headerText,
    'showFooter': showFooter,
    'footerText': footerText,
  };
}

/// Visual presentation options.
class PresentationConfig {
  const PresentationConfig({
    this.dividerStyle = DividerStyle.thin,
    this.avatarShape = AvatarShape.circle,
    this.avatarSize = 72.0,
    this.showContactIcons = true,
    this.contactInline = false,
    this.showSectionIcons = true,
    this.headerStyle = 'split',
    this.projectCardStyle = 'card',
    this.projectImageAspectRatio = 1.6,
    this.showProjectTechChips = true,
  });

  final DividerStyle dividerStyle;
  final AvatarShape avatarShape;

  /// Avatar diameter in points.
  final double avatarSize;
  final bool showContactIcons;

  /// `true` stacks contact details, `false` separates with bullets.
  final bool contactInline;
  final bool showSectionIcons;

  /// Header style: `left`, `center` or `split`.
  final String headerStyle;

  /// Portfolio project card style: `card`, `flat` or `gallery`.
  final String projectCardStyle;

  /// Aspect ratio (width / height) for project cover images.
  final double projectImageAspectRatio;
  final bool showProjectTechChips;

  PresentationConfig copyWith({
    DividerStyle? dividerStyle,
    AvatarShape? avatarShape,
    double? avatarSize,
    bool? showContactIcons,
    bool? contactInline,
    bool? showSectionIcons,
    String? headerStyle,
    String? projectCardStyle,
    double? projectImageAspectRatio,
    bool? showProjectTechChips,
  }) => PresentationConfig(
    dividerStyle: dividerStyle ?? this.dividerStyle,
    avatarShape: avatarShape ?? this.avatarShape,
    avatarSize: avatarSize ?? this.avatarSize,
    showContactIcons: showContactIcons ?? this.showContactIcons,
    contactInline: contactInline ?? this.contactInline,
    showSectionIcons: showSectionIcons ?? this.showSectionIcons,
    headerStyle: headerStyle ?? this.headerStyle,
    projectCardStyle: projectCardStyle ?? this.projectCardStyle,
    projectImageAspectRatio:
        projectImageAspectRatio ?? this.projectImageAspectRatio,
    showProjectTechChips: showProjectTechChips ?? this.showProjectTechChips,
  );

  factory PresentationConfig.fromJson(Map<String, dynamic> json) =>
      PresentationConfig(
        dividerStyle: const DividerStyleConverter().fromJson(
          json['dividerStyle'],
        ),
        avatarShape: const AvatarShapeConverter().fromJson(json['avatarShape']),
        avatarSize: (json['avatarSize'] as num?)?.toDouble() ?? 72.0,
        showContactIcons: json['showContactIcons'] as bool? ?? true,
        contactInline: json['contactInline'] as bool? ?? false,
        showSectionIcons: json['showSectionIcons'] as bool? ?? true,
        headerStyle: '${json['headerStyle'] ?? 'split'}',
        projectCardStyle: '${json['projectCardStyle'] ?? 'card'}',
        projectImageAspectRatio:
            (json['projectImageAspectRatio'] as num?)?.toDouble() ?? 1.6,
        showProjectTechChips: json['showProjectTechChips'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
    'dividerStyle': const DividerStyleConverter().toJson(dividerStyle),
    'avatarShape': const AvatarShapeConverter().toJson(avatarShape),
    'avatarSize': avatarSize,
    'showContactIcons': showContactIcons,
    'contactInline': contactInline,
    'showSectionIcons': showSectionIcons,
    'headerStyle': headerStyle,
    'projectCardStyle': projectCardStyle,
    'projectImageAspectRatio': projectImageAspectRatio,
    'showProjectTechChips': showProjectTechChips,
  };
}

/// The complete design configuration for a document.
///
/// This single model drives on-screen previews, PDF export and public pages so
/// all outputs stay consistent.
class DocumentDesign {
  const DocumentDesign({
    this.layoutMode = LayoutMode.one,
    this.typography = const TypographyConfig(),
    this.colors = const ColorConfig(),
    this.spacing = const SpacingConfig(),
    this.page = const PageConfig(),
    this.presentation = const PresentationConfig(),
    this.sections = const <SectionConfig>[],
    this.templateId = 'minimal',
    this.isRtl = false,
  });

  final LayoutMode layoutMode;
  final TypographyConfig typography;
  final ColorConfig colors;
  final SpacingConfig spacing;
  final PageConfig page;
  final PresentationConfig presentation;
  final List<SectionConfig> sections;

  /// Template this design originated from, for "reset to template".
  final String templateId;
  final bool isRtl;

  DocumentDesign copyWith({
    LayoutMode? layoutMode,
    TypographyConfig? typography,
    ColorConfig? colors,
    SpacingConfig? spacing,
    PageConfig? page,
    PresentationConfig? presentation,
    List<SectionConfig>? sections,
    String? templateId,
    bool? isRtl,
  }) => DocumentDesign(
    layoutMode: layoutMode ?? this.layoutMode,
    typography: typography ?? this.typography,
    colors: colors ?? this.colors,
    spacing: spacing ?? this.spacing,
    page: page ?? this.page,
    presentation: presentation ?? this.presentation,
    sections: sections ?? this.sections,
    templateId: templateId ?? this.templateId,
    isRtl: isRtl ?? this.isRtl,
  );

  factory DocumentDesign.fromJson(Map<String, dynamic> json) {
    List<SectionConfig> sectionsOf(dynamic raw) {
      if (raw is! List) return const <SectionConfig>[];
      return raw
          .whereType<Map>()
          .map((e) => SectionConfig.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    T nested<T>(
      dynamic raw,
      T Function(Map<String, dynamic>) decode,
      T fallback,
    ) => raw is Map ? decode(Map<String, dynamic>.from(raw)) : fallback;

    return DocumentDesign(
      layoutMode: const LayoutModeConverter().fromJson(json['layoutMode']),
      typography: nested(
        json['typography'],
        TypographyConfig.fromJson,
        const TypographyConfig(),
      ),
      colors: nested(json['colors'], ColorConfig.fromJson, const ColorConfig()),
      spacing: nested(
        json['spacing'],
        SpacingConfig.fromJson,
        const SpacingConfig(),
      ),
      page: nested(json['page'], PageConfig.fromJson, const PageConfig()),
      presentation: nested(
        json['presentation'],
        PresentationConfig.fromJson,
        const PresentationConfig(),
      ),
      sections: sectionsOf(json['sections']),
      templateId: '${json['templateId'] ?? 'minimal'}',
      isRtl: json['isRtl'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'layoutMode': const LayoutModeConverter().toJson(layoutMode),
    'typography': typography.toJson(),
    'colors': colors.toJson(),
    'spacing': spacing.toJson(),
    'page': page.toJson(),
    'presentation': presentation.toJson(),
    'sections': sections.map((s) => s.toJson()).toList(),
    'templateId': templateId,
    'isRtl': isRtl,
  };
}

/// Extension helpers for [DocumentDesign].
extension DocumentDesignX on DocumentDesign {
  /// Visible sections in stored order (page breaks included).
  List<SectionConfig> get visibleSections =>
      sections.where((s) => s.visible).toList();

  /// Sections assigned to the full width.
  List<SectionConfig> get fullWidthSections =>
      visibleSections.where((s) => s.slot == ColumnSlot.fullWidth).toList();

  /// Sections assigned to the left column.
  List<SectionConfig> get leftSections =>
      visibleSections.where((s) => s.slot == ColumnSlot.left).toList();

  /// Sections assigned to the right column.
  List<SectionConfig> get rightSections =>
      visibleSections.where((s) => s.slot == ColumnSlot.right).toList();

  /// `true` when the layout uses two columns.
  bool get usesTwoColumns =>
      layoutMode == LayoutMode.two || layoutMode == LayoutMode.mix;

  /// Looks up a section by kind.
  SectionConfig? sectionOf(SectionKind kind) {
    for (final section in sections) {
      if (section.kind == kind) return section;
    }
    return null;
  }
}
