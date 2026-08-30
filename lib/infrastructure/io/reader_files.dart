// ignore_for_file: prefer_initializing_formals — the public parameter hides the private field.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'desktop_atomic_files.dart';

/// Adapter: the reader's own preferences, themes, recovery journal location,
/// and machine-local source authority under application support
/// (`~/Library/Application Support/Visual MD` on macOS).
final class ReaderFiles {
  final Directory root;
  final DesktopAtomicFiles _atomic;

  const ReaderFiles(
    this.root, {
    DesktopAtomicFiles atomic = const DesktopAtomicFiles(),
  }) : _atomic = atomic;

  static Future<ReaderFiles> locate() async {
    final support = await getApplicationSupportDirectory();
    final root = rootFor(
      support,
      uiTestProfile: Platform.environment[uiTestProfileEnvironment],
      uiTestBase: Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}Visual MD UI Tests',
      ),
    );
    await root.create(recursive: true);
    final files = ReaderFiles(root);
    if (Platform.environment[uiTestMalformedSessionEnvironment] == '1') {
      await files.sessionJournal.writeAsString('{ malformed ui-test recovery');
    }
    if (!await files.themesDirectory.exists()) {
      await files.themesDirectory.create(recursive: true);
      // A first-time note so the folder explains itself. Only `.json` files
      // are read as themes, so this one is documentation, not a theme.
      await File(
        '${files.themesDirectory.path}${Platform.pathSeparator}README.md',
      ).writeAsString(themesReadme);
    }
    return files;
  }

  /// Keeps UI automation out of a reader's real preferences and recovery
  /// journal while exercising the same on-disk adapters as the shipped app.
  ///
  /// A profile is a name, never a path. Refusing separators and punctuation
  /// prevents a malformed test launch from escaping the dedicated directory.
  static Directory rootFor(
    Directory support, {
    String? uiTestProfile,
    Directory? uiTestBase,
  }) {
    final ordinary = Directory(
      '${support.path}${Platform.pathSeparator}Visual MD',
    );
    if (uiTestProfile == null) return ordinary;
    if (!RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(uiTestProfile)) {
      throw ArgumentError.value(
        uiTestProfile,
        uiTestProfileEnvironment,
        'must contain only letters, digits, underscores, or hyphens',
      );
    }
    return Directory(
      '${(uiTestBase ?? Directory('${ordinary.path}${Platform.pathSeparator}UI Tests')).path}'
      '${Platform.pathSeparator}$uiTestProfile',
    );
  }

  Directory get themesDirectory =>
      Directory('${root.path}${Platform.pathSeparator}themes');

  File get _preferences =>
      File('${root.path}${Platform.pathSeparator}preferences.json');

  /// Private reading-room recovery, separate from preferences and public
  /// workspace files selected by the reader.
  File get sessionJournal =>
      File('${root.path}${Platform.pathSeparator}session.json');

  Future<Map<String, Object?>> _readPreferences() async {
    if (!await _preferences.exists()) return {};
    try {
      final decoded = jsonDecode(await _preferences.readAsString());
      return decoded is Map<String, Object?> ? decoded : {};
    } on FormatException {
      return {};
    }
  }

  Future<String?> readPreference(String key) async {
    final value = (await _readPreferences())[key];
    return value is String ? value : null;
  }

  Future<void> writePreference(String key, String value) async {
    final all = await _readPreferences();
    all[key] = value;
    await _writeJson(_preferences, all);
  }

  File get _workspaceAccess =>
      File('${root.path}${Platform.pathSeparator}workspace-access.json');

  Future<Map<String, Object?>> _readWorkspaceAccess() async {
    if (!await _workspaceAccess.exists()) return {};
    try {
      final decoded = jsonDecode(await _workspaceAccess.readAsString());
      return decoded is Map<String, Object?> ? decoded : {};
    } on FormatException {
      return {};
    }
  }

  Future<({String path, Uint8List? bookmark})?> readWorkspaceAccess(
    String workspaceId,
    String sourceId,
  ) async {
    final value = (await _readWorkspaceAccess())['$workspaceId/$sourceId'];
    if (value is! Map<String, Object?> || value['path'] is! String) return null;
    final encoded = value['bookmark'];
    return (
      path: value['path']! as String,
      bookmark: encoded is String ? base64Decode(encoded) : null,
    );
  }

  Future<void> writeWorkspaceAccess(
    String workspaceId,
    String sourceId, {
    required String path,
    required Uint8List? bookmark,
  }) async {
    final all = await _readWorkspaceAccess();
    all['$workspaceId/$sourceId'] = {
      'path': path,
      'bookmark': bookmark == null ? null : base64Encode(bookmark),
    };
    await _writeJson(_workspaceAccess, all);
  }

  Future<void> forkWorkspaceAccess(
    String fromWorkspaceId,
    String toWorkspaceId,
    Iterable<String> sourceIds,
  ) async {
    final all = await _readWorkspaceAccess();
    for (final sourceId in sourceIds) {
      final stored = all['$fromWorkspaceId/$sourceId'];
      if (stored != null) all['$toWorkspaceId/$sourceId'] = stored;
    }
    await _writeJson(_workspaceAccess, all);
  }

  Future<void> _writeJson(File target, Map<String, Object?> value) async {
    final temporary = File('${target.path}.writing');
    await temporary.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(value)}\n',
      flush: true,
    );
    await _atomic.replace(
      target: target,
      temporary: temporary,
      backup: File('${target.path}.bak'),
    );
  }

  /// Every `*.json` in the themes directory, in name order.
  Future<List<({String origin, String json})>> readThemeDocuments() async {
    if (!await themesDirectory.exists()) return const [];
    final files =
        await themesDirectory
              .list(followLinks: false)
              .where((e) => e is File && e.path.toLowerCase().endsWith('.json'))
              .cast<File>()
              .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    return [
      for (final file in files)
        (
          origin: file.path.split(Platform.pathSeparator).last,
          json: await file.readAsString(),
        ),
    ];
  }
}

