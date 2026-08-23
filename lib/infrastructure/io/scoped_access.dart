import 'dart:typed_data';

/// How the platform lets us read outside our sandbox for a moment.
/// macOS needs security-scoped bookmarks; everything else just reads.
abstract interface class ScopedAccess {
  Future<T> within<T>(Uint8List? bookmark, Future<T> Function() body);
}

final class OpenAccess implements ScopedAccess {
  const OpenAccess();

  @override
  Future<T> within<T>(Uint8List? bookmark, Future<T> Function() body) => body();
}
