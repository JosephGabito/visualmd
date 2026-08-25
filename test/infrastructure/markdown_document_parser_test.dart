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
  });

  group('emphasis delimiters', () {
    test('asterisks and underscores become the same domain mark', () {
      final paragraph = single<ParagraphBlock>(
        'Read *asterisk emphasis* beside _underscore emphasis_.',
      );
      final emphasis = paragraph.content.whereType<MarkedRun>().toList();

      expect(emphasis.map((run) => run.mark), [
        InlineMark.emphasis,
        InlineMark.emphasis,
      ]);
      expect(emphasis.map((run) => run.text), [
        'asterisk emphasis',
        'underscore emphasis',
      ]);
      expect(
        paragraph.text,
        'Read asterisk emphasis beside underscore emphasis.',
      );
    });

    test('asterisks may work inside words while underscores do not', () {
      final paragraph = single<ParagraphBlock>(
        'foo*bar* and 5*6*78; foo_bar_ and 5_6_78 stay literal.',
      );
      final emphasis = paragraph.content.whereType<MarkedRun>().toList();

      expect(emphasis.map((run) => run.text), ['bar', '6']);
      expect(paragraph.text, contains('foo_bar_ and 5_6_78'));
    });

    test('punctuation may flank emphasis but interior edge spaces may not', () {
      final valid = single<ParagraphBlock>('foo-_(bar)_ and _(baz)_.');
      final invalid = single<ParagraphBlock>(
        r'Before * leading* and *trailing * and _ leading_ and _trailing _',
      );

      expect(valid.content.whereType<MarkedRun>().map((run) => run.text), [
        '(bar)',
        '(baz)',
      ]);
      expect(invalid.content.whereType<MarkedRun>(), isEmpty);
      expect(
        invalid.text,
        r'Before * leading* and *trailing * and _ leading_ and _trailing _',
      );
    });

    test('mismatched and unmatched delimiters remain authored text', () {
      for (final source in [
        r'_asterisk*',
        r'*underscore_',
        r'an unmatched *delimiter',
      ]) {
        final paragraph = single<ParagraphBlock>(source);
        expect(paragraph.content.whereType<MarkedRun>(), isEmpty);
        expect(paragraph.text, source);
      }
    });
  });

  group('strong emphasis delimiters', () {
    test('double asterisks and underscores become the same domain mark', () {
      final paragraph = single<ParagraphBlock>(
        'Read **asterisk strength** beside __underscore strength__.',
      );
      final strength = paragraph.content.whereType<MarkedRun>().toList();

      expect(strength.map((run) => run.mark), [
        InlineMark.strong,
        InlineMark.strong,
      ]);
      expect(strength.map((run) => run.text), [
        'asterisk strength',
        'underscore strength',
      ]);
      expect(
        paragraph.text,
        'Read asterisk strength beside underscore strength.',
      );
    });

    test('double asterisks may work inside words while underscores do not', () {
      final paragraph = single<ParagraphBlock>(
        'foo**bar** and 5**6**78; foo__bar__ and 5__6__78 stay literal.',
      );
      final strength = paragraph.content.whereType<MarkedRun>().toList();

      expect(strength.map((run) => run.text), ['bar', '6']);
      expect(paragraph.text, contains('foo__bar__ and 5__6__78'));
    });

    test('punctuation may flank strength but interior edge spaces may not', () {
      final valid = single<ParagraphBlock>('foo-__(bar)__ and __(baz)__.');
      final invalid = single<ParagraphBlock>(
        r'Before ** leading** and **trailing ** and __ leading__ and __trailing __',
      );

      expect(valid.content.whereType<MarkedRun>().map((run) => run.text), [
        '(bar)',
        '(baz)',
      ]);
      expect(invalid.content.whereType<MarkedRun>(), isEmpty);
      expect(
        invalid.text,
        r'Before ** leading** and **trailing ** and __ leading__ and __trailing __',
      );
    });

    test('mismatched and unmatched pairs remain authored text', () {
      for (final source in [
        r'__asterisk**',
        r'**underscore__',
        r'an unmatched **delimiter',
      ]) {
        final paragraph = single<ParagraphBlock>(source);
        expect(paragraph.content.whereType<MarkedRun>(), isEmpty);
        expect(paragraph.text, source);
      }
    });
  });

  group('combined and nested emphasis', () {
    test('triple delimiters prefer emphasis around strength', () {
      for (final source in ['***important***', '___important___']) {
        final paragraph = single<ParagraphBlock>(source);
        final emphasis = paragraph.content.single as MarkedRun;
        final strength = emphasis.children.single as MarkedRun;

        expect(emphasis.mark, InlineMark.emphasis, reason: source);
        expect(strength.mark, InlineMark.strong, reason: source);
        expect(strength.children, [const TextRun('important')]);
        expect(paragraph.text, 'important');
      }
    });

    test('each role may contain the other without exposing its notation', () {
      final emphasisOutside =
          single<ParagraphBlock>('*voice with **important words** inside*')
                  .content
                  .single
              as MarkedRun;
      final strengthOutside =
          single<ParagraphBlock>('**important words with *voice* inside**')
                  .content
                  .single
              as MarkedRun;

      expect(emphasisOutside.mark, InlineMark.emphasis);
      expect(
        emphasisOutside.children.whereType<MarkedRun>().single.mark,
        InlineMark.strong,
      );
      expect(emphasisOutside.text, 'voice with important words inside');
      expect(strengthOutside.mark, InlineMark.strong);
      expect(
        strengthOutside.children.whereType<MarkedRun>().single.mark,
        InlineMark.emphasis,
      );
      expect(strengthOutside.text, 'important words with voice inside');
    });

    test('nesting remains recursive rather than flattening the mark stack', () {
      final outer =
          single<ParagraphBlock>('*outer **middle *inner* middle** outer*')
                  .content
                  .single
              as MarkedRun;
      final middle = outer.children.whereType<MarkedRun>().single;
      final inner = middle.children.whereType<MarkedRun>().single;

      expect(
        [outer.mark, middle.mark, inner.mark],
        [InlineMark.emphasis, InlineMark.strong, InlineMark.emphasis],
      );
      expect(outer.text, 'outer middle inner middle outer');
    });

    test('the rule of three preserves delimiters that are reading text', () {
      final paragraph = single<ParagraphBlock>('*foo**bar*');
      final emphasis = paragraph.content.single as MarkedRun;

      expect(emphasis.mark, InlineMark.emphasis);
      expect(emphasis.children, [const TextRun('foo**bar')]);
      expect(paragraph.text, 'foo**bar');
    });

    test('overlap and shared-closer precedence keep only unmatched marks', () {
      final overlap = single<ParagraphBlock>('*foo _bar* baz_');
      final sharedCloser = single<ParagraphBlock>('**foo **bar baz**');

      expect(overlap.content.first, isA<MarkedRun>());
      expect((overlap.content.first as MarkedRun).text, 'foo _bar');
      expect(overlap.text, 'foo _bar baz_');
      expect(sharedCloser.content.first, const TextRun('**foo '));
      expect((sharedCloser.content.last as MarkedRun).text, 'bar baz');
      expect(sharedCloser.text, '**foo bar baz');
    });

    test('code and links remain nested inside the combined mark', () {
      final paragraph = single<ParagraphBlock>(
        '***read `*` and [the guide](https://example.com)***',
      );
      final emphasis = paragraph.content.single as MarkedRun;
      final strength = emphasis.children.single as MarkedRun;

      expect(strength.children.whereType<CodeRun>().single.text, '*');
      expect(strength.children.whereType<LinkRun>().single.text, 'the guide');
      expect(paragraph.text, 'read * and the guide');
    });
  });

  group('GFM strikethrough delimiters', () {
    test('one and two tildes become the same domain mark', () {
      final paragraph = single<ParagraphBlock>(
        'Read ~one tilde~ beside ~~two tildes~~.',
      );
      final deleted = paragraph.content.whereType<MarkedRun>().toList();

      expect(deleted.map((run) => run.mark), [
        InlineMark.strikethrough,
        InlineMark.strikethrough,
      ]);
      expect(deleted.map((run) => run.text), ['one tilde', 'two tildes']);
      expect(paragraph.text, 'Read one tilde beside two tildes.');
    });

    test('a shorter eligible run leaves the unmatched tilde authored', () {
      final paragraph = single<ParagraphBlock>('~corrected~~ text');
      final deleted = paragraph.content.whereType<MarkedRun>().single;

      expect(deleted.mark, InlineMark.strikethrough);
      expect(deleted.text, 'corrected');
      expect(paragraph.text, 'corrected~ text');
    });

    test('strikethrough may occur inside words and beside punctuation', () {
      final paragraph = single<ParagraphBlock>(
        'before~obsolete~after and (~aside~).',
      );

      expect(paragraph.content.whereType<MarkedRun>().map((run) => run.text), [
        'obsolete',
        'aside',
      ]);
      expect(paragraph.text, 'beforeobsoleteafter and (aside).');
    });

    test('interior whitespace and runs of three or more remain literal', () {
      for (final source in [
        '~ leading~',
        '~trailing ~',
        'This will ~~~not~~~ strike.',
        'This will ~~~~also not~~~~ strike.',
      ]) {
        final paragraph = single<ParagraphBlock>(source);

        expect(
          paragraph.content.whereType<MarkedRun>(),
          isEmpty,
          reason: source,
        );
        expect(paragraph.text, source, reason: source);
      }
    });

    test('a blank line prevents a strikethrough pair', () {
      final content = parse('This ~~has a\n\nnew paragraph~~.');

      expect(content.blocks, hasLength(2));
      expect(content.blocks.whereType<ParagraphBlock>(), hasLength(2));
      expect(content.blocks.map((block) => block.text), [
        'This ~~has a',
        'new paragraph~~.',
      ]);
    });

    test('nested inline roles bind inside the deletion mark', () {
      final paragraph = single<ParagraphBlock>(
        '~~old **important** `literal ~` and [guide](https://example.com)~~',
      );
      final deleted = paragraph.content.single as MarkedRun;

      expect(deleted.mark, InlineMark.strikethrough);
      expect(
        deleted.children.whereType<MarkedRun>().single.mark,
        InlineMark.strong,
      );
      expect(deleted.children.whereType<CodeRun>().single.text, 'literal ~');
      expect(deleted.children.whereType<LinkRun>().single.text, 'guide');
      expect(paragraph.text, 'old important literal ~ and guide');
    });
  });

  group('inline links', () {
    test('the title is optional domain data', () {
      final paragraph = single<ParagraphBlock>(
        'Read [untitled](/guide) beside [titled](/reference "Details").',
      );
      final links = paragraph.content.whereType<LinkRun>().toList();

      expect(links.map((link) => link.text), ['untitled', 'titled']);
      expect(links.map((link) => link.href), ['/guide', '/reference']);
      expect(links.map((link) => link.title), [null, 'Details']);
      expect(paragraph.text, 'Read untitled beside titled.');
    });

    test('all three title delimiters resolve to the same value', () {
      final paragraph = single<ParagraphBlock>(
        '[double](/a "Title") [single](/b \'Title\') '
        '[parentheses](/c (Title))',
      );
      final links = paragraph.content.whereType<LinkRun>().toList();

      expect(links.map((link) => link.title), ['Title', 'Title', 'Title']);
    });

    test('escapes and character references resolve inside href and title', () {
      final link =
          single<ParagraphBlock>(
                r'[guide](/a\(b\)?q=&copy; "A \"title\" &copy;")',
              ).content.single
              as LinkRun;

      expect(link.href, '/a(b)?q=%C2%A9');
      expect(link.title, 'A "title" ©');
      expect(link.text, 'guide');
    });

    test('components may span one source line but not a blank line', () {
      final valid = single<ParagraphBlock>('[guide](/manual\n"Manual title")');
      final link = valid.content.whereType<LinkRun>().single;
      final invalid = parse('[guide](/manual\n\n"Not a title")');

      expect(link.href, '/manual');
      expect(link.title, 'Manual title');
      expect(invalid.text, '[guide](/manual\n\n"Not a title")');
      expect(
        invalid.blocks
            .whereType<ParagraphBlock>()
            .expand((block) => block.content)
            .whereType<LinkRun>(),
        isEmpty,
      );
    });

    test('nested inline roles remain inside the visible link text', () {
      final link =
          single<ParagraphBlock>(
                '[read **important** *voice* and `code`](/guide)',
              ).content.single
              as LinkRun;

      expect(link.text, 'read important voice and code');
      expect(link.children.whereType<MarkedRun>(), hasLength(2));
      expect(link.children.whereType<CodeRun>().single.text, 'code');
    });

    test('a link cannot contain another link, so the inner link wins', () {
      final paragraph = single<ParagraphBlock>(
        '[outer [inner](/inner)](/outer)',
      );
      final links = paragraph.content.whereType<LinkRun>().toList();

      expect(links, hasLength(1));
      expect(links.single.href, '/inner');
      expect(links.single.text, 'inner');
      expect(paragraph.text, '[outer inner](/outer)');
    });

    test('long destinations preserve balanced structure and URL data', () {
      final repeated = List.filled(40, 'segment-').join();
      final destination =
          'https://example.com/one/two/three/'
          '${repeated}resource(foo(and(bar)))'
          '?workspace=visual-md&mode=reader%20view#deep-link';
      final link =
          single<ParagraphBlock>('[reachable]($destination)').content.single
              as LinkRun;

      expect(link.href, destination);
      expect(link.text, 'reachable');
    });

    test('an empty label is valid but contributes no reading text', () {
      final paragraph = single<ParagraphBlock>(
        'before [](/invisible-target "Advisory") after',
      );
      final link = paragraph.content.whereType<LinkRun>().single;

      expect(link.children, isEmpty);
      expect(link.text, isEmpty);
      expect(link.href, '/invisible-target');
      expect(link.title, 'Advisory');
      expect(paragraph.text, 'before  after');
    });

    test('a title keeps resolved punctuation exactly', () {
      final link =
          single<ParagraphBlock>(
                '[guide](/guide "A \'quote\', (detail), '
                'colon: semicolon; — &copy;")',
              ).content.single
              as LinkRun;

      expect(link.title, "A 'quote', (detail), colon: semicolon; — ©");
    });
  });

  group('reference links', () {
    test('full collapsed and shortcut forms become the same domain link', () {
      final blocks = parse('''
[before definition][guide]

[guide]: /manual "Manual title"

[full][guide], [guide][], and [guide].
''').blocks.whereType<ParagraphBlock>().toList();
      final links = blocks
          .expand((block) => block.content)
          .whereType<LinkRun>()
          .toList();

      expect(links.map((link) => link.text), [
        'before definition',
        'full',
        'guide',
        'guide',
      ]);
      expect(links.map((link) => link.href), everyElement('/manual'));
      expect(links.map((link) => link.title), everyElement('Manual title'));
      expect(parse('[guide]: /manual').blocks, isEmpty);
    });

    test('labels match by folded case and collapsed whitespace', () {
      final paragraph = single<ParagraphBlock>('''
[read **important** *voice* and `code`][  ẞ
 GUIDE ]

[SS Guide]: /unicode
''');
      final link = paragraph.content.whereType<LinkRun>().single;

      expect(link.href, '/unicode');
      expect(link.text, 'read important voice and code');
      expect(link.children.whereType<MarkedRun>(), hasLength(2));
      expect(link.children.whereType<CodeRun>().single.text, 'code');
    });

    test('the first duplicate definition remains authoritative', () {
      final link =
          single<ParagraphBlock>('''
[guide]

[guide]: /first "First"
[GUIDE]: /second "Second"
''').content.single
              as LinkRun;

      expect(link.href, '/first');
      expect(link.title, 'First');
    });

    test('a destination and title may continue on following source lines', () {
      final paragraph =
          parse('''
[destination] and [title]

[destination]:
  <https://example.com/a path?q=&copy;>
[title]: /manual
  "A title
  over two lines"
''').blocks.single
              as ParagraphBlock;
      final links = paragraph.content.whereType<LinkRun>().toList();

      expect(links.map((link) => link.href), [
        'https://example.com/a%20path?q=%C2%A9',
        '/manual',
      ]);
      expect(links.map((link) => link.title), [
        null,
        'A title\n  over two lines',
      ]);
    });

    test('unresolved forms stay literal and precedence stays local', () {
      final paragraph = single<ParagraphBlock>('''
[missing][unknown], [missing][], [missing], and [guide][unknown][guide].

[guide]: /resolved
''');
      final links = paragraph.content.whereType<LinkRun>().toList();

      expect(links, hasLength(1));
      expect(links.single.text, 'unknown');
      expect(links.single.href, '/resolved');
      expect(
        paragraph.text,
        '[missing][unknown], [missing][], [missing], and '
        '[guide]unknown.',
      );
    });

    test('a reference label may contain 999 characters but not 1000', () {
      final maximum = List.filled(999, 'a').join();
      final overlong = '${maximum}a';
      final blocks = parse('''
[valid][$maximum] and [literal][$overlong]

[$maximum]: /maximum
[$overlong]: /overlong
''').blocks;
      final paragraph = blocks.first as ParagraphBlock;

      expect(paragraph.content.whereType<LinkRun>().single.href, '/maximum');
      expect(paragraph.text, contains('[literal][$overlong]'));
      expect(blocks.last.text, contains('[$overlong]: /overlong'));
    });
  });

  group('autolinks', () {
    test('angle-bracket URI and email forms become ordinary domain links', () {
      final paragraph = single<ParagraphBlock>(
        '<https://example.com/a?workspace=visual-md> and '
        '<reader+notes@example.com>',
      );
      final links = paragraph.content.whereType<LinkRun>().toList();

      expect(links.map((link) => link.text), [
        'https://example.com/a?workspace=visual-md',
        'reader+notes@example.com',
      ]);
      expect(links.map((link) => link.href), [
        'https://example.com/a?workspace=visual-md',
        'mailto:reader+notes@example.com',
      ]);
      expect(links.map((link) => link.title), everyElement(isNull));
      expect(
        paragraph.text,
        'https://example.com/a?workspace=visual-md and '
        'reader+notes@example.com',
      );
    });

    test('invalid angle-bracket candidates remain authored text', () {
      final paragraph = single<ParagraphBlock>(
        '<> <m:one-character-scheme> <example.com> '
        '<https://example.com/a path> <reader@example.com->',
      );

      expect(paragraph.content.whereType<LinkRun>(), isEmpty);
      expect(
        paragraph.text,
        '<> <m:one-character-scheme> <example.com> '
        '<https://example.com/a path> <reader@example.com->',
      );
    });

    test('invalid angle-bracket candidates remain visible in headings', () {
      final heading = single<HeadingBlock>(
        '# <m:one-character-scheme> and <reader@bad..example.com>',
      );

      expect(
        heading.text,
        '<m:one-character-scheme> and <reader@bad..example.com>',
      );
    });

    test('GFM recognises bare web addresses and email addresses', () {
      final paragraph = single<ParagraphBlock>(
        'https://example.com/guide, www.example.com/help, and '
        'reader.notes+visual@example.com.',
      );
      final links = paragraph.content.whereType<LinkRun>().toList();

      expect(links.map((link) => link.text), [
        'https://example.com/guide',
        'www.example.com/help',
        'reader.notes+visual@example.com',
      ]);
      expect(links.map((link) => link.href), [
        'https://example.com/guide',
        'http://www.example.com/help',
        'mailto:reader.notes+visual@example.com',
      ]);
      expect(paragraph.text, endsWith('reader.notes+visual@example.com.'));
    });

    test('GFM keeps sentence punctuation outside a bare URL', () {
      final paragraph = single<ParagraphBlock>(
        '(Visit https://example.com/search?q=Markup+(business)). '
        'Then www.example.com/a.b.',
      );
      final links = paragraph.content.whereType<LinkRun>().toList();

      expect(links.map((link) => link.text), [
        'https://example.com/search?q=Markup+(business)',
        'www.example.com/a.b',
      ]);
      expect(
        paragraph.text,
        '(Visit https://example.com/search?q=Markup+(business)). '
        'Then www.example.com/a.b.',
      );
    });

    test('a bare URL needs a valid left boundary', () {
      final paragraph = single<ParagraphBlock>(
        'prefixhttps://example.com is literal; '
        '(https://example.com) is linked.',
      );
      final links = paragraph.content.whereType<LinkRun>().toList();

      expect(links, hasLength(1));
      expect(links.single.text, 'https://example.com');
      expect(links.single.href, 'https://example.com');
      expect(paragraph.text, contains('prefixhttps://example.com'));
    });
  });

  group('soft line breaks', () {
    test('source wrapping disappears into one word separator', () {
      final paragraph = single<ParagraphBlock>(
        'one line\nand its continuation\r\nacross another source line',
      );

      expect(paragraph.content.whereType<LineBreakRun>(), isEmpty);
      expect(
        paragraph.text,
        'one line and its continuation across another source line',
      );
    });

    test('adjoining indentation disappears but internal spacing remains', () {
      final paragraph = single<ParagraphBlock>(
        'one line \n   continues\t\n\tthrough tabs and  keeps an internal pair',
      );

      expect(
        paragraph.text,
        'one line continues through tabs and  keeps an internal pair',
      );
    });

    test(
      'normalises wrapping inside marks and links without flattening them',
      () {
        final paragraph = single<ParagraphBlock>(
          'one *soft\n break* and [linked\n words](https://example.com)',
        );
        final emphasis = paragraph.content.whereType<MarkedRun>().single;
        final link = paragraph.content.whereType<LinkRun>().single;

        expect(emphasis.text, 'soft break');
        expect(link.text, 'linked words');
        expect(link.href, 'https://example.com');
        expect(paragraph.text, 'one soft break and linked words');
      },
    );

    test('Chinese and Japanese source wrapping adds no Western word space even across marks', () {
      final paragraph = single<ParagraphBlock>(
        '中文源代码\n*继续阅读*\n日本語の文書\n[詳細](https://example.com)',
      );

      expect(paragraph.text, '中文源代码继续阅读日本語の文書詳細');
    });

    test('space-separated scripts keep their word separator', () {
      expect(
        single<ParagraphBlock>('مرحبا بالعالم\nهذا سطر ملفوف').text,
        'مرحبا بالعالم هذا سطر ملفوف',
      );
      expect(
        single<ParagraphBlock>('עברית בשורה\nממשיכה כאן').text,
        'עברית בשורה ממשיכה כאן',
      );
      expect(
        single<ParagraphBlock>('한국어 문장이\n여기서 계속됩니다').text,
        '한국어 문장이 여기서 계속됩니다',
      );
    });

    test('the same joining rule survives quotation and list containers', () {
      final blocks = parse(
        '> quoted source\n> wraps here\n\n- listed source\n  wraps here',
      ).blocks;
      final quote = blocks.first as QuoteBlock;
      final list = blocks.last as ListBlock;

      expect(quote.text, 'quoted source wraps here');
      expect(list.items.single.text, 'listed source wraps here');
    });

    test('code spans remain different grammar', () {
      final code = single<ParagraphBlock>('read `one\ntwo` now');
      expect(code.content.whereType<CodeRun>().single.text, 'one two');
    });
  });

  group('hard line breaks', () {
    test(
      'two or more spaces and a backslash produce the same authored line',
      () {
        for (final source in [
          'first line  \nsecond line',
          'first line       \nsecond line',
          'first line\\\nsecond line',
          'first line  \r\nsecond line',
          'first line\\\r\nsecond line',
        ]) {
          final paragraph = single<ParagraphBlock>(source);

          expect(paragraph.content.whereType<LineBreakRun>(), hasLength(1));
          expect(paragraph.text, 'first line\nsecond line');
        }
      },
    );

    test(
      'indentation after an authored line is formatting, not reading text',
      () {
        for (final source in [
          'first line  \n     second line',
          'first line\\\n\t\tsecond line',
        ]) {
          final paragraph = single<ParagraphBlock>(source);

          expect(paragraph.text, 'first line\nsecond line');
        }
      },
    );

    test('authored lines remain inside emphasis and links', () {
      final paragraph = single<ParagraphBlock>(
        '*first line  \n     second line* and '
        '[third line\\\n    fourth line](https://example.com)',
      );
      final emphasis = paragraph.content.whereType<MarkedRun>().single;
      final link = paragraph.content.whereType<LinkRun>().single;

      expect(emphasis.text, 'first line\nsecond line');
      expect(emphasis.children.whereType<LineBreakRun>(), hasLength(1));
      expect(link.text, 'third line\nfourth line');
      expect(link.children.whereType<LineBreakRun>(), hasLength(1));
      expect(link.href, 'https://example.com');
    });

    test('authored lines survive headings, quotations, and list items', () {
      final heading = single<HeadingBlock>('first  \nsecond\n===');
      final quote =
          parse('> first  \n>     second').blocks.single as QuoteBlock;
      final list = parse('- first\\\n      second').blocks.single as ListBlock;

      expect(heading.text, 'first\nsecond');
      expect(heading.content.whereType<LineBreakRun>(), hasLength(1));
      expect(quote.text, 'first\nsecond');
      expect(list.items.single.text, 'first\nsecond');
    });

    test('consecutive authored lines remain consecutive', () {
      final paragraph = single<ParagraphBlock>('first  \n\\\nthird');

      expect(paragraph.content.whereType<LineBreakRun>(), hasLength(2));
      expect(paragraph.text, 'first\n\nthird');
    });

    test('code spans and block endings do not invent a hard break', () {
      final spaces = single<ParagraphBlock>('`code  \nspan`');
      final slash = single<ParagraphBlock>('`code\\\nspan`');
      expect(spaces.content.whereType<CodeRun>().single.text, 'code   span');
      expect(slash.content.whereType<CodeRun>().single.text, 'code\\ span');

      final terminalSlash = single<ParagraphBlock>('paragraph\\\n');
      final terminalSpaces = single<ParagraphBlock>('paragraph  \n');
      final headingSlash = single<HeadingBlock>('### heading\\\n');
      final headingSpaces = single<HeadingBlock>('### heading  \n');

      expect(terminalSlash.text, 'paragraph\\');
      expect(terminalSpaces.text, 'paragraph');
      expect(headingSlash.text, 'heading\\');
      expect(headingSpaces.text, 'heading');
      expect(
        [terminalSlash, terminalSpaces, headingSlash, headingSpaces]
            .expand(
              (block) => switch (block) {
                ParagraphBlock(:final content) => content,
                HeadingBlock(:final content) => content,
                _ => const <Inline>[],
              },
            )
            .whereType<LineBreakRun>(),
        isEmpty,
      );
    });
  });

  group('backslash escapes', () {
    test('every ASCII punctuation mark can become literal reading text', () {
      final punctuation = String.fromCharCodes([
        ...List.generate(0x2f - 0x21 + 1, (index) => 0x21 + index),
        ...List.generate(0x40 - 0x3a + 1, (index) => 0x3a + index),
        ...List.generate(0x60 - 0x5b + 1, (index) => 0x5b + index),
        ...List.generate(0x7e - 0x7b + 1, (index) => 0x7b + index),
      ]);

      for (final codeUnit in punctuation.codeUnits) {
        final mark = String.fromCharCode(codeUnit);
        final paragraph = single<ParagraphBlock>('\\$mark');
        expect(paragraph.text, mark, reason: 'U+${codeUnit.toRadixString(16)}');
        expect(paragraph.content, [TextRun(mark)]);
      }
    });

    test('a backslash before anything else remains authored text', () {
      const source = r'\A \3 \→ \φ \« before\ after';
      expect(single<ParagraphBlock>(source).text, source);
    });

    test('escaped block and inline markers lose their grammar role', () {
      final content = parse(r'''
\# not a heading

\* not a list

1\. not a list

\*not emphasis\* and \`not code\`

\[not a link\](destination) and \&copy;

\[label]: relative/path

\<span>not raw HTML\</span>
''');

      expect(content.blocks, everyElement(isA<ParagraphBlock>()));
      expect(content.blocks.map((block) => block.text), [
        '# not a heading',
        '* not a list',
        '1. not a list',
        '*not emphasis* and `not code`',
        '[not a link](destination) and &copy;',
        '[label]: relative/path',
        '<span>not raw HTML</span>',
      ]);
      final runs = content.blocks.whereType<ParagraphBlock>().expand(
        (paragraph) => paragraph.content,
      );
      expect(runs.whereType<MarkedRun>(), isEmpty);
      expect(runs.whereType<CodeRun>(), isEmpty);
      expect(runs.whereType<LinkRun>(), isEmpty);
    });

    test('an escaped backslash exposes the real delimiter after it', () {
      final paragraph = single<ParagraphBlock>(r'\\*emphasis*');

      expect(paragraph.text, r'\emphasis');
      expect(paragraph.content.first, const TextRun(r'\'));
      expect(paragraph.content.last, isA<MarkedRun>());
    });

    test('escape boundaries do not divide one typographic phrase', () {
      final paragraph = single<ParagraphBlock>(r'\... and \"quoted\"');

      expect(paragraph.content, [const TextRun('... and "quoted"')]);
    });

    test(
      'code keeps escapes while destinations and fence info resolve them',
      () {
        final inline = single<ParagraphBlock>(r'`\[\*`');
        expect(inline.content.single, const CodeRun(r'\[\*'));

        final block = single<CodeBlock>('```foo\\+bar\n\\* literal\n```');
        expect(block.language, 'foo+bar');
        expect(block.code, r'\* literal');

        final linked =
            single<ParagraphBlock>(r'[label](/bar\* "title\*")').content.single
                as LinkRun;
        expect(linked.href, '/bar*');
        expect(linked.title, 'title*');
      },
    );

    test('autolinks keep backslashes because they are literal regions', () {
      final link =
          single<ParagraphBlock>(r'<https://example.com?find=\*>')
                  .content
                  .single
              as LinkRun;

      expect(link.text, r'https://example.com?find=\*');
      expect(link.href, contains('%5C*'));
    });
  });

  group('character references', () {
    test('named, decimal, and hexadecimal forms become reading text', () {
      final paragraph = single<ParagraphBlock>(
        '&nbsp; &amp; &copy; &AElig; &Dcaron; &frac34; &HilbertSpace; '
        '&DifferentialD; &ClockwiseContourIntegral; &ngE; '
        '&#35; &#1234; &#992; &#0; &#X22; &#XD06; &#xcab;',
      );

      expect(paragraph.text, '\u00a0 & © Æ Ď ¾ ℋ ⅆ ∲ ≧̸ # Ӓ Ϡ � " ആ ಫ');
      expect(single<ParagraphBlock>('&#1; &#x1;').text, '� \u0001');
    });

    test('malformed and unknown forms remain authored text', () {
      const source =
          '&nbsp &x; &#; &#x; &#87654321; &#abcdef0; '
          '&ThisIsNotDefined; &hi?; &copy';

      expect(single<ParagraphBlock>(source).text, source);
    });

    test('decoded punctuation cannot create markdown structure', () {
      final content = parse('''
&#42;foo&#42;

&#42; foo

&#35; heading-shaped text
''');

      expect(content.blocks, everyElement(isA<ParagraphBlock>()));
      expect(content.blocks.map((block) => block.text), [
        '*foo*',
        '* foo',
        '# heading-shaped text',
      ]);
      expect(
        content.blocks
            .whereType<ParagraphBlock>()
            .expand((paragraph) => paragraph.content)
            .whereType<MarkedRun>(),
        isEmpty,
      );
    });

    test('code keeps references while link metadata and fence info decode', () {
      final inline = single<ParagraphBlock>('`f&ouml;&ouml;`');
      expect(inline.content.single, const CodeRun('f&ouml;&ouml;'));

      final block = single<CodeBlock>('```f&ouml;&ouml;\nbody &copy;\n```');
      expect(block.language, 'föö');
      expect(block.code, 'body &copy;');

      final link =
          single<ParagraphBlock>('[foo](/f&ouml;&ouml; "f&ouml;&ouml;")')
                  .content
                  .single
              as LinkRun;
      expect(link.href, '/f%C3%B6%C3%B6');
      expect(link.title, 'föö');
    });

    test('reference boundaries do not divide one typographic phrase', () {
      final paragraph = single<ParagraphBlock>(
        '&quot;quoted&quot; and an ellipsis&#46;&#46;&#46;',
      );

      expect(paragraph.content, [const TextRun('"quoted" and an ellipsis...')]);
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

    test('a setext heading parses every source line as inline content', () {
      final heading = single<HeadingBlock>(
        'First *line*\n'
        'continues with `code` and [a link](https://example.com)\n'
        '====\n',
      );

      expect(heading.level, 1);
      expect(heading.text, 'First line continues with code and a link');
      expect(heading.content.whereType<MarkedRun>(), hasLength(1));
      expect(heading.content.whereType<CodeRun>(), hasLength(1));
      expect(heading.content.whereType<LinkRun>(), hasLength(1));
    });

    test('a hyphen underline makes the complete paragraph level two', () {
      final heading = single<HeadingBlock>(
        'A level-two heading begins here\n'
        'and continues on another source line\n'
        '---\n',
      );

      expect(heading.level, 2);
      expect(
        heading.text,
        'A level-two heading begins here and continues on another source line',
      );
    });
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

  group('plain Unicode', () {
    test('preserves combining sequences without normalising the source', () {
      const source =
          'Precomposed café; decomposed nai\u0308ve; stacked Z\u0351\u036b\u0343; '
          'and Devanagari क्षि.';

      final paragraph = single<ParagraphBlock>(source);

      expect(paragraph.text, source);
      expect(paragraph.text, contains('i\u0308'));
      expect(paragraph.text, isNot(contains('ï')));
    });

    test('preserves complete emoji, bidirectional, and CJK sequences', () {
      const source =
          'Emoji 👩🏽‍💻, family 👨‍👩‍👧‍👦, flag 🇵🇭, and keycap 1️⃣. '
          'العربية 123 beside עברית; 中文日本語沒有空格。';

      final paragraph = single<ParagraphBlock>(source);

      expect(paragraph.text, source);
      expect(paragraph.text, contains('👩🏽‍💻'));
      expect(paragraph.text, contains('👨‍👩‍👧‍👦'));
      expect(paragraph.text, endsWith('中文日本語沒有空格。'));
    });
  });

  group('the smaller shapes', () {
    test('every CommonMark thematic-break form becomes the same block', () {
      for (final source in [
        '***\n',
        '---\n',
        '___\n',
        ' *  *\t*   *   *\n',
        '  -     -      -      -\t\n',
        '   _ _ _ _ _ _\n',
      ]) {
        expect(
          single<RuleBlock>(source),
          isA<RuleBlock>(),
          reason: source.replaceAll('\t', r'\t'),
        );
      }
    });

    test('near misses remain authored content rather than becoming rules', () {
      for (final source in [
        '+++\n',
        '===\n',
        '--\n',
        '**\n',
        '__\n',
        '*-*\n',
        '_ _ _ a\n',
        '---a---\n',
        '    ***\n',
        '&#42;&#42;&#42;\n',
      ]) {
        expect(
          parse(source).blocks.whereType<RuleBlock>(),
          isEmpty,
          reason: source,
        );
      }
    });

    test('a rule interrupts prose without borrowing either paragraph', () {
      final blocks = parse('Before.\n***\nAfter.\n').blocks;

      expect(blocks, [
        isA<ParagraphBlock>().having((block) => block.text, 'text', 'Before.'),
        isA<RuleBlock>(),
        isA<ParagraphBlock>().having((block) => block.text, 'text', 'After.'),
      ]);
    });

    test('setext and list precedence preserve the authored structure', () {
      final setext = parse('A section title\n---\n').blocks;
      expect(setext, [
        isA<HeadingBlock>()
            .having((block) => block.level, 'level', 2)
            .having((block) => block.text, 'text', 'A section title'),
      ]);

      final dividedLists = parse('* First\n* * *\n* Second\n').blocks;
      expect(dividedLists, [
        isA<ListBlock>().having(
          (list) => list.items.single.text,
          'item',
          'First',
        ),
        isA<RuleBlock>(),
        isA<ListBlock>().having(
          (list) => list.items.single.text,
          'item',
          'Second',
        ),
      ]);

      final nested = single<ListBlock>('- First\n- * * *\n');
      expect(nested.items.last.blocks.single, isA<RuleBlock>());
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
