/// Serialises mutations of the session library in the order the user made
/// them. Folder scans are asynchronous; without this boundary a slow first
/// drop could overwrite a faster second drop after it completes.
final class LibraryMutationQueue {
  Future<void> _tail = Future.value();

  Future<T> run<T>(Future<T> Function() mutation) {
    final operation = _tail.then((_) => mutation());
    _tail = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }
}
