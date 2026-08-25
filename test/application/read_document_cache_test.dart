import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/application/document_source_reader.dart';
import 'package:visualmd/application/ports/document_parser.dart';
import 'package:visualmd/application/ports/folder_document_scanner.dart';
import 'package:visualmd/application/ports/folder_scanner.dart';
import 'package:visualmd/application/ports/library_repository.dart';
import 'package:visualmd/application/ports/markdown_scanner.dart';
import 'package:visualmd/application/use_cases/read_document.dart';
import 'package:visualmd/application/use_cases/search_documents.dart';
import 'package:visualmd/domain/library/document_id.dart';
import 'package:visualmd/domain/library/library.dart';
import 'package:visualmd/domain/library/library_builder.dart';
import 'package:visualmd/domain/library/library_root_id.dart';
import 'package:visualmd/domain/reading/content/document_content.dart';
import 'package:visualmd/infrastructure/markdown/markdown_document_parser.dart';
import 'package:visualmd/infrastructure/search/literal_document_search.dart';

void main() {
  const rootId = LibraryRootId('notes');

  Library library(int count) => Library(
    roots: [
      LibraryBuilder.buildRoot(
        id: rootId,
        name: 'Notes',
        files: [
          for (var index = 0; index < count; index++)
            FileEntry('document-$index.md', null),
        ],
      ),
    ],
  );

  DocumentId id(int index) => DocumentId(rootId, 'document-$index.md');

  test('a cached reading avoids both source IO and parsing', () async {
    final fixture = _Fixture(library(1));

    final first = await fixture.reader.execute(id(0));
    final second = await fixture.reader.execute(id(0));

    expect(second, same(first));
    expect(fixture.sources.calls[id(0).path], 1);
    expect(fixture.parser.calls, 1);
  });

  test(
    'recent use promotes a reading before the eleventh entry evicts',
    () async {
      final fixture = _Fixture(library(11));

      for (var index = 0; index < 10; index++) {
        await fixture.reader.execute(id(index));
      }
      await fixture.reader.execute(id(0));
      await fixture.reader.execute(id(10));
      await fixture.reader.execute(id(1));

      expect(fixture.sources.calls[id(0).path], 1);
      expect(fixture.sources.calls[id(1).path], 2);
      expect(fixture.sources.calls[id(10).path], 1);
      expect(fixture.parser.calls, 12);
    },
  );

  test('source invalidation evicts an otherwise reusable reading', () async {
    final fixture = _Fixture(library(1));
    await fixture.reader.execute(id(0));
    fixture.sources.contents[id(0).path] = '# Changed';

    fixture.reader.invalidate([id(0)]);
    final changed = await fixture.reader.execute(id(0));

    expect(changed.outline.title, 'Changed');
    expect(fixture.sources.calls[id(0).path], 2);
  });

  test(
    'retaining a smaller library releases readings it no longer owns',
    () async {
      final fixture = _Fixture(library(2));
      await fixture.reader.execute(id(0));
      await fixture.reader.execute(id(1));

      fixture.reader.retain([id(1)]);
      await fixture.reader.execute(id(0));
      await fixture.reader.execute(id(1));

      expect(fixture.sources.calls[id(0).path], 2);
      expect(fixture.sources.calls[id(1).path], 1);
    },
  );

  test('concurrent opens share one source read and one parse', () async {
    final repository = _Repository(library(1));
    final sources = _BlockingSources();
    final parser = _CountingParser();
    final reader = ReadDocument(
      repository: repository,
      parser: parser,
      sources: DocumentSourceReader(
        folderDocuments: sources,
        markdowns: const _NoMarkdowns(),
      ),
    );

    final first = reader.execute(id(0));
    await sources.started.future;
    final second = reader.execute(id(0));
    sources.release.complete();

    expect(await second, same(await first));
    expect(sources.calls, 1);
    expect(parser.calls, 1);
  });

  test(
    'an invalidated in-flight read cannot repopulate stale source',
    () async {
      final repository = _Repository(library(1));
      final sources = _InvalidatedSources();
      final reader = ReadDocument(
        repository: repository,
        parser: const MarkdownDocumentParser(),
        sources: DocumentSourceReader(
          folderDocuments: sources,
          markdowns: const _NoMarkdowns(),
        ),
      );

      final stale = reader.execute(id(0));
      await sources.started.future;
      reader.invalidate([id(0)]);
      final current = await reader.execute(id(0));
      sources.release.complete();
      await stale;
      final reopened = await reader.execute(id(0));

      expect(current.outline.title, 'Current');
      expect(reopened.outline.title, 'Current');
      expect(sources.calls, 2);
    },
  );

  test(
    'whole-library search streams sources without warming the reading cache',
    () async {
      final open = library(3);
      final fixture = _Fixture(open);
      final search = SearchDocuments(
        repository: fixture.repository,
        search: LiteralDocumentSearch(parser: fixture.parser),
        sources: fixture.sourceReader,
      );

      final results = await search.execute('document');
      await fixture.reader.execute(id(0));
      await fixture.reader.execute(id(0));

      expect(results, hasLength(3));
      expect(
        results.every((result) => result.document.loadedContent == null),
        isTrue,
      );
      expect(fixture.sources.calls[id(0).path], 2);
    },
  );
}

