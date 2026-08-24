import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/domain/library/document.dart';
import 'package:visualmd/domain/library/document_id.dart';
import 'package:visualmd/domain/library/library_root_id.dart';
import 'package:visualmd/domain/search/search_result.dart';
import 'package:visualmd/infrastructure/markdown/markdown_document_parser.dart';
import 'package:visualmd/infrastructure/search/literal_document_search.dart';

void main() {
  const rootId = LibraryRootId('test');
  final search = LiteralDocumentSearch(parser: const MarkdownDocumentParser());

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

  test('omits documents without a match and preserves library order', () async {
    final documents = [
      Document(id: DocumentId(rootId, 'a.md'), content: 'first needle'),
      Document(id: DocumentId(rootId, 'b.md'), content: 'nothing'),
      Document(id: DocumentId(rootId, 'c.md'), content: 'last needle'),
    ];

    final results = await search.find(SearchQuery('needle'), documents);

    expect(results.map((result) => result.document.id.path), ['a.md', 'c.md']);
  });
}
