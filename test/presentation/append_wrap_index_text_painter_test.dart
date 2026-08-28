import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_viewport/quiet_viewport.dart';

void main() {
  const style = TextStyle(fontSize: 19, height: 1.65);

  test(
    'bounded Latin layout has the same line boundaries as one paragraph',
    () {
      final source = List.filled(
        120,
        'Generated prose keeps arriving without an authored paragraph break. ',
      ).join();

      _expectSameLayout(source, style: style, width: 613, window: 257);
    },
  );

  test('hard breaks and long words retain every exact source boundary', () {
    final source =
        '''First line with ordinary words.
Second line ${List.filled(900, 'unbroken').join()} finishes here.

The final paragraph has no terminal newline.''';

    _expectSameLayout(source, style: style, width: 401, window: 193);
  });

  test(
    'emoji and mixed-direction prose match the complete text engine layout',
    () {
      final source = List.filled(
        60,
        'Visual MD 📚 keeps Latin, العربية, עברית, and café text together. ',
      ).join();

      _expectSameLayout(source, style: style, width: 527, window: 211);
    },
  );

  test('successive appends revisit a bounded tail and converge exactly', () {
    final chunks = List.generate(
      80,
      (index) => 'Chunk $index extends the same provisional paragraph. ',
    );
    var source = chunks.first;
    final resolver = _TextPainterLineResolver(style: style, width: 433);
    final index = AppendWrapIndex(
      source: source,
      resolve: resolver.call,
      windowCodeUnits: 128,
    );

    for (final chunk in chunks.skip(1)) {
      final base = source.length;
      source = '$source$chunk';
      index.append(baseLength: base, source: source);
      expect(index.lastIndexedCodeUnits, lessThan(chunk.length + 160));
    }

    expect(_starts(index), resolver(source));
  });
}

void _expectSameLayout(
  String source, {
  required TextStyle style,
  required double width,
  required int window,
}) {
  final resolver = _TextPainterLineResolver(style: style, width: width);
  final index = AppendWrapIndex(
    source: source,
    resolve: resolver.call,
    windowCodeUnits: window,
  );

  expect(_starts(index), resolver(source));
  expect(
    [
      for (var line = 0; line < index.length; line++)
        _lineText(index, source, line),
    ].join(),
    source,
  );
  expect(index.largestWindowCodeUnits, lessThan(window + 256));
}

List<int> _starts(AppendWrapIndex index) => [
  for (var line = 0; line < index.length; line++) index.startAt(line),
];

String _lineText(AppendWrapIndex index, String source, int line) {
  final range = index.rangeAt(line);
  return source.substring(range.start, range.end);
}

final class _TextPainterLineResolver {
  final TextStyle style;
  final double width;

  const _TextPainterLineResolver({required this.style, required this.width});

  List<int> call(String text) {
    if (text.isEmpty) return const [0];
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    final starts = <int>[0];
    var offset = 0;
    while (offset < text.length) {
      final range = painter.getLineBoundary(TextPosition(offset: offset));
      var next = range.end;
      if (next < text.length && text.codeUnitAt(next) == 10) next++;
      if (next <= offset) {
        throw StateError('TextPainter did not advance from $offset in $text');
      }
      if (next <= text.length) starts.add(next);
      offset = next;
    }
    if (starts.last == text.length && !text.endsWith('\n')) {
      starts.removeLast();
    }
    painter.dispose();
    return starts;
  }
}
