import 'workspace_id.dart';
import 'workspace_source.dart';
import 'workspace_theme.dart';

/// The durable reading room: its sources, appearance, and current document.
final class Workspace {
  final WorkspaceId id;

  /// Null only where the platform cannot expose filesystem paths (the web).
  final String? documentRootAbsolutePath;
  final WorkspaceTheme theme;
  final List<WorkspaceSource> markdowns;
  final List<WorkspaceSource> folders;
  final WorkspaceDocument? activeDocument;

  Workspace({
    required this.id,
    required String? documentRootAbsolutePath,
    required this.theme,
    Iterable<WorkspaceSource> markdowns = const [],
    Iterable<WorkspaceSource> folders = const [],
    this.activeDocument,
  }) : documentRootAbsolutePath = _absoluteRoot(documentRootAbsolutePath),
       markdowns = List.unmodifiable(markdowns),
       folders = List.unmodifiable(folders) {
    final sourceIds = [
      ...this.markdowns.map((source) => source.id),
      ...this.folders.map((source) => source.id),
    ];
    if (sourceIds.toSet().length != sourceIds.length) {
      throw ArgumentError('workspace source identities must be unique');
    }
    final active = activeDocument;
    if (active != null && !sourceIds.contains(active.sourceId)) {
      throw ArgumentError.value(
        active,
        'activeDocument',
        'must belong to a workspace source',
      );
    }
  }

  bool get isEmpty => markdowns.isEmpty && folders.isEmpty;

  Iterable<WorkspaceSource> get sources sync* {
    yield* markdowns;
    yield* folders;
  }

  WorkspaceSource? sourceById(WorkspaceSourceId id) {
    for (final source in sources) {
      if (source.id == id) return source;
    }
    return null;
  }

  Workspace copyWith({
    WorkspaceId? id,
    String? documentRootAbsolutePath,
    bool clearDocumentRoot = false,
    WorkspaceTheme? theme,
    Iterable<WorkspaceSource>? markdowns,
    Iterable<WorkspaceSource>? folders,
    WorkspaceDocument? activeDocument,
    bool clearActiveDocument = false,
  }) => Workspace(
    id: id ?? this.id,
    documentRootAbsolutePath: clearDocumentRoot
        ? null
        : documentRootAbsolutePath ?? this.documentRootAbsolutePath,
    theme: theme ?? this.theme,
    markdowns: markdowns ?? this.markdowns,
    folders: folders ?? this.folders,
    activeDocument: clearActiveDocument
        ? null
        : activeDocument ?? this.activeDocument,
  );
}

/// Stable workspace address of the document that should remain open.
final class WorkspaceDocument {
  final WorkspaceSourceId sourceId;
  final String relativePath;

  WorkspaceDocument({required this.sourceId, required String relativePath})
    : relativePath = normalizeWorkspacePath(relativePath);

  @override
  bool operator ==(Object other) =>
      other is WorkspaceDocument &&
      other.sourceId == sourceId &&
      other.relativePath == relativePath;

  @override
  int get hashCode => Object.hash(sourceId, relativePath);
}

String? _absoluteRoot(String? raw) {
  if (raw == null) return null;
  final portable = raw.replaceAll(r'\', '/');
  final normalized =
      portable == '/' || RegExp(r'^[A-Za-z]:/$').hasMatch(portable)
      ? portable
      : portable.replaceAll(RegExp(r'/+$'), '');
  final unix = normalized.startsWith('/');
  final windowsDrive = RegExp(r'^[A-Za-z]:/').hasMatch(normalized);
  final windowsShare = normalized.startsWith('//');
  if (!unix && !windowsDrive && !windowsShare) {
    throw ArgumentError.value(
      raw,
      'documentRootAbsolutePath',
      'must be absolute',
    );
  }
  return normalized.isEmpty ? '/' : normalized;
}
