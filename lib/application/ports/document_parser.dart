import '../../domain/reading/content/document_content.dart';

/// Port: turns markdown source into the blocks a reader meets.
///
/// Parsing markdown is a technical job with a large specification, so it is
/// done by an adapter; what a document *is* stays in the domain.
abstract interface class DocumentParser {
  DocumentContent parse(String markdown);
}

/// Port: opens one append-oriented parse generation.
///
/// A session keeps already committed blocks stable and replaces only the
/// suffix which later Markdown is still allowed to reinterpret. Transport,
/// batching, and scheduling remain separate application concerns.
abstract interface class IncrementalDocumentParser {
  IncrementalDocumentParserSession startSession();
}

abstract interface class IncrementalDocumentParserSession {
  DocumentContent get content;

  int get sourceLength;

  int get committedSourceLength;

  int get provisionalSourceLength;

  /// Source characters parsed to produce the most recent revision.
  int get lastParsedSourceLength;

  DocumentContent append(String source);

  DocumentContent finish();
}
