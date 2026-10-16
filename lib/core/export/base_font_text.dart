/// Text substitutions for the base-14 PostScript fonts.
///
/// `pdf`'s built-in fonts cover Latin-1 only. Characters outside it — including
/// everything in the CP1252 `0x80`–`0x9F` range such as `’ “ ” • … – —` — are
/// drawn as a `.notdef` box: the exported page shows a black rectangle where
/// the character should be, and `pdf` only mentions it on the console. Text
/// pasted from a word processor is full of these characters, and this renderer
/// itself emits `•` for every entry description.
///
/// [transliterateForBaseFonts] maps them to Latin-1/ASCII equivalents so the
/// fallback output stays readable. It is deliberately **not** applied when a
/// TrueType font was embedded: those fonts carry the real characters, and
/// replacing them would be a quality regression.
library;

/// Characters the base-14 fonts cannot draw, mapped to Latin-1/ASCII
/// equivalents.
///
/// Every key is outside Latin-1, which is asserted by the tests: mapping a
/// character the fonts *can* draw would degrade real output for no reason.
const Map<int, String> baseFontReplacements = <int, String>{
  // Quotation marks.
  0x2018: "'", // ‘
  0x2019: "'", // ’
  0x201A: "'", // ‚
  0x201B: "'", // ‛
  0x201C: '"', // “
  0x201D: '"', // ”
  0x201E: '"', // „
  0x201F: '"', // ‟
  0x2032: "'", // ′
  0x2033: '"', // ″
  0x2039: '<', // ‹
  0x203A: '>', // ›
  // Dashes.
  0x2010: '-', // ‐
  0x2011: '-', // ‑
  0x2012: '-', // ‒
  0x2013: '-', // –
  0x2014: '-', // —
  0x2015: '-', // ―
  0x2212: '-', // −
  // Bullets and other list markers.
  0x2022: '-', // •
  0x2023: '-', // ‣
  0x2043: '-', // ⁃
  0x25AA: '-', // ▪
  0x25CF: '-', // ●
  // Pacing and symbols.
  0x2026: '...', // …
  0x2030: '%', // ‰
  0x2044: '/', // ⁄
  0x20AC: 'EUR', // €
  0x2122: '(TM)', // ™
  0x2020: '+', // †
  0x2021: '++', // ‡
  0x02C6: '^', // ˆ
  0x02DC: '~', // ˜
  0x0192: 'f', // ƒ
  // Letters outside Latin-1.
  0x0152: 'OE', // Œ
  0x0153: 'oe', // œ
  0x0160: 'S', // Š
  0x0161: 's', // š
  0x0178: 'Y', // Ÿ
  0x017D: 'Z', // Ž
  0x017E: 'z', // ž
};

/// Replaces characters no base-14 font can draw with ASCII equivalents.
///
/// Characters that are not in [baseFontReplacements] pass through unchanged,
/// so this is safe to apply to any already-prepared text.
String transliterateForBaseFonts(String input) {
  if (input.isEmpty) return input;
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final replacement = baseFontReplacements[rune];
    if (replacement != null) {
      buffer.write(replacement);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// Whether [input] contains characters a base-14 font cannot draw.
///
/// Used by tests to assert that the fallback path is fully covered.
bool needsBaseFontTransliteration(String input) =>
    input.runes.any(baseFontReplacements.containsKey);
