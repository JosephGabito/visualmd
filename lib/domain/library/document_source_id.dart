/// Opaque identity of one physical markdown source.
///
/// Infrastructure may derive the value from a local path or another platform
/// handle. The domain knows only equality, which is enough to prevent one file
/// appearing both as a standalone markdown and inside a folder root.
final class DocumentSourceId {
  final String value;

  const DocumentSourceId(this.value) : assert(value != '');

  @override
  bool operator ==(Object other) =>
      other is DocumentSourceId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
