/// Stable identity of a workspace, independent of its file name or location.
final class WorkspaceId {
  final String value;

  const WorkspaceId(this.value) : assert(value != '');

  @override
  bool operator ==(Object other) =>
      other is WorkspaceId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Stable identity of one source inside a workspace.
final class WorkspaceSourceId {
  final String value;

  const WorkspaceSourceId(this.value) : assert(value != '');

  @override
  bool operator ==(Object other) =>
      other is WorkspaceSourceId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