final class _Fixture {
  final _Repository repository;
  final _FolderSources sources;
  final _CountingParser parser;
  late final DocumentSourceReader sourceReader;
  late final ReadDocument reader;

  _Fixture(Library library)
    : repository = _Repository(library),
      sources = _FolderSources({
        for (final document in library.documents)
          document.id.path: '# ${document.id.fileName} document',
      }),
      parser = _CountingParser() {
    sourceReader = DocumentSourceReader(
      folderDocuments: sources,
      markdowns: const _NoMarkdowns(),
    );
    reader = ReadDocument(
      repository: repository,
      parser: parser,
      sources: sourceReader,
    );
  }
}

final class _Repository implements LibraryRepository {
  final Library library;

  const _Repository(this.library);

  @override
  Future<Library?> current() async => library;

  @override
  Future<void> save(Library library) async {}
}

final class _FolderSources implements FolderDocumentScanner {
  final Map<String, String> contents;
  final Map<String, int> calls = {};

  _FolderSources(this.contents);

  @override
  Future<ScannedFolderDocument?> scanDocument(
    FolderRef folder,
    String relativePath,
  ) async {
    calls[relativePath] = (calls[relativePath] ?? 0) + 1;
    final content = contents[relativePath];
    return content == null
        ? null
        : ScannedFolderDocument(
            relativePath: relativePath,
            content: content,
            sourceId: null,
          );
  }
}

final class _BlockingSources implements FolderDocumentScanner {
  final started = Completer<void>();
  final release = Completer<void>();
  var calls = 0;

  @override
  Future<ScannedFolderDocument?> scanDocument(
    FolderRef folder,
    String relativePath,
  ) async {
    calls++;
    started.complete();
    await release.future;
    return ScannedFolderDocument(
      relativePath: relativePath,
      content: '# Shared',
      sourceId: null,
    );
  }
}

final class _InvalidatedSources implements FolderDocumentScanner {
  final started = Completer<void>();
  final release = Completer<void>();
  var calls = 0;

  @override
  Future<ScannedFolderDocument?> scanDocument(
    FolderRef folder,
    String relativePath,
  ) async {
    calls++;
    if (calls == 1) {
      started.complete();
      await release.future;
      return ScannedFolderDocument(
        relativePath: relativePath,
        content: '# Stale',
        sourceId: null,
      );
    }
    return ScannedFolderDocument(
      relativePath: relativePath,
      content: '# Current',
      sourceId: null,
    );
  }
}

final class _CountingParser implements DocumentParser {
  var calls = 0;
  final MarkdownDocumentParser _delegate = const MarkdownDocumentParser();

  @override
  DocumentContent parse(String markdown) {
    calls++;
    return _delegate.parse(markdown);
  }
}

final class _NoMarkdowns implements MarkdownScanner {
  const _NoMarkdowns();

  @override
  Future<ScannedMarkdown> scan(MarkdownRef ref) =>
      throw MarkdownUnavailable(ref);
}
