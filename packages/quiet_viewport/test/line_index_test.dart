import 'package:quiet_viewport/quiet_viewport.dart';
import 'package:test/test.dart';

void main() {
  test('appending visits only new text and preserves existing ranges', () {
    final prefix = List.filled(10000, 'prefix').join('\n');
    final index = AppendLineIndex(prefix);
    final retained = index.rangeAt(5000);

    index.append('\none\ntwo');

    expect(index.lastIndexedCodeUnits, 8);
    expect(index.rangeAt(5000).start, retained.start);
    expect(index.rangeAt(5000).end, retained.end);
    expect(index.length, 10002);
    expect(index.rangeAt(10000).end - index.rangeAt(10000).start, 3);
    expect(index.rangeAt(10001).end - index.rangeAt(10001).start, 3);
  });

  test('an appended suffix can extend the current final line', () {
    final index = AppendLineIndex('short\nlonger');

    index.append('-still-growing');

    expect(index.length, 2);
    expect(index.maximumColumns, 'longer-still-growing'.length);
    expect(index.rangeAt(1).end, index.sourceLength);
  });
}
