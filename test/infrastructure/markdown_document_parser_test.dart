import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/domain/reading/content/block.dart';
import 'package:visualmd/domain/reading/content/document_content.dart';
import 'package:visualmd/domain/reading/content/inline.dart';
import 'package:visualmd/domain/reading/heading_anchor.dart';
import 'package:visualmd/infrastructure/markdown/markdown_document_parser.dart';

DocumentContent parse(String markdown) =>
    const MarkdownDocumentParser().parse(markdown);

/// The single block of a one-block document, as the type it should be.
T single<T extends Block>(String markdown) {
  final blocks = parse(markdown).blocks;
  expect(
    blocks,
    hasLength(1),
    reason: 'expected one block, got ${blocks.map((b) => b.runtimeType)}',
  );
  return blocks.single as T;
}

void main() {
  group('a paragraph', () {
    test('carries its marks as runs, in order', () {
      final paragraph = single<ParagraphBlock>(
        'A *little* **bold** and ~~gone~~.',
      );
      final marks = paragraph.content.whereType<MarkedRun>().map((r) => r.mark);
      expect(marks, [
        InlineMark.emphasis,
        InlineMark.strong,
        InlineMark.strikethrough,
      ]);
      expect(paragraph.text, 'A little bold and gone.');
    });

    test('nests one mark inside another', () {
      final paragraph = single<ParagraphBlock>('**bold with *italic* inside**');
      final strong = paragraph.content.single as MarkedRun;
      expect(strong.mark, InlineMark.strong);
      expect(
        strong.children.whereType<MarkedRun>().single.mark,
        InlineMark.emphasis,
      );
      expect(strong.text, 'bold with italic inside');
    });

    test('leaves the author\'s punctuation exactly as typed', () {
      // Setting quotes and dashes is a presentation decision made later; the
      // domain keeps what was written.
      final paragraph = single<ParagraphBlock>('He said "no" -- twice...');
      expect(paragraph.text, 'He said "no" -- twice...');
    });

    test('treats a single newline as a space, not a break', () {
      final paragraph = single<ParagraphBlock>(
        'one line\nand its continuation',
      );
      expect(paragraph.content.whereType<LineBreakRun>(), isEmpty);
      expect(paragraph.text, 'one line and its continuation');
    });

    test('keeps a break the author asked for with two spaces', () {
      final paragraph = single<ParagraphBlock>('one line  \nand a new one');
      expect(paragraph.content.whereType<LineBreakRun>(), hasLength(1));
    });
  });

  group('inline code', () {
    test(
      'keeps every character, including what markdown would otherwise eat',
      () {
        final paragraph = single<ParagraphBlock>(
          'Run `git log --oneline "HEAD"` now.',
        );
        final code = paragraph.content.whereType<CodeRun>().single;
        expect(code.text, 'git log --oneline "HEAD"');
      },
    );

    test('a longer delimiter carries literal backticks', () {
      final paragraph = single<ParagraphBlock>(
        'Use ``one `backtick` here`` safely.',
      );
      expect(
        paragraph.content.whereType<CodeRun>().single.text,
        'one `backtick` here',
      );
    });

    test('one ordinary space is stripped from both edges', () {
      final paragraph = single<ParagraphBlock>('Read ``  padded code  ``.');
      expect(
        paragraph.content.whereType<CodeRun>().single.text,
        ' padded code ',
      );
    });

    test('line endings become spaces while literal syntax stays literal', () {
      final paragraph = single<ParagraphBlock>(
        'Read ``first\n\\* &copy; second``.',
      );
      expect(
        paragraph.content.whereType<CodeRun>().single.text,
        r'first \* &copy; second',
      );
    });
  });

  group('a heading', () {
    test('takes its level from the source and its anchor from its words', () {
      final heading = single<HeadingBlock>('### The *shelf*');
      expect(heading.level, 3);
      expect(heading.text, 'The shelf');
      expect(heading.anchor, HeadingAnchors.slug('The shelf'));
    });

    test('numbers repeats so every anchor in a document is reachable', () {
      final headings = parse('# Setup\n\n# Setup\n\n# Setup\n').blocks
          .cast<HeadingBlock>();
      expect(headings.map((h) => h.anchor), ['setup', 'setup-1', 'setup-2']);
    });

    test(
      'anchors are counted per document, not across the reader\'s session',
      () {
        expect(
          parse('# Setup').blocks.cast<HeadingBlock>().single.anchor,
          'setup',
        );
        expect(
          parse('# Setup').blocks.cast<HeadingBlock>().single.anchor,
          'setup',
        );
      },
    );
  });

  group('a code block', () {
    test('remembers the language the author named', () {
      final code = single<CodeBlock>('```dart\nfinal x = 1;\n```');
      expect(code.language, 'dart');
      expect(code.code, 'final x = 1;');
    });

    test('a tilde fence carries the same language contract', () {
      final code = single<CodeBlock>('~~~python\nprint("hello")\n~~~');
      expect(code.language, 'python');
      expect(code.code, 'print("hello")');
    });

    test('only the first word of an info string names the language', () {
      final code = single<CodeBlock>(
        '```dart title="record.dart" linenos=true\nfinal x = 1;\n```',
      );
      expect(code.language, 'dart');
      expect(code.code, 'final x = 1;');
    });

    test('has no language when the fence names none', () {
      expect(single<CodeBlock>('```\nplain\n```').language, isNull);
    });

    test('keeps its own blank lines but not the fence\'s closing newline', () {
      final code = single<CodeBlock>('```\nfirst\n\nlast\n```');
      expect(code.code, 'first\n\nlast');
    });

    test('keeps tabs, trailing spaces, and shorter inner fences verbatim', () {
      final code = single<CodeBlock>(
        '````markdown\nalpha\tbeta  \n```dart\nvalue\n```\n````',
      );
      expect(code.language, 'markdown');
      expect(code.code, 'alpha\tbeta  \n```dart\nvalue\n```');
    });

    test('an unclosed fence safely owns the rest of the document', () {
      final code = single<CodeBlock>('```php\n<?php echo "still visible";');
      expect(code.language, 'php');
      expect(code.code, '<?php echo "still visible";');
    });

    test('an indented block is code too', () {
      final code = single<CodeBlock>('    echo "hi" --now');
      expect(code.language, isNull);
      expect(code.code, 'echo "hi" --now');
    });
  });

  group('a quotation', () {
    test('holds blocks of its own, including a list', () {
      final quote = single<QuoteBlock>('> First.\n>\n> - one\n> - two\n');
      expect(quote.blocks.first, isA<ParagraphBlock>());
      final list = quote.blocks.last as ListBlock;
      expect(list.items.map((i) => i.text.trim()), ['one', 'two']);
    });
  });

  group('a list', () {
    test('is tight when the author left no blank lines between items', () {
      final list = single<ListBlock>('- one\n- two\n');
      expect(list.ordered, isFalse);
      expect(list.loose, isFalse);
      expect(list.items, hasLength(2));
      expect(list.items.first.blocks.single, isA<ParagraphBlock>());
    });

    test('is loose when the author asked for air between items', () {
      final list = single<ListBlock>('- one\n\n- two\n');
      expect(list.loose, isTrue);
      expect(list.items.map((i) => i.text.trim()), ['one', 'two']);
    });

    test('starts where the author started it', () {
      final list = single<ListBlock>('5. five\n6. six\n');
      expect(list.ordered, isTrue);
      expect(list.start, 5);
    });

    test('starts at one when the author did not say otherwise', () {
      expect(single<ListBlock>('1. one\n2. two\n').start, 1);
    });

    test('carries the state of a task, and not its checkbox', () {
      final list = single<ListBlock>('- [x] done\n- [ ] still to do\n');
      expect(list.items.map((i) => i.checked), [true, false]);
      expect(list.items.map((i) => i.text.trim()), ['done', 'still to do']);
    });

    test('an ordinary item is not a task', () {
      expect(single<ListBlock>('- ordinary\n').items.single.checked, isNull);
    });

    test('an item may hold blocks of its own', () {
      final list = parse('- first paragraph\n\n  ```\n  code\n  ```\n').blocks
          .whereType<ListBlock>()
          .single;
      final item = list.items.single;
      expect(item.blocks.whereType<ParagraphBlock>(), isNotEmpty);
      expect(item.blocks.whereType<CodeBlock>().single.code, 'code');
    });
  });

  group('a table', () {
    test(
      'separates the head from the body and keeps each column\'s alignment',
      () {
        final table = single<TableBlock>(
          '| a | b | c |\n|:--|:-:|--:|\n| 1 | 2 | 3 |\n',
        );
        expect(table.head.map((c) => c.text), ['a', 'b', 'c']);
        expect(table.head.map((c) => c.alignment), [
          ColumnAlignment.start,
          ColumnAlignment.center,
          ColumnAlignment.end,
        ]);
        expect(table.rows.single.map((c) => c.text), ['1', '2', '3']);
        expect(table.rows.single.map((c) => c.alignment), [
          ColumnAlignment.start,
          ColumnAlignment.center,
          ColumnAlignment.end,
        ]);
      },
    );

    test('a short row still has a cell for every column', () {
      final table = single<TableBlock>('| a | b |\n|---|---|\n| 1 |\n');
      expect(table.rows.single, hasLength(2));
      expect(table.rows.single.last.text, isEmpty);
    });

    test('cells carry marks like any other text', () {
      final table = single<TableBlock>('| a |\n|---|\n| `code` |\n');
      expect(table.rows.single.single.content.single, isA<CodeRun>());
    });
  });

  group('the smaller shapes', () {
    test('a rule is a rule', () {
      expect(single<RuleBlock>('***\n'), isA<RuleBlock>());
    });

    test('a link keeps where it points and what it was called', () {
      final paragraph = single<ParagraphBlock>(
        'See [the docs](https://x.test "Docs") now.',
      );
      final link = paragraph.content.whereType<LinkRun>().single;
      expect(link.href, 'https://x.test');
      expect(link.title, 'Docs');
      expect(link.text, 'the docs');
    });

    test('an image keeps its source and its words', () {
      final paragraph = single<ParagraphBlock>(
        '![a diagram](diagram.png "Figure 1")',
      );
      final image = paragraph.content.whereType<ImageRun>().single;
      expect(image.source, 'diagram.png');
      expect(image.alt, 'a diagram');
      expect(image.title, 'Figure 1');
    });
  });

  group('the document as a whole', () {
    test('front matter belongs to the file, not to the page', () {
      final content = parse(
        '---\ntitle: Colophon\ntags: [a]\n---\n\n# Body\n\nText.\n',
      );
      expect(content.blocks.first, isA<HeadingBlock>());
      expect(content.text, isNot(contains('tags')));
    });

    test('front matter closed with dots is still front matter', () {
      final content = parse('---\ntitle: X\n...\n\n# Body\n');
      expect(content.headings.single.text, 'Body');
    });

    test('an empty document has nothing in it', () {
      expect(parse('').isEmpty, isTrue);
      expect(parse('   \n\n  \n').isEmpty, isTrue);
    });

    test('headings come back in the order they were written', () {
      final content = parse('# One\n\ntext\n\n## Two\n\n### Three\n');
      expect(content.headings.map((h) => h.text), ['One', 'Two', 'Three']);
    });

    test('the text of a document is its words, without decoration', () {
      final content = parse('# Title\n\nA **bold** word.\n');
      expect(content.text, 'Title\n\nA bold word.');
    });

    test('blocks arrive in source order', () {
      final blocks = parse('# H\n\npara\n\n```\ncode\n```\n\n> quote\n').blocks;
      expect(blocks.map((b) => b.runtimeType.toString()), [
        'HeadingBlock',
        'ParagraphBlock',
        'CodeBlock',
        'QuoteBlock',
      ]);
    });
  });
}
