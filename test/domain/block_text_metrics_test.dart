import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/domain/reading/content/block.dart';
import 'package:visualmd/domain/reading/content/inline.dart';

void main() {
  test(
    'block metrics match visible text without flattening container trees',
    () {
      final blocks = <Block>[
        const ParagraphBlock([
          TextRun('one'),
          LineBreakRun(),
          MarkedRun(InlineMark.strong, [TextRun('two')]),
        ]),
        const HeadingBlock(
          level: 2,
          content: [TextRun('heading')],
          anchor: 'heading',
        ),
        const CodeBlock(code: 'a\nb\n'),
        const QuoteBlock([
          ParagraphBlock([TextRun('quoted')]),
          AnchorBlock('inside'),
          ParagraphBlock([TextRun('again')]),
        ]),
        const ListBlock(
          ordered: false,
          items: [
            ListItem([
              ParagraphBlock([TextRun('first')]),
            ]),
            ListItem([
              ParagraphBlock([TextRun('second')]),
              ParagraphBlock([TextRun('continued')]),
            ]),
          ],
        ),
        const FootnoteSectionBlock([
          FootnoteDefinition(
            number: 1,
            anchor: 'fn-1',
            blocks: [
              ParagraphBlock([TextRun('note')]),
            ],
          ),
        ]),
        const TableBlock(
          head: [
            TableCell([TextRun('a')]),
            TableCell([TextRun('b')]),
          ],
          rows: [
            [
              TableCell([TextRun('c')]),
              TableCell([TextRun('d')]),
            ],
          ],
        ),
        const RawBlock('raw\ntext'),
      ];

      for (final block in blocks) {
        final metrics = BlockTextMetrics.fromBlock(block);
        expect(metrics.codeUnits, block.text.length, reason: '$block');
        expect(metrics.lineBreaks, '\n'.allMatches(block.text).length);
      }
    },
  );

  test('suffix metrics extend only the retained visible facts', () {
    final before = BlockTextMetrics.fromText('one\ntwo');
    final suffix = BlockTextMetrics.fromInlines(const [
      TextRun(' three'),
      LineBreakRun(),
      CodeRun('four'),
    ]);

    final appended = before.append(suffix);

    expect(appended.codeUnits, 'one\ntwo three\nfour'.length);
    expect(appended.lineBreaks, 2);
  });
}
