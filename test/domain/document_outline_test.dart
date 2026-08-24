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

    test('shares reference link definitions with every section', () {
      final outline = DocumentOutline.parse(
        '[see][ref]\n\n# A\n\nuse [ref]\n\n[ref]: https://example.com\n',
      );
      for (final section in outline.sections) {
        expect(section.markdown, contains('[ref]: https://example.com'));
      }
    });

    test('sets front matter aside and reads its title', () {
      final outline = DocumentOutline.parse(
        '---\ntitle: "From Front Matter"\ntags: [a]\n---\n\n# Body Heading\n',
      );
      expect(outline.frontMatter, 'title: "From Front Matter"\ntags: [a]');
      expect(outline.title, 'From Front Matter');
      expect(outline.sections.first.markdown, isNot(contains('tags:')));
      expect(outline.sections.first.heading!.line, 5);
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
