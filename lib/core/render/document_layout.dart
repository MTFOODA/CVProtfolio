/// Pure layout helpers for the shared rendering engine.
///
/// These functions are kept side-effect free so they can be unit tested
/// without a widget tree. The [DocumentView] widget and future exporters both
/// depend on this single source of truth for column placement.
library;

import 'package:cv_portfolio_maker/core/domain/enums.dart';
import 'package:cv_portfolio_maker/core/render/resolved_document.dart';

/// Clamps a column ratio into a usable range so a column can never become
/// illegibly narrow or collapse entirely.
double clampColumnRatio(double ratio) {
  if (ratio.isNaN || ratio.isInfinite) return 0.5;
  return ratio.clamp(0.25, 0.75).toDouble();
}

/// The three column buckets a document layout is composed of.
///
/// Every section lands in exactly one bucket based on its [ColumnSlot]. The
/// renderer decides how to arrange the buckets according to the layout mode.
class SectionColumns {
  const SectionColumns({
    required this.full,
    required this.left,
    required this.right,
  });

  final List<ResolvedSection> full;
  final List<ResolvedSection> left;
  final List<ResolvedSection> right;

  /// `true` when nothing was assigned to either column (e.g. a One layout
  /// where every section is full width).
  bool get hasColumns => left.isNotEmpty || right.isNotEmpty;
}

/// The effective column slot for [section].
///
/// Structural page breaks always span the full width so they are never trapped
/// inside a narrow column, regardless of how their slot was stored.
ColumnSlot effectiveSlot(ResolvedSection section) =>
    section.isPageBreak ? ColumnSlot.fullWidth : section.config.slot;

/// Partitions [sections] into full-width, left-column and right-column
/// buckets, preserving each bucket's internal reading order.
SectionColumns partitionSections(List<ResolvedSection> sections) {
  final full = <ResolvedSection>[];
  final left = <ResolvedSection>[];
  final right = <ResolvedSection>[];
  for (final section in sections) {
    switch (effectiveSlot(section)) {
      case ColumnSlot.fullWidth:
        full.add(section);
      case ColumnSlot.left:
        left.add(section);
      case ColumnSlot.right:
        right.add(section);
    }
  }
  return SectionColumns(full: full, left: left, right: right);
}

/// Buckets sections for a strict two-column layout.
///
/// Unlike `Mix`, `Two` never renders a full-width band: a `fullWidth` slot
/// (common when switching a single-column template to two columns) falls back
/// to the left column so no content is ever dropped. Reading order is
/// preserved within each column. When *no* section has been assigned to a
/// column yet, sections are alternated so a freshly switched document shows two
/// real columns instead of collapsing into one narrow one.
SectionColumns twoColumnBuckets(List<ResolvedSection> sections) {
  final buckets = partitionSections(sections);

  // Nothing was assigned to either column yet: auto-balance across both.
  if (buckets.left.isEmpty && buckets.right.isEmpty) {
    return SectionColumns(
      full: const [],
      left: [for (var i = 0; i < sections.length; i += 2) sections[i]],
      right: [for (var i = 1; i < sections.length; i += 2) sections[i]],
    );
  }

  return SectionColumns(
    full: const [],
    left: [
      for (final section in sections)
        if (effectiveSlot(section) != ColumnSlot.right) section,
    ],
    right: [
      for (final section in sections)
        if (effectiveSlot(section) == ColumnSlot.right) section,
    ],
  );
}

/// A single horizontal band of a mixed layout.
///
/// Either a full-width band ([isFullWidth] `true`, content in [full]) or a
/// left/right column pair. Splitting the document into bands is what lets
/// `Mix` interleave full-width content with columns in reading order instead
/// of stacking every full-width section above the columns.
class LayoutRow {
  LayoutRow.full(List<ResolvedSection> sections)
    : isFullWidth = true,
      full = List.unmodifiable(sections),
      left = const [],
      right = const [];

  LayoutRow.columns({
    required List<ResolvedSection> left,
    required List<ResolvedSection> right,
  }) : isFullWidth = false,
       full = const [],
       left = List.unmodifiable(left),
       right = List.unmodifiable(right);

  final bool isFullWidth;
  final List<ResolvedSection> full;
  final List<ResolvedSection> left;
  final List<ResolvedSection> right;
}

/// Builds the ordered bands for a `Mix` layout.
///
/// Full-width sections (and page breaks) keep their position in the reading
/// order; consecutive left/right sections are grouped into a single column
/// band so their tops stay aligned. This is the semantic difference between
/// `Mix` and `Two`.
List<LayoutRow> buildMixRows(List<ResolvedSection> sections) {
  final rows = <LayoutRow>[];
  final pendingLeft = <ResolvedSection>[];
  final pendingRight = <ResolvedSection>[];

  void flushColumns() {
    if (pendingLeft.isEmpty && pendingRight.isEmpty) return;
    rows.add(
      LayoutRow.columns(
        left: List.of(pendingLeft),
        right: List.of(pendingRight),
      ),
    );
    pendingLeft.clear();
    pendingRight.clear();
  }

  for (final section in sections) {
    switch (effectiveSlot(section)) {
      case ColumnSlot.fullWidth:
        flushColumns();
        rows.add(LayoutRow.full([section]));
      case ColumnSlot.left:
        pendingLeft.add(section);
      case ColumnSlot.right:
        pendingRight.add(section);
    }
  }
  flushColumns();
  return rows;
}
