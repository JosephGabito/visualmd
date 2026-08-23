// ignore_for_file: prefer_initializing_formals — private fields stay private; named params stay public.
import '../../domain/library/document.dart';
import '../../domain/library/document_id.dart';
import '../../domain/reading/document_outline.dart';
import '../../domain/reading/content/document_content.dart';
import '../ports/document_parser.dart';
import '../ports/library_repository.dart';

/// What the reader gets when opening a document: the document, the structure
/// to navigate it by, and the blocks to set on the page.
final class DocumentReading {
  final Document document;
  final DocumentOutline outline;
  final DocumentContent content;

  const DocumentReading({
    required this.document,
    required this.outline,
    required this.content,
  });
}

final class NoLibraryOpen implements Exception {
  const NoLibraryOpen();

  @override
  String toString() => 'NoLibraryOpen';
}

final class DocumentNotFound implements Exception {
  final DocumentId id;
  const DocumentNotFound(this.id);

  @override
  String toString() => 'DocumentNotFound: $id';
}

/// Use case: read a document from the current library.
final class ReadDocument {
  final LibraryRepository _repository;
  final DocumentParser _parser;

  const ReadDocument({
    required LibraryRepository repository,
    required DocumentParser parser,
  }) : _repository = repository,
       _parser = parser;

  Future<DocumentReading> execute(DocumentId id) async {
    final library = await _repository.current();
    if (library == null) throw const NoLibraryOpen();
    final document = library.find(id);
    if (document == null) throw DocumentNotFound(id);
    return DocumentReading(
      document: document,
      outline: document.outline,
      content: _parser.parse(document.content),
    );
  }
}
