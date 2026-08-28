import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/presentation/theme/typographic_punctuation.dart';

void main() {
  test('the projection sets the same keyboard punctuation a reader sees', () {
    final projection = TypographicProjection.of(
      '"Hello," she said -- then paused... "Really?"',
    );

    expect(projection.text, '“Hello,” she said – then paused… “Really?”');
  });

  test('display boundaries recover exact source around contractions', () {
    final projection = TypographicProjection.of('a--b...c');

    expect(projection.text, 'a–b…c');
    expect(
      [
        for (var offset = 0; offset <= projection.text.length; offset++)
          projection.sourceOffsetAt(offset),
      ],
      [0, 1, 3, 4, 7, 8],
    );
  });

  test('surrogate pairs remain whole and do not disturb later offsets', () {
    final projection = TypographicProjection.of('😀... "yes"');

    expect(projection.text, '😀… “yes”');
    expect(projection.sourceOffsetAt(2), 2);
    expect(projection.sourceOffsetAt(projection.text.length), 11);
    expect(projection.previousDisplayAt(2), '😀');
  });

  test('bounded projections inherit quote context from their left edge', () {
    final closing = TypographicProjection.of('"word"', previous: 'x');
    final opening = TypographicProjection.of('"word"', previous: ' ');

    expect(closing.text, '”word”');
    expect(opening.text, '“word”');
    expect(closing.previousDisplayAt(0), 'x');
    expect(opening.previousDisplayAt(opening.text.length), '”');
  });

  test('invalid display boundaries cannot escape the projection', () {
    final projection = TypographicProjection.of('text');

    expect(() => projection.sourceOffsetAt(-1), throwsRangeError);
    expect(() => projection.sourceOffsetAt(5), throwsRangeError);
    expect(() => projection.previousDisplayAt(-1), throwsRangeError);
    expect(() => projection.previousDisplayAt(5), throwsRangeError);
  });
}
