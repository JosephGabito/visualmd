import '../../application/ports/library_repository.dart';
import '../../domain/library/library.dart';
import 'in_memory_reader_state.dart';

/// Adapter: the open library lives for the session, in memory.
final class InMemoryLibraryRepository implements LibraryRepository {
  final InMemoryReaderState _state;

  InMemoryLibraryRepository([InMemoryReaderState? state])
    : _state = state ?? InMemoryReaderState();

  @override
  Future<Library?> current() async => _state.library;

  @override
  Future<void> save(Library library) async => _state.library = library;
}
