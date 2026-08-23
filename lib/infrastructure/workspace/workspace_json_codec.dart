import 'dart:convert';

import '../../domain/workspace/workspace.dart';
import '../../domain/workspace/workspace_id.dart';
import '../../domain/workspace/workspace_source.dart';
import '../../domain/workspace/workspace_theme.dart';
import '../../application/ports/workspace_codec.dart';

/// Converts the public Visual MD workspace format without reading any files.
final class WorkspaceJsonCodec implements WorkspaceCodec {
  const WorkspaceJsonCodec();

  @override
  Workspace decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw WorkspaceFormatException('Invalid JSON: ${error.message}');
    }
    if (decoded is! Map<String, Object?>) {
      throw const WorkspaceFormatException('The workspace must be an object.');
    }
    _onlyKeys(decoded, const {
      'format',
      'version',
      'workspaceId',
      'documentRootAbsolutePath',
      'theme',
      'library',
      'activeDocument',
    }, 'workspace');
    if (decoded['format'] != 'visualmd-workspace') {
      throw const WorkspaceFormatException(
        'The file is not a Visual MD workspace.',
      );
    }
    if (decoded['version'] != 1) {
      throw WorkspaceFormatException(
        'Workspace version ${decoded['version']} is not supported.',
      );
    }

    final library = _map(decoded['library'], 'library');
    _onlyKeys(library, const {'markdowns', 'folders'}, 'library');
    try {
      return Workspace(
        id: WorkspaceId(_string(decoded['workspaceId'], 'workspaceId')),
        documentRootAbsolutePath: _nullableString(
          decoded['documentRootAbsolutePath'],
          'documentRootAbsolutePath',
        ),
        theme: _theme(decoded['theme']),
        markdowns: _sources(library['markdowns'], 'library.markdowns'),
        folders: _sources(library['folders'], 'library.folders'),
        activeDocument: _activeDocument(decoded['activeDocument']),
      );
    } on ArgumentError catch (error) {
      throw WorkspaceFormatException(error.message?.toString() ?? '$error');
    }
  }

  @override
  String encode(Workspace workspace) =>
      '${const JsonEncoder.withIndent('  ').convert(_document(workspace))}\n';

  Map<String, Object?> _document(Workspace workspace) => {
    'format': 'visualmd-workspace',
    'version': 1,
    'workspaceId': workspace.id.value,
    'documentRootAbsolutePath': workspace.documentRootAbsolutePath,
    'theme': _encodeTheme(workspace.theme),
    'library': {
      'markdowns': workspace.markdowns.map(_encodeSource).toList(),
      'folders': workspace.folders.map(_encodeSource).toList(),
    },
    'activeDocument': switch (workspace.activeDocument) {
      null => null,
      final active => {
        'sourceId': active.sourceId.value,
        'relativePath': active.relativePath,
      },
    },
  };

  WorkspaceTheme _theme(Object? value) {
    final map = _map(value, 'theme');
    return switch (map['mode']) {
      'fixed' => () {
        _onlyKeys(map, const {'mode', 'theme'}, 'theme');
        return FixedWorkspaceTheme(_string(map['theme'], 'theme.theme'));
      }(),
      'system' => () {
        _onlyKeys(map, const {'mode', 'light', 'dark'}, 'theme');
        return SystemWorkspaceTheme(
          lightThemeId: _string(map['light'], 'theme.light'),
          darkThemeId: _string(map['dark'], 'theme.dark'),
        );
      }(),
      _ => throw const WorkspaceFormatException(
        'theme.mode must be "fixed" or "system".',
      ),
    };
  }

  Map<String, Object?> _encodeTheme(WorkspaceTheme theme) => switch (theme) {
    FixedWorkspaceTheme(:final themeId) => {'mode': 'fixed', 'theme': themeId},
    SystemWorkspaceTheme(:final lightThemeId, :final darkThemeId) => {
      'mode': 'system',
      'light': lightThemeId,
      'dark': darkThemeId,
    },
  };

  List<WorkspaceSource> _sources(Object? value, String field) {
    if (value is! List<Object?>) {
      throw WorkspaceFormatException('$field must be an array.');
    }
    return [
      for (var index = 0; index < value.length; index++)
        _source(value[index], '$field[$index]'),
    ];
  }

  WorkspaceSource _source(Object? value, String field) {
    final map = _map(value, field);
    _onlyKeys(map, const {'id', 'displayName', 'relativePath'}, field);
    return WorkspaceSource(
      id: WorkspaceSourceId(_string(map['id'], '$field.id')),
      displayName: _string(map['displayName'], '$field.displayName'),
      relativePath: _string(map['relativePath'], '$field.relativePath'),
    );
  }

  Map<String, Object?> _encodeSource(WorkspaceSource source) => {
    'id': source.id.value,
    'displayName': source.displayName,
    'relativePath': source.relativePath,
  };

  WorkspaceDocument? _activeDocument(Object? value) {
    if (value == null) return null;
    final map = _map(value, 'activeDocument');
    _onlyKeys(map, const {'sourceId', 'relativePath'}, 'activeDocument');
    return WorkspaceDocument(
      sourceId: WorkspaceSourceId(
        _string(map['sourceId'], 'activeDocument.sourceId'),
      ),
      relativePath: _string(map['relativePath'], 'activeDocument.relativePath'),
    );
  }

  Map<String, Object?> _map(Object? value, String field) {
    if (value is Map<String, Object?>) return value;
    throw WorkspaceFormatException('$field must be an object.');
  }

  String _string(Object? value, String field) {
    if (value is String && value.isNotEmpty) return value;
    throw WorkspaceFormatException('$field must be a non-empty string.');
  }

  String? _nullableString(Object? value, String field) {
    if (value == null) return null;
    return _string(value, field);
  }

  void _onlyKeys(
    Map<String, Object?> value,
    Set<String> allowed,
    String field,
  ) {
    for (final key in value.keys) {
      if (!allowed.contains(key)) {
        throw WorkspaceFormatException('$field contains unknown field "$key".');
      }
    }
  }
}

final class WorkspaceFormatException implements Exception {
  final String message;

  const WorkspaceFormatException(this.message);

  @override
  String toString() => message;
}
