import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/domain/reading/content/block.dart';
import 'package:visualmd/domain/reading/content/document_content.dart';
import 'package:visualmd/domain/reading/content/inline.dart';
import 'package:visualmd/infrastructure/markdown/markdown_document_parser.dart';

void main() {
  const parser = MarkdownDocumentParser();

  test('an unfinished paragraph revises one stable provisional block', () {
    final session = parser.startSession();

    final first = session.append('A paragraph');
    final id = first.entries.single.id;
    final second = session.append(' still arriving');

    expect(second.entries.single.id, id);
    expect(second.entries.single.revision, 2);
    expect(second.entries.single.commitment, BlockCommitment.provisional);
    expect(second.blocks.single.text, 'A paragraph still arriving');
    expect(second.entries.single.textAppend?.baseRevision, 1);
    expect(second.entries.single.textAppend?.text, ' still arriving');
  });

  test(
    'prose which closes Markdown syntax is not misreported as an append',
    () {
      final session = parser.startSession();

      final first = session.append('An *unfinished');
      final second = session.append(' emphasis*');

      expect(first.blocks.single.text, 'An *unfinished');
      expect(second.blocks.single.text, 'An unfinished emphasis');
      expect(second.entries.single.textAppend, isNull);
      expect(second.entries.single.inlineAppend, isNull);
    },
  );

  test('a stable rich paragraph advertises only its new inline suffix', () {
    final session = parser.startSession();

    final first = session.append('A **bold** thought');
    final previous = first.entries.single;
    final second = session.append(' keeps `streaming`.');
    final current = second.entries.single;

    expect(current.id, previous.id);
    expect(current.textAppend, isNull);
    expect(current.inlineAppend?.baseRevision, previous.revision);
    expect(current.inlineAppend?.runs, const [
      TextRun(' keeps '),
      CodeRun('streaming'),
      TextRun('.'),
    ]);
    expect(
      '${previous.block.text}'
      '${current.inlineAppend!.runs.map((run) => run.text).join()}',
      current.block.text,
    );
  });

  test('a closed rich checkpoint parses only the newly arriving suffix', () {
    final session = parser.startSession();
    final prefix = List.filled(1000, 'A **bold** thought. ').join();
    final first = session.append(prefix);
    const suffix = 'keeps `streaming`.';

    final second = session.append(suffix);

    expect(session.lastParsedSourceLength, suffix.length + 1);
    expect(
      second.blocks.single.text,
      '${first.blocks.single.text} keeps streaming.',
    );
    expect(second.entries.single.inlineAppend?.runs, const [
      TextRun(' keeps '),
      CodeRun('streaming'),
      TextRun('.'),
    ]);
  });

  test('accepted rich checkpoints match the canonical inline tree', () {
    const cases = <(String, String)>[
      ('Plain generated prose. ', 'More words.'),
      ('A **strong** statement. ', '*Emphasis* follows.'),
      ('Nested **strong and _emphasis_**. ', 'Then `code`.'),
      ('A [link](https://example.com). ', 'Then ~~deleted~~ text.'),
      ('An ![image](image.png). ', r'Then an escaped \* mark.'),
      ('Balanced (parenthetical) prose. ', '**A final phrase.**'),
    ];

    for (final (prefix, suffix) in cases) {
      final session = parser.startSession();
      session.append(prefix);

      final incremental = session.append(suffix);
      final canonical = parser.parse('$prefix$suffix');

      expect(session.lastParsedSourceLength, suffix.length + 1, reason: prefix);
      expect(_shape(incremental.blocks), _shape(canonical.blocks));
    }
  });

  test('successive rich checkpoints remain canonical', () {
    final session = parser.startSession();
    const chunks = <String>[
      'A **first** phrase. ',
      'A `second` phrase. ',
      'A [third](https://example.com) phrase. ',
      'The end.',
    ];
    var source = '';

    for (final chunk in chunks) {
      source += chunk;
      final incremental = session.append(chunk);
      final canonical = parser.parse(source);

      expect(_shape(incremental.blocks), _shape(canonical.blocks));
    }
  });

  test('checkpoint whitespace becomes visible only when prose follows it', () {
    final session = parser.startSession();
    final first = session.append('Complete. ');

    final whitespace = session.append(' \t');

    expect(whitespace.revision, first.revision);
    expect(whitespace.blocks.single.text, 'Complete.');
    expect(session.lastParsedSourceLength, 0);

    final continued = session.append('Next.');
    final canonical = parser.parse('Complete.  \tNext.');

    expect(_shape(continued.blocks), _shape(canonical.blocks));
  });

  test('delimiter closure proves only the uncertain inline tail changed', () {
    final session = parser.startSession();
    final stable = session.append('Settled **strong** prose. ');
    final opened = session.append('An **unfinished');

    final closed = session.append(' thought**.');
    final proof = closed.entries.single.inlineTailReplace!;

    expect(proof.baseRevision, opened.entries.single.revision);
    expect(proof.retainedPrefix, stable.entries.single.textMetrics);
    expect(
      '${opened.blocks.single.text.substring(0, proof.retainedPrefix.codeUnits)}'
      '${proof.runs.map((run) => run.text).join()}',
      closed.blocks.single.text,
    );
    expect(
      closed.entries.single.textMetrics.codeUnits,
      closed.blocks.single.text.length,
    );
    expect(closed.entries.single.inlineAppend, isNull);
  });

  test('ambiguous inline boundaries retain the complete parser fallback', () {
    const cases = <String>[
      'An *unclosed delimiter ',
      'An <sub>open HTML tag ',
      'An &amp; entity ',
      'A source line\n',
    ];

    for (final prefix in cases) {
      final session = parser.startSession();
      session.append(prefix);
      const suffix = 'continues.';

      session.append(suffix);

      expect(
        session.lastParsedSourceLength,
        prefix.length + suffix.length,
        reason: prefix,
      );
    }
  });

  test('a blank line commits prose and later work visits only the tail', () {
    final session = parser.startSession();
    final first = session.append('Alpha.\n\n');
    final alpha = first.entries.single.id;
    final committedLength = session.committedSourceLength;

    final second = session.append('Beta');

    expect(second.entries.first.id, alpha);
    expect(second.entries.first.commitment, BlockCommitment.committed);
    expect(second.entries.last.commitment, BlockCommitment.provisional);
    expect(session.committedSourceLength, committedLength);
    expect(session.provisionalSourceLength, 4);
    expect(session.lastParsedSourceLength, 4);
  });

  test('Setext syntax can reinterpret only the provisional tail', () {
    final session = parser.startSession();

    expect(session.append('A title\n').blocks.single, isA<ParagraphBlock>());
    final content = session.append('=======\n\n');

    final heading = content.blocks.single as HeadingBlock;
    expect(heading.text, 'A title');
    expect(heading.level, 1);
    expect(content.entries.single.commitment, BlockCommitment.committed);
  });

  test('an open container stays provisional until following prose settles', () {
    final session = parser.startSession();

    var content = session.append('```dart\nfinal answer = 42;\n\n');
    expect(content.entries.single.commitment, BlockCommitment.provisional);

    content = session.append('```\n\nAfterward.\n\n');
    expect(content.blocks, [isA<CodeBlock>(), isA<ParagraphBlock>()]);
    expect(
      content.entries.every(
        (entry) => entry.commitment == BlockCommitment.committed,
      ),
      isTrue,
    );
  });

  test('an open code fence publishes only its newly visible suffix', () {
    final session = parser.startSession();

    final first = session.append('```dart\nfinal first = 1;');
    final previous = first.entries.single;
    final second = session.append('\nfinal second = 2;');
    final current = second.entries.single;

    expect(current.id, previous.id);
    expect(current.textAppend?.baseRevision, previous.revision);
    expect(current.textAppend?.text, '\nfinal second = 2;');
    expect(
      '${previous.block.text}${current.textAppend?.text}',
      current.block.text,
    );
  });

  test('heading anchors remain unique across committed parse windows', () {
    final session = parser.startSession();

    session.append('# Same\n\n');
    final content = session.append('# Same\n\n');

    expect(
      content.blocks.whereType<HeadingBlock>().map((heading) => heading.anchor),
      ['same', 'same-1'],
    );
  });

  test('a late reference definition rebases its affected semantics', () {
    final session = parser.startSession();

    expect(
      session.append('[OpenAI][ref]\n\n').blocks.single.text,
      '[OpenAI][ref]',
    );
    final content = session.append('[ref]: https://openai.com\n\n');

    expect(content.blocks.single.text, 'OpenAI');
    expect(session.committedSourceLength, session.sourceLength);
  });

  test('finishing is exactly equivalent to the complete parser', () {
    const source = '''---
title: Stream
---

# Same

Text with **weight** and [a link][ref].

> A quotation
>
> with two paragraphs.

- one
- two

```dart
final answer = 42;
```

# Same

[ref]: https://example.com
''';
    final session = parser.startSession();
    for (final chunk in _chunks(source, 7)) {
      session.append(chunk);
    }

    final streamed = session.finish();
    final complete = parser.parse(source);

    expect(_shape(streamed.blocks), _shape(complete.blocks));
    expect(
      streamed.entries.every(
        (entry) => entry.commitment == BlockCommitment.committed,
      ),
      isTrue,
    );
    expect(session.committedSourceLength, source.length);
  });

  test('append parse cost is independent of a large committed prefix', () {
    final session = parser.startSession();
    final prefix = StringBuffer();
    for (var index = 0; index < 5000; index++) {
      prefix.writeln('Paragraph $index.');
      prefix.writeln();
    }
    session.append(prefix.toString());

    session.append('new tail');

    expect(session.lastParsedSourceLength, 'new tail'.length);
    expect(session.provisionalSourceLength, 'new tail'.length);
    expect(session.content.blocks, hasLength(5001));
  });

  test('a finished generation fences late chunks', () {
    final session = parser.startSession();
    session
      ..append('Done.')
      ..finish();

    expect(() => session.append(' Too late.'), throwsStateError);
  });
}

