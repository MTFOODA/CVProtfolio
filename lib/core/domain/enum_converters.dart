/// JSON converters for the domain enums.
///
/// These make persistence explicit and resilient to unknown values, which
/// matters when reading rows written by an older app version. They are plain
/// hand-written converters (no code generation, no `json_annotation`).
library;

import 'enums.dart';

/// Reads an enum by name, falling back to [fallback].
T _byName<T extends Enum>(List<T> values, Object? raw, T fallback) {
  if (raw is String) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
  }
  return fallback;
}

class DocumentTypeConverter {
  const DocumentTypeConverter();

  DocumentType fromJson(Object? json) =>
      _byName(DocumentType.values, json, DocumentType.cv);

  String toJson(DocumentType object) => object.name;
}

class ShareModeConverter {
  const ShareModeConverter();

  ShareMode fromJson(Object? json) =>
      _byName(ShareMode.values, json, ShareMode.privateDraft);

  String toJson(ShareMode object) => object.name;
}

class SectionKindConverter {
  const SectionKindConverter();

  SectionKind fromJson(Object? json) =>
      SectionKindX.fromKey(json is String ? json : '');

  String toJson(SectionKind object) => object.key;
}

class ColumnSlotConverter {
  const ColumnSlotConverter();

  ColumnSlot fromJson(Object? json) =>
      _byName(ColumnSlot.values, json, ColumnSlot.fullWidth);

  String toJson(ColumnSlot object) => object.name;
}

class LayoutModeConverter {
  const LayoutModeConverter();

  LayoutMode fromJson(Object? json) =>
      _byName(LayoutMode.values, json, LayoutMode.one);

  String toJson(LayoutMode object) => object.name;
}

class DividerStyleConverter {
  const DividerStyleConverter();

  DividerStyle fromJson(Object? json) =>
      _byName(DividerStyle.values, json, DividerStyle.thin);

  String toJson(DividerStyle object) => object.name;
}

class AvatarShapeConverter {
  const AvatarShapeConverter();

  AvatarShape fromJson(Object? json) =>
      _byName(AvatarShape.values, json, AvatarShape.circle);

  String toJson(AvatarShape object) => object.name;
}
