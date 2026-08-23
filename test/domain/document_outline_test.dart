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
