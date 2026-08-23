import '../../domain/reading/content/document_content.dart';

/// Port: turns markdown source into the blocks a reader meets.
///
/// Parsing markdown is a technical job with a large specification, so it is
/// done by an adapter; what a document *is* stays in the domain.
abstract interface class DocumentParser {
  DocumentContent parse(String markdown);
}
