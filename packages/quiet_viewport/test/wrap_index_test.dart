import 'package:quiet_viewport/quiet_viewport.dart';
import 'package:test/test.dart';

void main() {
  test('an append revisits only the unfinished line and its suffix', () {
    const source = 'alpha bravo charlie delta';
    final index = AppendWrapIndex(
      source: 'alpha bravo charlie',
      windowCodeUnits: 8,
      resolve: _fiveColumns,
    );

    index.append(baseLength: 'alpha bravo charlie'.length, source: source);

    expect(_ranges(index, source), [
      'alpha',
      ' brav',
      'o cha',
      'rlie ',
      'delta',
    ]);
    expect(index.lastIndexedCodeUnits, lessThan(source.length));
  });

  test('bounded windows reproduce a complete fixed-width layout', () {
    const source = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final index = AppendWrapIndex(
      source: source,
      windowCodeUnits: 7,
      resolve: _fiveColumns,
    );

    expect(index.length, (source.length / 5).ceil());
    expect(_ranges(index, source).join(), source);
    expect(index.largestWindowCodeUnits, lessThanOrEqualTo(11));
  });

  test('a surrogate pair is never divided between resolver windows', () {
    final seen = <String>[];
    final index = AppendWrapIndex(
      source: 'abcde😀fghij',
      windowCodeUnits: 6,
      resolve: (text) {
        seen.add(text);
        return _fiveColumns(text);
      },
    );

    expect(seen.every(_hasCompleteSurrogates), isTrue);
    expect(_ranges(index, 'abcde😀fghij').join(), 'abcde😀fghij');
  });

  test('an invalid resolver cannot corrupt retained geometry', () {
    expect(
      () => AppendWrapIndex(source: 'text', resolve: (_) => [1]),
      throwsStateError,
    );
    expect(
      () => AppendWrapIndex(source: 'text', resolve: (_) => [0, 3, 2]),
      throwsStateError,
    );
  });

  test('a tail revision retains every declared prefix line', () {
    const initial = 'aaaaabbbbbcccccddddd';
    const revised = 'aaaaabbbbbXXXXXYYYYYZZZZZ';
    final index = AppendWrapIndex(
      source: initial,
      windowCodeUnits: 7,
      resolve: _fiveColumns,
    );
    final retained = [index.startAt(0), index.startAt(1), index.startAt(2)];

    index.replaceTail(line: 2, source: revised);

    expect([index.startAt(0), index.startAt(1), index.startAt(2)], retained);
    expect(_ranges(index, revised).join(), revised);
    expect(index.lastIndexedCodeUnits, lessThan(revised.length));
  });

  test('a rejected tail revision leaves retained geometry unchanged', () {
    final index = AppendWrapIndex(
      source: 'aaaaabbbbbccccc',
      resolve: _fiveColumns,
    );
    final before = [
      for (var line = 0; line < index.length; line++) index.startAt(line),
    ];

    expect(() => index.replaceTail(line: 2, source: 'short'), throwsStateError);
    expect([
      for (var line = 0; line < index.length; line++) index.startAt(line),
    ], before);
  });
}

List<int> _fiveColumns(String text) => [
  for (var offset = 0; offset < text.length; offset += 5) offset,
];

List<String> _ranges(AppendWrapIndex index, String source) => [
  for (var line = 0; line < index.length; line++)
    source.substring(index.rangeAt(line).start, index.rangeAt(line).end),
];

bool _hasCompleteSurrogates(String text) {
  for (var index = 0; index < text.length; index++) {
    final unit = text.codeUnitAt(index);
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      if (index + 1 >= text.length) return false;
      final low = text.codeUnitAt(++index);
      if (low < 0xDC00 || low > 0xDFFF) return false;
    } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
      return false;
    }
  }
  return true;
}
