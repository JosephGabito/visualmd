import '../../domain/library/library.dart';

/// Port: holds the library currently open in the reader.
abstract interface class LibraryRepository {
  Future<void> save(Library library);
  Future<Library?> current();
}
