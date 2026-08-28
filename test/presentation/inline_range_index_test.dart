import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/render/inline_range_index.dart';
import 'package:visualmd/domain/reading/content/inline.dart';

void main() {
  const content = <Inline>[
    TextRun('zero '),
    MarkedRun(InlineMark.strong, [
      TextRun('one '),
      LinkRun(
        href: '/two',
        title: 'Two',
        children: [TextRun('two'), CodeRun('()')],
      ),
      TextRun(' three'),
    ]),
    LineBreakRun(),
    CodeRun('four'),
  ];

  test('the index retains exact visible source without flattening meaning', () {
    final index = InlineRangeIndex(content);

    expect(index.source, 'zero one two() three\nfour');
    expect(index.length, index.source.length);
    expect(InlineRangeIndex.textLength(content), index.source.length);
    expect(InlineRangeIndex.supports(content), isTrue);
    expect(InlineRangeIndex.supportsAtLeast(content, index.length), isTrue);
    expect(
      InlineRangeIndex.supportsAtLeast(content, index.length + 1),
      isFalse,
    );
  });

  test('a bounded slice preserves nested marks and one link container', () {
    final index = InlineRangeIndex(content);
    final sliced = index.slice(7, 17);

    expect(sliced.map((run) => run.text).join(), index.source.substring(7, 17));
    expect(sliced, hasLength(1));
    final strong = sliced.single as MarkedRun;
    expect(strong.mark, InlineMark.strong);
    expect(strong.children, hasLength(3));
    final link = strong.children[1] as LinkRun;
    expect(link.href, '/two');
    expect(link.title, 'Two');
    expect(link.children, [const TextRun('two'), const CodeRun('()')]);
  });

  test('seeking a final range excludes every earlier leaf', () {
    final index = InlineRangeIndex(content);

    expect(index.slice(index.length - 4, index.length), [
      const CodeRun('four'),
    ]);
  });

  test('a proven suffix extends the index without changing earlier ranges', () {
    final index = InlineRangeIndex(content);
    final appended = index.append(const [
      TextRun(' five '),
      MarkedRun(InlineMark.strong, [TextRun('six')]),
    ]);

    expect(appended.source, '${index.source} five six');
    expect(
      appended.slice(0, index.length).map((run) => run.text).join(),
      index.source,
    );
    expect(
      appended.slice(7, 17).map((run) => run.text).join(),
      index.slice(7, 17).map((run) => run.text).join(),
    );
    final suffix = appended.slice(index.length, appended.length);
    expect(suffix.first, const TextRun(' five '));
    final marked = suffix.last as MarkedRun;
    expect(marked.mark, InlineMark.strong);
    expect(marked.children, const [TextRun('six')]);
  });

  test('an unsupported suffix cannot enter a range-safe index', () {
    final index = InlineRangeIndex(content);

    expect(() => index.append(const [MathRun('x')]), throwsArgumentError);
  });

  test('a proven tail replacement retains every earlier inline range', () {
    final index = InlineRangeIndex(content);
    const prefix = 'zero ';
    final replaced = index.replaceTail(
      prefixLength: prefix.length,
      runs: const [
        TextRun('changed '),
        MarkedRun(InlineMark.emphasis, [TextRun('tail')]),
      ],
    );

    expect(replaced.source, 'zero changed tail');
    expect(replaced.slice(0, prefix.length), const [TextRun(prefix)]);
    final tail = replaced.slice(prefix.length, replaced.length);
    expect(tail.first, const TextRun('changed '));
    final marked = tail.last as MarkedRun;
    expect(marked.mark, InlineMark.emphasis);
    expect(marked.children, const [TextRun('tail')]);
  });

  test('a tail replacement cannot split a retained inline leaf', () {
    final index = InlineRangeIndex(content);

    expect(
      () => index.replaceTail(
        prefixLength: 2,
        runs: const [TextRun('replacement')],
      ),
      throwsStateError,
    );
  });

  test('progressive indexing publishes only one complete immutable result', () {
    final builder = ProgressiveInlineRangeIndex.fromSupported(content);

    expect(builder.isComplete, isFalse);
    expect(() => builder.result, throwsStateError);
    while (!builder.indexNext(maxNodes: 2)) {
      expect(builder.lastIndexedNodes, lessThanOrEqualTo(2));
      expect(() => builder.result, throwsStateError);
    }

    expect(builder.result.source, 'zero one two() three\nfour');
    expect(
      builder.result.slice(7, 17).map((run) => run.text).join(),
      'e two() th',
    );
    expect(builder.indexNext(maxNodes: 2), isTrue);
    expect(builder.lastIndexedNodes, 0);
  });

  test('widow binding follows the eager paragraph ending rule', () {
    final marked = InlineRangeIndex(const [
      TextRun('one two three '),
      MarkedRun(InlineMark.emphasis, [TextRun('four five')]),
    ]);
    final linked = InlineRangeIndex(const [
      TextRun('one two three '),
      LinkRun(href: '/five', children: [TextRun('four five')]),
    ]);

    expect(marked.widowOffset, marked.source.lastIndexOf(' '));
    expect(linked.widowOffset, isNull);
    expect(InlineRangeIndex(content).widowOffset, isNull);
  });

  test('widget and control runs stay on their deliberate eager path', () {
    expect(InlineRangeIndex.supports(const [MathRun('x')]), isFalse);
    expect(InlineRangeIndex.supportsAtLeast(const [MathRun('x')], 0), isFalse);
    expect(
      InlineRangeIndex.supports(const [
        ImageRun(source: 'image.png', alt: 'image'),
      ]),
      isFalse,
    );
    expect(() => InlineRangeIndex(const [MathRun('x')]), throwsArgumentError);
  });

  test('range validation cannot escape the visible source', () {
    final index = InlineRangeIndex(content);

    expect(() => index.slice(-1, 1), throwsRangeError);
    expect(() => index.slice(0, index.length + 1), throwsRangeError);
    expect(() => index.slice(3, 2), throwsRangeError);
    expect(
      () => InlineRangeIndex.supportsAtLeast(content, -1),
      throwsRangeError,
    );
    expect(
      () =>
          ProgressiveInlineRangeIndex.fromSupported(content)
              .indexNext(maxNodes: 0),
      throwsRangeError,
    );
  });
}
