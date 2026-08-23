import 'workspace_id.dart';

/// One folder or standalone Markdown addressable beneath a document root.
final class WorkspaceSource {
  final WorkspaceSourceId id;
  final String displayName;
  final String relativePath;

  WorkspaceSource({
    required this.id,
    required this.displayName,
    required String relativePath,
  }) : relativePath = normalizeWorkspacePath(relativePath) {
    if (displayName.trim().isEmpty) {
      throw ArgumentError.value(
        displayName,
        'displayName',
        'must not be empty',
      );
    }
  }

  WorkspaceSource copyWith({String? displayName, String? relativePath}) =>
      WorkspaceSource(
        id: id,
        displayName: displayName ?? this.displayName,
        relativePath: relativePath ?? this.relativePath,
      );

  @override
  bool operator ==(Object other) =>
      other is WorkspaceSource &&
      other.id == id &&
      other.displayName == displayName &&
      other.relativePath == relativePath;

  @override
  int get hashCode => Object.hash(id, displayName, relativePath);
}

/// A serialized path is portable syntax and cannot leave its declared root.
String normalizeWorkspacePath(String raw) {
  if (raw == '.') return raw;
  if (raw.isEmpty || raw.startsWith('/') || raw.contains(r'\')) {
    throw ArgumentError.value(raw, 'relativePath', 'must be relative');
  }
  final segments = raw.split('/');
  if (segments.any(
    (segment) => segment.isEmpty || segment == '.' || segment == '..',
  )) {
    throw ArgumentError.value(
      raw,
      'relativePath',
      'must not be empty, ambiguous, or escape its root',
    );
  }
  return segments.join('/');
}