/// Launch environment understood only as a storage-isolation profile name.
const uiTestProfileEnvironment = 'VISUAL_MD_UI_TEST_PROFILE';

/// Requests a corrupt recovery journal inside an already isolated UI-test
/// profile. The profile requirement prevents ordinary launches from using it.
const uiTestMalformedSessionEnvironment = 'VISUAL_MD_UI_TEST_MALFORMED_SESSION';

/// Dropped into the themes folder the first time it is created.
const themesReadme = '''
# Visual MD themes

Every `.json` file in this folder is a theme. Add one, restart Visual MD, and
it appears in the theme menu. A file whose `id` matches a built-in replaces
that built-in — that is how you tweak one of the shipped themes.

```json
{
  "schema": 1,
  "id": "sepia",
  "name": "Sepia",
  "brightness": "light",
  "palette": {
    "paper": "#f4ecd8",
    "panel": "#ece3cc",
    "border": "#d8ccb0",
    "ink": "#3b2f2f",
    "muted": "#7a6a5a",
    "accent": "#8b4513",
    "codeBackground": "#ebe2c9"
  },
  "typefaces": {
    "serif": "Lora",
    "sans": "Inter",
    "mono": "Geist Mono"
  }
}
```

| Field | Meaning |
|-------|---------|
| `id` | Lowercase letters, digits and hyphens. Unique; matching a built-in replaces it. |
| `name` | What the menu shows. |
| `brightness` | `light` or `dark` — which half of a "follow system" pair it can serve. |
| `palette.paper` | The page. |
| `palette.panel` | Shelf, outline, table heads: a shade off the paper. |
| `palette.border` | Hairlines between panes and around code and tables. |
| `palette.ink` | Body text. |
| `palette.muted` | Breadcrumbs, counts, inactive outline entries. |
| `palette.accent` | Links, the active outline entry, bullets, the selected row. |
| `palette.codeBackground` | Fenced-code header; the body derives a second tone. |
| `palette.accentSoft` | Optional. Selected and hovered rows. Derived from the accent over the paper when absent. |
| `palette.selection` | Optional. Text selection. Derived from the accent when absent. |
| `typefaces` | Optional. Bundled family names; an unsupported name falls back locally to the library's own. |

Scientific `sub` and `sup` text uses each face's OpenType `subs` and `sups`
features. Every bundled face provides both.

Colours accept `#rgb`, `#rrggbb` or `#rrggbbaa`, with or without the `#`.

A file that is not valid JSON, or that is missing a required field, is skipped.
Open the Reading menu to see the filename and the exact reason — the rest of
your themes still load.
''';
