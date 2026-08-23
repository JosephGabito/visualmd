/// Opaque reference to a workspace file selected through the platform.
final class WorkspaceFileRef {
  final String id;
  final String name;

  /// False when writing means an explicit download rather than silent replace.
  final bool supportsAutomaticWrites;

  const WorkspaceFileRef({
    required this.id,
    required this.name,
    this.supportsAutomaticWrites = true,
  });

  @override
  bool operator ==(Object other) => other is WorkspaceFileRef && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Port: selects and reads/writes user-owned workspace documents.
abstract interface class WorkspaceFiles {
  Future<WorkspaceFileRef?> pickOpen();

  Future<WorkspaceFileRef?> pickSave({required String suggestedName});

  Future<String> read(WorkspaceFileRef file);

  Future<void> write(WorkspaceFileRef file, String contents);
}

String workspaceFileName(String name) {
  const suffix = '.visualmd-workspace.json';
  if (name.toLowerCase().endsWith(suffix)) return name;
  final stem = name.toLowerCase().endsWith('.json')
      ? name.substring(0, name.length - '.json'.length)
      : name;
  return '$stem$suffix';
}
