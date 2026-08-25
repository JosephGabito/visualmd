import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/domain/library/document.dart';
import 'package:visualmd/domain/library/document_id.dart';
import 'package:visualmd/domain/library/library_root_id.dart';
import 'package:visualmd/domain/reading/document_outline.dart';

void main() {
  const rootId = LibraryRootId('test');
  group('DocumentOutline', () {
    test('extracts ATX headings with levels, text and anchors', () {
      final outline = DocumentOutline.parse('''
# Purpose and Status

## Purpose ##

Text.

### `code` and [a link](http://x) and **bold**
''');
      final h = outline.tableOfContents.headings;
      expect(h.map((x) => x.level), [1, 2, 3]);
      expect(h.map((x) => x.text), [
        'Purpose and Status',
        'Purpose',
        'code and a link and bold',
      ]);
      expect(h.map((x) => x.anchor), [
        'purpose-and-status',
        'purpose',
        'code-and-a-link-and-bold',
      ]);
      expect(outline.title, 'Purpose and Status');
    });

    test('escaped ASCII punctuation remains visible in a heading', () {
      final punctuation = String.fromCharCodes([
        ...List.generate(0x2f - 0x21 + 1, (index) => 0x21 + index),
        ...List.generate(0x40 - 0x3a + 1, (index) => 0x3a + index),
        ...List.generate(0x60 - 0x5b + 1, (index) => 0x5b + index),
        ...List.generate(0x7e - 0x7b + 1, (index) => 0x7b + index),
      ]);
      final escaped = punctuation.codeUnits
          .map((codeUnit) => '\\${String.fromCharCode(codeUnit)}')
          .join();

      final heading = DocumentOutline.parse('# $escaped')
          .tableOfContents
          .headings
          .single;

      expect(heading.text, punctuation);
      expect(heading.anchor, '-');
    });

    test('literal regions and one-sided escapes keep their exact meaning', () {
      expect(
        DocumentOutline.parse(r'# \*not emphasis* | \`not code`')
            .tableOfContents
            .headings
            .single
            .text,
        r'*not emphasis* | `not code`',
      );
      expect(
        DocumentOutline.parse(
          r'# \\*emphasis* | `\* code` | <https://example.com?find=\*>',
        ).tableOfContents.headings.single.text,
        r'\emphasis | \* code | https://example.com?find=\*',
      );
      expect(
        DocumentOutline.parse('# ``  padded code  ``')
            .tableOfContents
            .headings
            .single
            .text,
        ' padded code ',
      );
    });

    test('character references resolve after heading grammar is settled', () {
      final headings = DocumentOutline.parse(r'''
# &copy; &#35; &HilbertSpace; &ngE;

## &#42;literal&#42; and \&copy; and `&amp;`
''').tableOfContents.headings;

      expect(headings.map((heading) => heading.text), [
        '© # ℋ ≧̸',
        r'*literal* and &copy; and &amp;',
      ]);
      expect(headings.map((heading) => heading.anchor), [
        'ℋ',
        'literal-and-copy-and-amp',
      ]);
    });

    test('nested heading marks agree on plain text and anchors', () {
      final headings = DocumentOutline.parse(r'''
# ***Combined importance***

## **Strong with _nested voice_**

### *foo**bar*
''').tableOfContents.headings;

      expect(headings.map((heading) => heading.text), [
        'Combined importance',
        'Strong with nested voice',
        'foo**bar',
      ]);
      expect(headings.map((heading) => heading.anchor), [
        'combined-importance',
        'strong-with-nested-voice',
        'foobar',
      ]);
    });

    test('reference link headings agree with the rendered page', () {
      final headings = DocumentOutline.parse(r'''
# [Full **heading**][Guide]
## [Collapsed *heading*][]
### [Shortcut `heading`]
#### [Missing][unknown]
##### [Also missing][]
###### [Still missing]

[guide]: /manual
[collapsed *heading*]: /collapsed
[shortcut `heading`]: /shortcut
''').tableOfContents.headings;

      expect(headings.map((heading) => heading.text), [
        'Full heading',
        'Collapsed heading',
        'Shortcut heading',
        '[Missing][unknown]',
        '[Also missing][]',
        '[Still missing]',
      ]);
      expect(headings.map((heading) => heading.anchor), [
        'full-heading',
        'collapsed-heading',
        'shortcut-heading',
        'missingunknown',
        'also-missing',
        'still-missing',
      ]);
    });

    test('reference labels fold Unicode case and formatting whitespace', () {
      final heading = DocumentOutline.parse('''
[ẞ Guide][  SS
 GUIDE ]
========

[SS Guide]: /unicode
''').tableOfContents.headings.single;

      expect(heading.text, 'ẞ Guide');
      expect(heading.anchor, 'ß-guide');
    });

    test('delimiter precedence preserves only genuinely literal marks', () {
      final headings = DocumentOutline.parse(r'''
# *foo**bar*

## *foo _bar* baz_

### **foo **bar baz**

#### foo***bar***baz

##### \**escaped opener* and **escaped closer\***
''').tableOfContents.headings;

      expect(headings.map((heading) => heading.text), [
        'foo**bar',
        'foo _bar baz_',
        '**foo bar baz',
        'foobarbaz',
        '*escaped opener and escaped closer*',
      ]);
    });

    test('formal GFM strikethrough keeps only eligible tildes', () {
      final headings = DocumentOutline.parse(r'''
# ~single~ and ~~double~~

## before~inside~after and ~shorter~~

### ~ leading~ and ~trailing ~

#### ~~~three~~~ and ~~~~four~~~~

##### ~~old **important** `literal ~` and [guide](https://example.com)~~
''').tableOfContents.headings;

      expect(headings.map((heading) => heading.text), [
        'single and double',
        'beforeinsideafter and shorter~',
        '~ leading~ and ~trailing ~',
        '~~~three~~~ and ~~~~four~~~~',
        'old important literal ~ and guide',
      ]);
      expect(headings.map((heading) => heading.anchor), [
        'single-and-double',
        'beforeinsideafter-and-shorter',
        'leading-and-trailing',
        'three-and-four',
        'old-important-literal-and-guide',
      ]);
    });

    test('malformed references and literal regions remain untouched', () {
      final heading = DocumentOutline.parse(
        '# &MadeUpEntity; &copy and '
        '`&copy;` <https://example.com?q=&copy;>',
      ).tableOfContents.headings.single;

      expect(
        heading.text,
        '&MadeUpEntity; &copy and &copy; https://example.com?q=&copy;',
      );
      expect(heading.anchor, 'madeupentity-copy-and-copy-httpsexamplecomqcopy');
    });

    test('autolink headings keep only the words a reader sees', () {
      final headings = DocumentOutline.parse('''
# <https://example.com/angle> and <reader@example.com>

## https://example.com/bare and www.example.com
''').tableOfContents.headings;

      expect(headings.map((heading) => heading.text), [
        'https://example.com/angle and reader@example.com',
        'https://example.com/bare and www.example.com',
      ]);
      expect(headings.map((heading) => heading.anchor), [
        'httpsexamplecomangle-and-readerexamplecom',
        'httpsexamplecombare-and-wwwexamplecom',
      ]);
    });

    test('ignores headings inside fenced code blocks', () {
      final outline = DocumentOutline.parse('''
# Real

```md
# Not a heading
```

~~~
## Also not
~~~

````
```
# Nested fence, still code
```
````

## Real too
''');
      expect(outline.tableOfContents.headings.map((x) => x.text), [
        'Real',
        'Real too',
      ]);
    });

    test('supports setext headings but not rules or tables', () {
      final outline = DocumentOutline.parse('''
Title
=====

Sub
---

---

| a | b |
|---|---|
| 1 | 2 |

- item
---
''');
      final h = outline.tableOfContents.headings;
      expect(h.map((x) => '${x.level}:${x.text}'), ['1:Title', '2:Sub']);
    });

    test('a setext heading owns every source line in its paragraph', () {
      final outline = DocumentOutline.parse(
        'First *line*\n'
        'continues with `code` and [a link](https://example.com)\n'
        '====\n'
        'body\n'
        '\n'
        'Second line\n'
        'continues too\n'
        '---\n'
        'after\n',
      );

      expect(
        outline.tableOfContents.headings.map(
          (heading) => (heading.level, heading.text, heading.line),
        ),
        [
          (1, 'First line continues with code and a link', 0),
          (2, 'Second line continues too', 5),
        ],
      );
      expect(outline.title, 'First line continues with code and a link');
      expect(outline.sections, hasLength(2));
      expect(
        outline.sections.first.markdown,
        startsWith('First *line*\ncontinues with `code`'),
      );
      expect(outline.sections.last.markdown, startsWith('Second line\n'));
    });

    test('setext content must otherwise be an ordinary paragraph', () {
      expect(
        DocumentOutline.parse('    indented code\n---\n')
            .tableOfContents
            .headings,
        isEmpty,
      );
      expect(
        DocumentOutline.parse('[reference]: https://example.com\n---\n')
            .tableOfContents
            .headings,
        isEmpty,
      );
      final hashText = DocumentOutline.parse('#not-an-atx-heading\n===\n')
          .tableOfContents
          .headings
          .single;
      expect(hashText.text, '#not-an-atx-heading');
      expect(hashText.anchor, 'not-an-atx-heading');
    });

    test('makes duplicate anchors unique', () {
      final outline = DocumentOutline.parse(
        '# Setup\n## Setup\n## Setup\n## ???\n',
      );
      expect(outline.tableOfContents.headings.map((x) => x.anchor), [
        'setup',
        'setup-1',
        'setup-2',
        'section',
      ]);
    });

    test('cuts sections at headings, keeping the heading line', () {
      final outline = DocumentOutline.parse(
        'intro\n\n# One\nbody one\n\n## Two\nbody two\n',
      );
      final s = outline.sections;
      expect(s.length, 3);
      expect(s[0].heading, isNull);
      expect(s[0].markdown.trim(), 'intro');
      expect(s[1].heading!.text, 'One');
      expect(s[1].markdown, '# One\nbody one\n');
      expect(s[2].markdown, '## Two\nbody two\n');
    });

    test(
      'sections remain exact source slices around reference definitions',
      () {
        final outline = DocumentOutline.parse(
          '[see][ref]\n\n# A\n\nuse [ref]\n\n[ref]: https://example.com\n',
        );

        expect(outline.sections, hasLength(2));
        expect(outline.sections.first.markdown, '[see][ref]\n');
        expect(
          outline.sections.last.markdown,
          '# A\n\nuse [ref]\n\n[ref]: https://example.com\n',
        );
      },
    );

    test('sets front matter aside and reads its title', () {
      final outline = DocumentOutline.parse(
        '---\ntitle: "From Front Matter"\ntags: [a]\n---\n\n# Body Heading\n',
      );
      expect(outline.frontMatter, 'title: "From Front Matter"\ntags: [a]');
      expect(outline.title, 'From Front Matter');
      expect(outline.sections.first.markdown, isNot(contains('tags:')));
      expect(outline.sections.first.heading!.line, 5);
    });

    test('the lightweight title index agrees with a complete outline', () {
      final sources = [
        '---\ntitle: "From Front Matter"\n---\n# Body\n',
        '```md\n# Not the title\n```\n\n# Actual **title**\n',
        '# A [reference][later]\n\n[later]: https://example.com\n',
        'First *line*\ncontinues with `code`\n====\n\n## Later\n',
        '## No level one\n',
      ];

      for (final source in sources) {
        expect(
          DocumentOutline.titleOf(source),
          DocumentOutline.parse(source).title,
        );
      }
    });

    test('handles CRLF and an empty document', () {
      expect(
        DocumentOutline.parse('# A\r\n\r\ntext\r\n')
            .tableOfContents
            .headings
            .single
            .text,
        'A',
      );
      final empty = DocumentOutline.parse('');
      expect(empty.sections, isEmpty);
      expect(empty.title, isNull);
    });
  });

  group('Document', () {
    test('title falls back to the file name without extension', () {
      final doc = Document(
        id: DocumentId(rootId, 'guides/02-vocabulary.md'),
        content: 'no heading here',
      );
      expect(doc.title, '02-vocabulary');
      expect(
        Document(id: DocumentId(rootId, 'x.md'), content: '# Hello').title,
        'Hello',
      );
    });

    test('rejects non-markdown files', () {
      expect(
        () => Document(id: DocumentId(rootId, 'a.txt'), content: ''),
        throwsArgumentError,
      );
    });
  });
}