Iterable<String> _chunks(String source, int width) sync* {
  for (var start = 0; start < source.length; start += width) {
    final end = (start + width).clamp(0, source.length);
    yield source.substring(start, end);
  }
}

List<Object> _shape(List<Block> blocks) => [
  for (final block in blocks) _blockShape(block),
];

Object _blockShape(Block block) => switch (block) {
  ParagraphBlock(:final content) => ['paragraph', _inlineShape(content)],
  HeadingBlock(:final level, :final anchor) => [
    'heading',
    level,
    anchor,
    block.text,
  ],
  CodeBlock(:final language) => ['code', language, block.text],
  QuoteBlock(:final blocks) => ['quote', _shape(blocks)],
  ListBlock(:final ordered, :final start, :final loose, :final items) => [
    'list',
    ordered,
    start,
    loose,
    [for (final item in items) _shape(item.blocks)],
  ],
  FootnoteSectionBlock(:final definitions) => [
    'footnotes',
    for (final definition in definitions)
      [definition.number, definition.anchor, _shape(definition.blocks)],
  ],
  _ => [block.runtimeType.toString(), block.text],
};

List<Object> _inlineShape(List<Inline> content) {
  final result = <Object>[];
  for (final inline in content) {
    if (inline case TextRun(:final text)) {
      if (result.lastOrNull case ['text', String previous]) {
        result[result.length - 1] = ['text', '$previous$text'];
      } else {
        result.add(['text', text]);
      }
      continue;
    }
    result.add(switch (inline) {
      CodeRun(:final text) => ['code', text],
      LineBreakRun() => ['break'],
      MarkedRun(:final mark, :final children) => [
        'mark',
        mark.name,
        _inlineShape(children),
      ],
      LinkRun(:final href, :final title, :final children) => [
        'link',
        href,
        title,
        _inlineShape(children),
      ],
      MathRun(:final source) => ['math', source],
      FootnoteReferenceRun(:final text) => ['footnote-reference', text],
      FootnoteBackReferenceRun(:final text) => ['footnote-backref', text],
      ImageRun(:final source, :final title, :final alt) => [
        'image',
        source,
        title,
        alt,
      ],
      TextRun() => throw StateError('Text was handled above.'),
    });
  }
  return result;
}
