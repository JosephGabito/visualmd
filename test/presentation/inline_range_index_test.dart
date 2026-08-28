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
  });
}
