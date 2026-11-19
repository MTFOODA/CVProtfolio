import 'package:flutter_test/flutter_test.dart';

import 'package:cv_portfolio_maker/core/domain/profile_models.dart';

void main() {
  group('DateRange.format', () {
    test('formats a closed range', () {
      const range = DateRange(
        startIso: '2020-01-15T00:00:00.000Z',
        endIso: '2022-06-30T00:00:00.000Z',
      );
      expect(range.format(), 'Jan 2020 - Jun 2022');
    });

    test('formats a current role with no end date', () {
      const range = DateRange(
        startIso: '2022-07-01T00:00:00.000Z',
        isCurrent: true,
      );
      expect(range.format(), 'Jul 2022 - Present');
    });

    test('treats a missing end date as open-ended', () {
      const range = DateRange(startIso: '2022-07-01T00:00:00.000Z');
      expect(range.format(), 'Jul 2022 - Present');
    });

    test('formats an end date when the start is missing', () {
      const range = DateRange(endIso: '2018-06-30T00:00:00.000Z');
      expect(range.format(), 'Jun 2018');
    });

    test('both dates missing yields an empty string', () {
      expect(const DateRange().format(), '');
      expect(const DateRange().isEmpty, isTrue);
    });

    test('free-text dates are preserved rather than dropped', () {
      const range = DateRange(startIso: 'Spring 2020', endIso: 'Summer 2021');
      expect(range.format(), 'Spring 2020 - Summer 2021');
    });

    test('is reachable through a dynamic receiver', () {
      // Regression guard for the reported crash: the formatter used to be an
      // extension method, so this exact call threw
      // "Class 'DateRange' has no instance method 'format'".
      const dynamic range = DateRange(startIso: '2020-01-15');
      expect(range.format(), 'Jan 2020 - Present');
    });
  });
}
