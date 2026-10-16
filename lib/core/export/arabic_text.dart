/// Bidirectional text ordering and Arabic shaping for the PDF exporters.
///
/// `pdf` paints code points strictly left to right and performs no OpenType
/// shaping, so mixed-script text must be reordered and shaped *before* it is
/// handed to a `pw.Text`. This module does exactly that, using the `bidi`
/// package — the same engine `pdf` itself depends on.
///
/// `bidi.BidiString.fromLogical` applies the complete UAX #9 algorithm
/// (paragraph level from the first strong character, explicit embeddings, weak
/// and neutral resolution, implicit levels, L1 trailing whitespace, L4 mirrored
/// brackets) **and** Arabic/Persian joining forms with diacritic ligatures, and
/// returns the resulting visual order.
///
/// `pdf`'s own `bidi_utils.logicalToVisual` helper is deliberately *not* used.
/// It takes the already-visual result and then splits it on spaces and reverses
/// the word order a second time, which transposes words in multi-word Arabic
/// text. `test/bidi_and_shaping_test.dart` pins both behaviours.
library;

import 'package:bidi/bidi.dart' as bidi;

/// Right-to-left embedding (U+202B): forces an RTL paragraph direction.
const String _rle = '\u202B';

/// Pop directional formatting (U+202C).
const String _popDirectional = '\u202C';

/// Reorders and shapes [input] so it can be painted left to right.
///
/// Set [rtlBase] for documents whose design declares a right-to-left reading
/// direction; the paragraph direction is then forced to RTL regardless of the
/// first character. Otherwise the direction is derived from the first strong
/// character, per UAX #9 P2/P3, so an Arabic phrase inside an English document
/// still reads correctly.
///
/// The embedding markers used to force the direction are stripped by the engine
/// before the text is returned, so they never reach the output.
String prepareForPdf(String input, {required bool rtlBase}) {
  if (input.isEmpty) return input;

  // The engine splits paragraphs on the line separator and an explicit
  // embedding must not span one, so each line is processed on its own.
  final lines = input.split('\n');
  final out = StringBuffer();
  for (var i = 0; i < lines.length; i++) {
    if (i > 0) out.write('\n');
    final line = lines[i];
    if (line.isEmpty) continue;
    out.write(_visualOrder(rtlBase ? '$_rle$line$_popDirectional' : line));
  }
  return out.toString();
}

/// Returns one line's visual (left-to-right painting) order.
String _visualOrder(String line) {
  final codes = <int>[];
  for (final paragraph in bidi.BidiString.fromLogical(line).paragraphs) {
    codes.addAll(paragraph.bidiText);
  }
  return String.fromCharCodes(codes);
}
