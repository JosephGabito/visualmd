/// Stable identity of one top-level folder in a reading session.
///
/// The value is opaque to the domain. An adapter may derive it from a local
/// path or issue it for a browser handle; the domain only needs equality.
final class LibraryRootId {
  final String value;

  const LibraryRootId(this.value) : assert(value != '');

  @override
  bool operator ==(Object other) =>
      other is LibraryRootId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
