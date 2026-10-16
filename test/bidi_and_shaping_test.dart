/// Arabic shaping and bidirectional ordering for the PDF exporter.
///
/// The expectations are goldens captured from the `bidi` engine (`pdf`'s own
/// bidi/shaping dependency). They pin the exact code-point sequence written
/// into the PDF, so a regression in either joining or reading order fails.
library;

import 'package:bidi/bidi.dart' as bidi;
import 'package:flutter_test/flutter_test.dart';

import 'package:cv_portfolio_maker/core/export/arabic_text.dart';

/// Builds a string from code points, keeping the goldens readable.
String cp(List<int> codes) => String.fromCharCodes(codes);

// Presentation forms used by the goldens.
const int behIsolated = 0xFE8F;
const int behFinal = 0xFE90;
const int behInitial = 0xFE91;
const int behMedial = 0xFE92;
const int alefFinal = 0xFE8E;
const int lamAlefIsolated = 0xFEFB;
const int lamAlefFinal = 0xFEFC;

/// `'مرحبا بالعالم'` — every letter joined, words in reading order.
const List<int> helloWorld = [
  65250,
  65247,
  65166,
  65228,
  65247,
  65166,
  65169,
  32,
  65166,
  65170,
  65187,
  65198,
  65251,
];

void main() {
  group('Arabic joining', () {
    test('a lone letter is drawn in its isolated form', () {
      expect(prepareForPdf('ب', rtlBase: false), cp([behIsolated]));
    });

    test('two letters join: the first takes the initial form', () {
      expect(prepareForPdf('بب', rtlBase: false), cp([behFinal, behInitial]));
    });

    test('three letters use a medial form in the middle', () {
      expect(
        prepareForPdf('ببب', rtlBase: false),
        cp([behFinal, behMedial, behInitial]),
      );
    });

    test('a right-joining letter never takes an initial form', () {
      // Alef joins only to the preceding letter, so beh stays initial.
      expect(prepareForPdf('با', rtlBase: false), cp([alefFinal, behInitial]));
    });

    test('lam-alef collapses into the mandatory ligature', () {
      expect(prepareForPdf('لا', rtlBase: false), cp([lamAlefIsolated]));
      expect(
        prepareForPdf('بلا', rtlBase: false),
        cp([lamAlefFinal, behInitial]),
      );
    });

    test('every Arabic letter is emitted as a presentation form', () {
      final output = prepareForPdf('مرحبا بالعالم', rtlBase: false);
      for (final code in output.codeUnits) {
        if (code == 0x20) continue;
        expect(
          code >= 0xFB50 && code <= 0xFEFF,
          isTrue,
          reason:
              'expected a presentation form, got '
              'U+${code.toRadixString(16)}',
        );
      }
    });
  });

  group('mixed-script ordering', () {
    test('a pure Arabic sentence reads right to left', () {
      expect(prepareForPdf('مرحبا بالعالم', rtlBase: false), cp(helloWorld));
    });

    test('digits keep their left-to-right order inside Arabic', () {
      // `سنة 1843 م` — the ASCII digits stay as `1843`.
      expect(
        prepareForPdf('سنة 1843 م', rtlBase: false),
        cp([65249, 32, 49, 56, 52, 51, 32, 65172, 65256, 65203]),
      );
    });

    test('an Arabic phrase inside an English line is still reversed', () {
      // Regression: an earlier implementation returned the input unchanged
      // whenever the *document* was left-to-right, which left the Arabic run
      // painted backwards.
      expect(
        prepareForPdf('Name: أحمد', rtlBase: false),
        cp([78, 97, 109, 101, 58, 32, 65194, 65252, 65187, 65155]),
      );
    });

    test('a right-to-left base direction moves the Arabic run first', () {
      expect(
        prepareForPdf('Name: أحمد', rtlBase: true),
        cp([65194, 65252, 65187, 65155, 32, 58, 78, 97, 109, 101]),
      );
    });

    test('brackets are mirrored rather than swapped', () {
      // An earlier implementation reversed every code point of the run, which
      // turned "(...)" into ")(".
      final output = prepareForPdf('أحمد (مهندس)', rtlBase: false);
      expect(output.startsWith('('), isTrue);
      expect(output.endsWith(')'), isFalse);
      expect(output.indexOf('('), lessThan(output.indexOf(')')));
    });

    test('an email address inside Arabic stays intact and readable', () {
      final output = prepareForPdf('البريد: ada@example.com', rtlBase: false);
      expect(output, contains('ada@example.com'));
    });

    test('latin-only text is left untouched', () {
      expect(prepareForPdf('Ada Lovelace', rtlBase: false), 'Ada Lovelace');
      expect(prepareForPdf('Ada Lovelace', rtlBase: true), 'Ada Lovelace');
    });

    test('empty and newline-only input is preserved', () {
      expect(prepareForPdf('', rtlBase: true), '');
      expect(prepareForPdf('\n', rtlBase: true), '\n');
    });

    test('multi-line text keeps its line structure', () {
      final output = prepareForPdf('Ada\nبب', rtlBase: false);
      expect(output.split('\n').length, 2);
      expect(output.split('\n').first, 'Ada');
    });

    test('no direction markers leak into the output', () {
      final output = prepareForPdf('مرحبا', rtlBase: true);
      expect(output.codeUnits, isNot(contains(0x202B)));
      expect(output.codeUnits, isNot(contains(0x202C)));
    });
  });

  group('pdf owns bidi helper', () {
    /// The same call `pdf` makes internally, including its extra step.
    String pdfHelper(String input) {
      final buffer = StringBuffer();
      for (final paragraph in bidi.BidiString.fromLogical(input).paragraphs) {
        final endsWithNewLine = paragraph.separator == 10;
        final endIndex = paragraph.bidiText.length - (endsWithNewLine ? 1 : 0);
        final visual = String.fromCharCodes(paragraph.bidiText, 0, endIndex);
        buffer.write(visual.split(' ').reversed.join(' '));
        if (endsWithNewLine) buffer.writeln();
      }
      return buffer.toString();
    }

    test('is bypassed because it transposes words', () {
      const sample = 'مرحبا بالعالم';
      final mine = prepareForPdf(sample, rtlBase: false);
      final theirs = pdfHelper(sample);

      // The engine output is correct; the library helper reverses the words a
      // second time and therefore differs. This is why `pw.Text` is never given
      // `TextDirection.rtl`.
      expect(theirs, isNot(mine));
      expect(
        theirs.split(' ').reversed.join(' '),
        mine,
        reason: 'the library helper only re-reverses the word order',
      );
    });

    test('also transposes left-to-right word order', () {
      // The helper applies its extra reversal unconditionally, so even plain
      // English comes out with swapped words: `pw.Text` must therefore never be
      // given `TextDirection.rtl`.
      expect(pdfHelper('Ada Lovelace'), 'Lovelace Ada');
      expect(prepareForPdf('Ada Lovelace', rtlBase: false), 'Ada Lovelace');
    });
  });
}
