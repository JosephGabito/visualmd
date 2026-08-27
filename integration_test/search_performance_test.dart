import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:visualmd/application/document_source_reader.dart';
import 'package:visualmd/application/ports/document_parser.dart';
import 'package:visualmd/application/ports/folder_document_scanner.dart';
import 'package:visualmd/application/ports/folder_scanner.dart';
import 'package:visualmd/application/ports/library_repository.dart';
import 'package:visualmd/application/ports/markdown_scanner.dart';
import 'package:visualmd/application/use_cases/search_documents.dart';
import 'package:visualmd/domain/library/library.dart';
import 'package:visualmd/domain/library/library_builder.dart';
import 'package:visualmd/domain/library/library_root_id.dart';
import 'package:visualmd/domain/reading/content/document_content.dart';
import 'package:visualmd/infrastructure/markdown/markdown_document_parser.dart';
import 'package:visualmd/infrastructure/search/literal_document_search.dart';

/// Measures the cost of refining a literal search across an unchanged library.
///
/// Search is not a rendering concern, but it competes with streaming for the
/// same frame budget. The fixture keeps source delivery deterministic while
/// exercising the production use case, Markdown parser, and visible-text
/// search adapter. Reads and parses expose hidden repeated work directly.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('query refinement exposes its library-size slope', (
    tester,
  ) async {
    final runs = <Map<String, Object?>>[];

    for (final documentCount in const [100, 1000, 5000]) {
      const rootId = LibraryRootId('search-benchmark');
      final library = Library(
        roots: [
          LibraryBuilder.buildRoot(
            id: rootId,
            name: 'Search benchmark',
            files: [
              for (var index = 0; index < documentCount; index++)
                FileEntry('document-$index.md', null, title: 'Document $index'),
            ],
          ),
        ],
      );
      final sources = _GeneratedFolderSources();
      final parser = _CountingParser();
      final search = SearchDocuments(
        repository: _Repository(library),
        search: LiteralDocumentSearch(parser: parser),
        sources: DocumentSourceReader(
          folderDocuments: sources,
          markdowns: const _NoMarkdowns(),
        ),
      );

      final queries = <Map<String, Object?>>[];
      for (final query in const ['needle', 'needle 7', 'needle 77']) {
        final beforeReads = sources.reads;
        final beforeParses = parser.parses;
        final clock = Stopwatch()..start();
        final results = await search.execute(query);
        clock.stop();
        queries.add({
          'query': query,
          'elapsed_us': clock.elapsedMicroseconds,
          'source_reads': sources.reads - beforeReads,
          'parses': parser.parses - beforeParses,
          'results': results.length,
        });
      }

      runs.add({
        'documents': documentCount,
        'source_characters_per_document': sources.sourceLength,
        'queries': queries,
      });
    }

    binding.reportData = {
      'benchmark': 'library_search_refinement_scaling',
      'mode': 'profile',
      'runs': runs,
    };
  });
}

final class _Repository implements LibraryRepository {
  final Library library;

  const _Repository(this.library);

  @override
  Future<Library?> current() async => library;

  @override
  Future<void> save(Library library) async {}
}

final class _GeneratedFolderSources implements FolderDocumentScanner {
  static final String _padding = List.filled(
    18,
    'Quiet readers keep stable source projections between query refinements.',
  ).join(' ');

  var reads = 0;

  String sourceFor(String path) =>
      '# $path\n\nneedle ${path.replaceAll(RegExp(r'\D'), '')}\n\n$_padding';

  int get sourceLength => sourceFor('document-0000.md').length;

  @override
  Future<ScannedFolderDocument?> scanDocument(
    FolderRef folder,
    String relativePath,
  ) async {
    reads++;
    return ScannedFolderDocument(
      relativePath: relativePath,
      content: sourceFor(relativePath),
      sourceId: null,
    );
  }
}

final class _CountingParser implements DocumentParser {
  static const _delegate = MarkdownDocumentParser();

  var parses = 0;

  @override
  DocumentContent parse(String markdown) {
    parses++;
    return _delegate.parse(markdown);
  }
}

final class _NoMarkdowns implements MarkdownScanner {
  const _NoMarkdowns();

  @override
  Future<ScannedMarkdown> scan(MarkdownRef ref) =>
      throw MarkdownUnavailable(ref);
}
