/// Starting templates for CV and portfolio documents.
///
/// A template is a [DocumentDesign] factory. Users can customise the result
/// freely and reset back to the template at any time; templates are starting
/// points, never restrictions.
library;

import 'package:cv_portfolio_maker/core/design/template_definitions.dart';
import 'package:cv_portfolio_maker/core/domain/document_models.dart';
import 'package:cv_portfolio_maker/core/domain/enums.dart';

export 'package:cv_portfolio_maker/core/design/template_definitions.dart';

/// Metadata describing an available template.
class DesignTemplate {
  const DesignTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.build,
  });

  final String id;
  final String name;
  final String description;

  /// `minimal`, `modern`, `classic`, `professional`, `creative`,
  /// `developer` or `designer`.
  final String category;

  /// Creates the default [DocumentDesign] for this template.
  final DocumentDesign Function(DocumentType type) build;
}

/// The built-in template catalogue.
const List<DesignTemplate> builtinTemplates = [
  DesignTemplate(
    id: 'minimal',
    name: 'Minimal',
    description: 'Clean single column with generous whitespace.',
    category: 'minimal',
    build: buildMinimalTemplate,
  ),
  DesignTemplate(
    id: 'modern',
    name: 'Modern',
    description: 'Two column layout with an accent sidebar.',
    category: 'modern',
    build: buildModernTemplate,
  ),
  DesignTemplate(
    id: 'classic',
    name: 'Classic',
    description: 'Traditional serif headings, centred header.',
    category: 'classic',
    build: buildClassicTemplate,
  ),
  DesignTemplate(
    id: 'professional',
    name: 'Professional',
    description: 'Conservative styling for corporate roles.',
    category: 'professional',
    build: buildProfessionalTemplate,
  ),
  DesignTemplate(
    id: 'creative',
    name: 'Creative',
    description: 'Bold colours and a mixed, asymmetric layout.',
    category: 'creative',
    build: buildCreativeTemplate,
  ),
  DesignTemplate(
    id: 'developer',
    name: 'Developer',
    description: 'Dense, technical, project-forward single column.',
    category: 'developer',
    build: buildDeveloperTemplate,
  ),
  DesignTemplate(
    id: 'designer',
    name: 'Designer',
    description: 'Gallery-first portfolio with large cover images.',
    category: 'designer',
    build: buildDesignerTemplate,
  ),
];

/// Looks up a template by id, falling back to [minimal].
DesignTemplate templateById(String id) => builtinTemplates.firstWhere(
  (t) => t.id == id,
  orElse: () => builtinTemplates.first,
);

/// Builds a fresh [DocumentDesign] for a template and document type.
DocumentDesign designForTemplate(String templateId, DocumentType type) =>
    templateById(templateId).build(type);

/// The default section order applied to new documents.
List<SectionConfig> defaultSections({required bool isPortfolio}) {
  final sections = <SectionConfig>[
    const SectionConfig(
      id: 'personal_details',
      kind: SectionKind.personalDetails,
    ),
    const SectionConfig(id: 'profile', kind: SectionKind.profile),
    const SectionConfig(
      id: 'experience',
      kind: SectionKind.experience,
      slot: ColumnSlot.left,
    ),
    const SectionConfig(
      id: 'education',
      kind: SectionKind.education,
      slot: ColumnSlot.left,
    ),
    const SectionConfig(id: 'projects', kind: SectionKind.projects),
    const SectionConfig(
      id: 'skills',
      kind: SectionKind.skills,
      slot: ColumnSlot.right,
    ),
    const SectionConfig(
      id: 'languages',
      kind: SectionKind.languages,
      slot: ColumnSlot.right,
    ),
    const SectionConfig(
      id: 'certificates',
      kind: SectionKind.certificates,
      slot: ColumnSlot.left,
    ),
    const SectionConfig(id: 'courses', kind: SectionKind.courses),
    const SectionConfig(
      id: 'awards',
      kind: SectionKind.awards,
      slot: ColumnSlot.right,
    ),
  ];

  // Portfolios lead with projects.
  if (isPortfolio) {
    sections.removeWhere((s) => s.kind == SectionKind.projects);
    sections.insert(
      2,
      const SectionConfig(id: 'projects', kind: SectionKind.projects),
    );
  }
  return sections;
}

/// Sections a user may add to a document from the Layout screen.
const List<SectionKind> addableSections = [
  SectionKind.experience,
  SectionKind.education,
  SectionKind.certificates,
  SectionKind.projects,
  SectionKind.courses,
  SectionKind.skills,
  SectionKind.languages,
  SectionKind.awards,
  SectionKind.volunteer,
  SectionKind.publications,
  SectionKind.references,
  SectionKind.custom,
  SectionKind.pageBreak,
];
