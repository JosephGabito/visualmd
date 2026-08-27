import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/application/ports/document_parser.dart';
import 'package:visualmd/domain/library/document.dart';
import 'package:visualmd/domain/library/document_id.dart';
import 'package:visualmd/domain/library/library_root_id.dart';
import 'package:visualmd/domain/reading/content/document_content.dart';
import 'package:visualmd/domain/search/search_result.dart';
import 'package:visualmd/infrastructure/markdown/markdown_document_parser.dart';
import 'package:visualmd/infrastructure/search/literal_document_search.dart';

void main() {
  const rootId = LibraryRootId('test');
  late LiteralDocumentSearch search;

  setUp(() {
    search = LiteralDocumentSearch(parser: const MarkdownDocumentParser());
  });

  test(
    'finds every literal without treating punctuation as an expression',
    () async {
      final document = Document(
        id: DocumentId(rootId, 'guide.md'),
        content: '# Dart\n\nDart has `RegExp`, but a.b remains literal: a.b.',
      );

      final results = await search.find(SearchQuery('a.b'), [document]);

      expect(results, hasLength(1));
      expect(results.single.matches, hasLength(2));
      expect(
        results.single.matches.map((match) => match.excerpt),
        everyElement(contains('a.b')),
      );
    },
  );

  test('matches case-insensitively against words the reader sees', () async {
    final document = Document(
      id: DocumentId(rootId, 'guide.md'),
      content: '# Search\n\nFind **Needle** without exposing the marks.',
    );

    final results = await search.find(SearchQuery('needle'), [document]);

    expect(results.single.matches.single.start, greaterThan(0));
    expect(results.single.matches.single.excerpt, contains('Needle'));
    expect(results.single.matches.single.excerpt, isNot(contains('**')));
  });

  test('indexes emphasized words without either delimiter spelling', () async {
    final document = Document(
      id: DocumentId(rootId, 'emphasis.md'),
      content: 'Find *Needle* beside _thread_.',
    );

    final needle = await search.find(SearchQuery('needle'), [document]);
    final thread = await search.find(SearchQuery('thread'), [document]);
    final notation = await search.find(SearchQuery('*Needle*'), [document]);

    expect(needle.single.matches.single.excerpt, 'Find Needle beside thread.');
    expect(thread.single.matches.single.excerpt, 'Find Needle beside thread.');
    expect(notation, isEmpty);
  });

  test(
    'indexes strongly marked words without either delimiter spelling',
    () async {
      final document = Document(
        id: DocumentId(rootId, 'strength.md'),
        content: 'Find **Critical** beside __warning__.',
      );

      final critical = await search.find(SearchQuery('critical'), [document]);
      final warning = await search.find(SearchQuery('warning'), [document]);
      final notation = await search.find(SearchQuery('__warning__'), [
        document,
      ]);

      expect(
        critical.single.matches.single.excerpt,
        'Find Critical beside warning.',
      );
      expect(
        warning.single.matches.single.excerpt,
        'Find Critical beside warning.',
      );
      expect(notation, isEmpty);
    },
  );

  test('indexes nested marks as one delimiter-free reading phrase', () async {
    final document = Document(
      id: DocumentId(rootId, 'nested-emphasis.md'),
      content:
          'Find ***Critical*** beside **important _context_** without marks.',
    );

    final critical = await search.find(SearchQuery('critical'), [document]);
    final phrase = await search.find(SearchQuery('important context'), [
      document,
    ]);
    final notation = await search.find(SearchQuery('***Critical***'), [
      document,
    ]);

    expect(
      critical.single.matches.single.excerpt,
      'Find Critical beside important context without marks.',
    );
    expect(
      phrase.single.matches.single.excerpt,
      'Find Critical beside important context without marks.',
    );
    expect(notation, isEmpty);
  });

  test(
    'indexes valid strikethrough but preserves ineligible tilde runs',
    () async {
      final document = Document(
        id: DocumentId(rootId, 'strikethrough.md'),
        content:
            'Find ~retired~ beside ~~obsolete~~ while ~~~literal~~~ survives.',
      );

      final retired = await search.find(SearchQuery('retired'), [document]);
      final obsolete = await search.find(SearchQuery('obsolete'), [document]);
      final literal = await search.find(SearchQuery('~~~literal~~~'), [
        document,
      ]);
      final notation = await search.find(SearchQuery('~retired~'), [document]);

      expect(
        retired.single.matches.single.excerpt,
        'Find retired beside obsolete while ~~~literal~~~ survives.',
      );
      expect(
        obsolete.single.matches.single.excerpt,
        'Find retired beside obsolete while ~~~literal~~~ survives.',
      );
      expect(literal.single.matches.single.excerpt, contains('~~~literal~~~'));
      expect(notation, isEmpty);
    },
  );

  test('indexes GitHub inline HTML by its visible words alone', () async {
    final document = Document(
      id: DocumentId(rootId, 'scientific-prose.md'),
      content:
          'Water is H<sub>2</sub>O, area is x<sup>2</sup>, and '
          '<ins>this wording is current</ins>.',
    );

    final results = await search.find(SearchQuery('this wording'), [document]);
    final notation = await search.find(SearchQuery('<ins>'), [document]);

    expect(
      results.single.matches.single.excerpt,
      'Water is H2O, area is x2, and this wording is current.',
    );
    expect(notation, isEmpty);
  });

  test(
    'indexes a link label but not its destination or advisory title',
    () async {
      final document = Document(
        id: DocumentId(rootId, 'links.md'),
        content: 'Read [the visible guide](/private/path "Advisory title").',
      );

      final visible = await search.find(SearchQuery('visible guide'), [
        document,
      ]);
      final destination = await search.find(SearchQuery('private/path'), [
        document,
      ]);
      final title = await search.find(SearchQuery('advisory title'), [
        document,
      ]);

      expect(visible.single.matches.single.excerpt, 'Read the visible guide.');
      expect(destination, isEmpty);
      expect(title, isEmpty);
    },
  );

  test(
    'indexes every reference form but not definitions or link metadata',
    () async {
      final document = Document(
        id: DocumentId(rootId, 'reference-links.md'),
        content: '''
[Full visible words][guide], [Collapsed visible words][], and
[Shortcut visible words].

[guide]: /private/full "Full advisory"
[Collapsed visible words]: /private/collapsed
[Shortcut visible words]: /private/shortcut
''',
      );

      for (final phrase in [
        'Full visible words',
        'Collapsed visible words',
        'Shortcut visible words',
      ]) {
        final results = await search.find(SearchQuery(phrase), [document]);
        expect(results.single.matches.single.excerpt, contains(phrase));
      }
      expect(
        await search.find(SearchQuery('private/full'), [document]),
        isEmpty,
      );
      expect(
        await search.find(SearchQuery('Full advisory'), [document]),
        isEmpty,
      );
    },
  );

  test('indexes the visible spelling of every autolink form', () async {
    final document = Document(
      id: DocumentId(rootId, 'autolinks.md'),
      content: '''
<https://example.com/angle> <angle@example.com>
https://example.com/bare www.example.com reader@example.com
''',
    );

    for (final visible in [
      'https://example.com/angle',
      'angle@example.com',
      'https://example.com/bare',
      'www.example.com',
      'reader@example.com',
    ]) {
      final results = await search.find(SearchQuery(visible), [document]);
      expect(results.single.matches.single.excerpt, contains(visible));
    }
    expect(await search.find(SearchQuery('mailto:'), [document]), isEmpty);
    expect(await search.find(SearchQuery('http://www'), [document]), isEmpty);
  });

  test('matches the reading text across editor wrapping', () async {
    final document = Document(
      id: DocumentId(rootId, 'wrapped.md'),
      content:
          'A searchable phrase is deliberately\n'
          'wrapped in the source, while 中文源代码\n'
          '继续 remains naturally unspaced.',
    );

    final latin = await search.find(SearchQuery('deliberately wrapped'), [
      document,
    ]);
    final cjk = await search.find(SearchQuery('中文源代码继续'), [document]);

    expect(latin.single.matches, hasLength(1));
    expect(
      latin.single.matches.single.excerpt,
      contains('deliberately wrapped'),
    );
    expect(cjk.single.matches, hasLength(1));
    expect(cjk.single.matches.single.excerpt, contains('中文源代码继续'));
  });

  test(
    'indexes authored lines as one newline without their source syntax',
    () async {
      final document = Document(
        id: DocumentId(rootId, 'address.md'),
        content: 'Visual MD Reading Room  \n     Metro Manila',
      );

      final results = await search.find(SearchQuery('Metro Manila'), [
        document,
      ]);
      final match = results.single.matches.single;

      expect(match.start, 'Visual MD Reading Room\n'.length);
      expect(match.excerpt, 'Visual MD Reading Room Metro Manila');
    },
  );

  test('indexes escaped punctuation without its source backslashes', () async {
    final document = Document(
      id: DocumentId(rootId, 'literal.md'),
      content: r'Escaped \*literal\* and \[brackets\] remain searchable.',
    );

    final stars = await search.find(SearchQuery('*literal*'), [document]);
    final brackets = await search.find(SearchQuery('[brackets]'), [document]);
    final sourceNotation = await search.find(SearchQuery(r'\*literal'), [
      document,
    ]);

    expect(stars.single.matches.single.start, 'Escaped '.length);
    expect(stars.single.matches.single.excerpt, contains('*literal*'));
    expect(brackets.single.matches.single.excerpt, contains('[brackets]'));
    expect(sourceNotation, isEmpty);
  });

  test(
    'indexes decoded characters instead of their source references',
    () async {
      final document = Document(
        id: DocumentId(rootId, 'references.md'),
        content: 'Named &copy; and numeric &#35; references are visible.',
      );

      final visible = await search.find(SearchQuery('© and numeric #'), [
        document,
      ]);
      final sourceNotation = await search.find(SearchQuery('&copy;'), [
        document,
      ]);

      expect(
        visible.single.matches.single.excerpt,
        contains('© and numeric #'),
      );
      expect(sourceNotation, isEmpty);
    },
  );

  test('keeps excerpts on complete grapheme boundaries', () async {
    const emoji = '👩🏽‍💻';
    final document = Document(
      id: DocumentId(rootId, 'unicode.md'),
      content:
          '${List.filled(10, 'a').join()}$emoji'
          '${List.filled(40, 'b').join()} needle after',
    );

    final results = await search.find(SearchQuery('needle'), [document]);
    final excerpt = results.single.matches.single.excerpt;

    expect(excerpt, startsWith('…$emoji'));
    expect(excerpt, isNot(contains('\u{fffd}')));
  });

  test('finds exact combining and emoji source without rewriting it', () async {
    const source = 'A nai\u0308ve 👩🏽‍💻 reader.';
    final document = Document(
      id: DocumentId(rootId, 'clusters.md'),
      content: source,
    );

    final decomposed = await search.find(SearchQuery('nai\u0308ve'), [
      document,
    ]);
    final emoji = await search.find(SearchQuery('👩🏽‍💻'), [document]);

    expect(decomposed.single.matches.single.excerpt, contains('nai\u0308ve'));
    expect(emoji.single.matches.single.excerpt, contains('👩🏽‍💻'));
  });

  test('omits documents without a match and preserves library order', () async {
    final documents = [
      Document(id: DocumentId(rootId, 'a.md'), content: 'first needle'),
      Document(id: DocumentId(rootId, 'b.md'), content: 'nothing'),
      Document(id: DocumentId(rootId, 'c.md'), content: 'last needle'),
    ];

    final results = await search.find(SearchQuery('needle'), documents);

    expect(results.map((result) => result.document.id.path), ['a.md', 'c.md']);
  });

  test('an unchanged document reuses its visible-text projection', () async {
    final parser = _CountingParser();
    final indexed = LiteralDocumentSearch(parser: parser);
    final id = DocumentId(rootId, 'retained.md');

    await indexed.find(SearchQuery('needle'), [
      Document(id: id, content: '**needle**'),
    ]);
    final refined = await indexed.find(SearchQuery('need'), [Document(id: id)]);

    expect(refined, hasLength(1));
    expect(parser.calls, 1);
    expect(indexed.contains(id), isTrue);
  });

  test('invalidating one document rebuilds only that projection', () async {
    final parser = _CountingParser();
    final indexed = LiteralDocumentSearch(parser: parser);
    final first = DocumentId(rootId, 'first.md');
    final second = DocumentId(rootId, 'second.md');

    await indexed.find(SearchQuery('old'), [
      Document(id: first, content: 'old first'),
      Document(id: second, content: 'old second'),
    ]);
    indexed.invalidate([first]);
    final results = await indexed.find(SearchQuery('current'), [
      Document(id: first, content: 'current first'),
      Document(id: second),
    ]);

    expect(results.single.document.id, first);
    expect(parser.calls, 3);
  });

  test('retained visible text never exceeds its byte budget', () async {
    final indexed = LiteralDocumentSearch(
      parser: const MarkdownDocumentParser(),
      maximumRetainedBytes: 100,
    );
    final first = DocumentId(rootId, 'first.md');
    final second = DocumentId(rootId, 'second.md');

    await indexed.find(SearchQuery('text'), [
      Document(id: first, content: 'first text'),
      Document(id: second, content: 'second text'),
    ]);

    expect(indexed.retainedBytes, lessThanOrEqualTo(100));
    expect(indexed.retainedCount, 1);
    expect(indexed.contains(first), isFalse);
    expect(indexed.contains(second), isTrue);
  });
}

final class _CountingParser implements DocumentParser {
  static const _delegate = MarkdownDocumentParser();

  var calls = 0;

  @override
  DocumentContent parse(String markdown) {
    calls++;
    return _delegate.parse(markdown);
  }
}
