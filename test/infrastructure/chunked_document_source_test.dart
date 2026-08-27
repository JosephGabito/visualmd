import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/infrastructure/streaming/chunked_document_source.dart';

void main() {
  test('appending preserves exact chunks without rebuilding the prefix', () {
    final source = ChunkedDocumentSource();

    source
      ..append('# Heading\n\n')
      ..append('A split ')
      ..append('paragraph.\n')
      ..append('');

    expect(source.chunkCount, 3);
    expect(source.length, 30);
    expect(source.materialize(), '# Heading\n\nA split paragraph.\n');
  });

  test(
    'a parser window can cross chunks without materializing the document',
    () {
      final source = ChunkedDocumentSource();
      for (var index = 0; index < 10_000; index++) {
        source.append('old-$index\n');
      }
      final tailStart = source.length;
      source
        ..append('provisional ')
        ..append('tail');

      expect(source.tailFrom(tailStart), 'provisional tail');
      expect(source.range(tailStart + 4, source.length - 2), 'isional ta');
    },
  );

  test('ranges use Dart string offsets even when chunks contain Unicode', () {
    final source = ChunkedDocumentSource()
      ..append('A😀')
      ..append(' café');

    expect(source.length, 'A😀 café'.length);
    expect(source.range(1, 3), '😀');
    expect(source.range(3), ' café');
  });

  test('invalid ranges fail before reading source', () {
    final source = ChunkedDocumentSource()..append('abc');

    expect(() => source.range(-1), throwsRangeError);
    expect(() => source.range(2, 1), throwsRangeError);
    expect(() => source.range(0, 4), throwsRangeError);
  });
}
