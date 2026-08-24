import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';

import '../../application/ports/folder_scanner.dart';
import '../../application/ports/markdown_scanner.dart';
import '../../application/ports/source_change_monitor.dart';
import '../../domain/library/hidden_folders.dart';
import '../../domain/library/markdown_file.dart';
import 'local_folder.dart';
import 'local_markdown.dart';

/// Desktop invalidations come from native filesystem event streams.
///
/// A failed native watcher changes to a five-second full-source invalidation.
/// That slower path is deliberately a fallback: ordinary reading performs no
/// polling work while the filesystem is quiet.
final class DesktopSourceChangeMonitor implements SourceChangeMonitor {
  static const fallbackInterval = Duration(seconds: 5);

  final LocalFolderRegistry _folders;
  final LocalMarkdownRegistry _markdowns;

  const DesktopSourceChangeMonitor(this._folders, this._markdowns);

  @override
  Stream<SourceChange> watchFolder(FolderRef ref) {
    final folder = _folders.lookup(ref);
    if (folder == null) return const Stream.empty();
    return switch (folder) {
      LocalDirectory(:final path, :final bookmark) => _session(
        sourceName: ref.name,
        bookmarks: [bookmark],
        directories: [
          _DirectoryWatch(
            path: path,
            // Dart's Linux adapter cannot recurse; macOS and Windows can.
            recursive: !Platform.isLinux,
            onEvent: (event) => _folderChanges(ref, path, event),
          ),
        ],
        fallback: FolderRescanRequested(ref),
      ),
      LocalFiles(files: final files) => _watchLooseFiles(ref, files),
    };
  }

  @override
  Stream<SourceChange> watchMarkdown(MarkdownRef ref) {
    final markdown = _markdowns.lookup(ref);
    if (markdown == null) return const Stream.empty();
    final target = _absolute(markdown.path);
    return _session(
      sourceName: ref.name,
      bookmarks: [markdown.bookmark],
      directories: [
        _DirectoryWatch(
          path: File(markdown.path).parent.path,
          recursive: false,
          onEvent: (event) =>
              _eventPaths(event).any((path) => _samePath(path, target))
              ? [MarkdownInvalidated(ref)]
              : const [],
        ),
      ],
      fallback: MarkdownInvalidated(ref),
    );
  }

  Stream<SourceChange> _watchLooseFiles(
    FolderRef ref,
    List<(String, Uint8List?)> files,
  ) {
    final byParent = <String, Map<String, String>>{};
    for (final (path, _) in files) {
      final absolute = _absolute(path);
      final parent = _absolute(File(path).parent.path);
      byParent.putIfAbsent(parent, () => {})[_canonical(absolute)] = baseName(
        path,
      );
    }
    return _session(
      sourceName: ref.name,
      bookmarks: [for (final (_, bookmark) in files) bookmark],
      directories: [
        for (final entry in byParent.entries)
          _DirectoryWatch(
            path: entry.key,
            recursive: false,
            onEvent: (event) {
              final changed = <String>{};
              for (final path in _eventPaths(event)) {
                final relative = entry.value[_canonical(_absolute(path))];
                if (relative != null) changed.add(relative);
              }
              return changed.isEmpty
                  ? const []
                  : [FolderDocumentsInvalidated(ref, changed)];
            },
          ),
      ],
      fallback: FolderRescanRequested(ref),
    );
  }

  Iterable<SourceChange> _folderChanges(
    FolderRef ref,
    String root,
    FileSystemEvent event,
  ) sync* {
    if (event.isDirectory) {
      yield FolderRescanRequested(ref);
      return;
    }
    final changed = <String>{};
    for (final path in _eventPaths(event)) {
      final relative = _relativeTo(root, path);
      if (relative == null ||
          !MarkdownFile.isMarkdown(relative) ||
          HiddenFolders.hidesPath(relative)) {
        continue;
      }
      changed.add(relative);
    }
    if (changed.isNotEmpty) yield FolderDocumentsInvalidated(ref, changed);
  }

  Stream<SourceChange> _session({
    required String sourceName,
    required Iterable<Uint8List?> bookmarks,
    required List<_DirectoryWatch> directories,
    required SourceChange fallback,
  }) {
    late final StreamController<SourceChange> controller;
    late final _DesktopWatchSession session;
    controller = StreamController<SourceChange>(sync: true);
    session = _DesktopWatchSession(
      sourceName: sourceName,
      bookmarks: bookmarks.whereType<Uint8List>().toList(),
      directories: directories,
      fallback: fallback,
      add: (change) {
        if (!controller.isClosed) controller.add(change);
      },
    );
    controller.onListen = () => unawaited(session.start());
    controller.onCancel = session.dispose;
    return controller.stream;
  }
}

final class _DirectoryWatch {
  final String path;
  final bool recursive;
  final Iterable<SourceChange> Function(FileSystemEvent event) onEvent;

  const _DirectoryWatch({
    required this.path,
    required this.recursive,
    required this.onEvent,
  });
}

final class _DesktopWatchSession {
  final String sourceName;
  final List<Uint8List> bookmarks;
  final List<_DirectoryWatch> directories;
  final SourceChange fallback;
  final void Function(SourceChange change) add;
  final _subscriptions = <StreamSubscription<FileSystemEvent>>[];
  final _grantedBookmarks = <Uint8List>[];
  Timer? _fallbackTimer;
  bool _disposed = false;
  bool _fallbackStarted = false;

  _DesktopWatchSession({
    required this.sourceName,
    required this.bookmarks,
    required this.directories,
    required this.fallback,
    required this.add,
  });

  Future<void> start() async {
    if (_disposed) return;
    if (Platform.isMacOS) {
      for (final bookmark in bookmarks) {
        if (bookmark.isEmpty) continue;
        final granted = await DesktopDrop.instance
            .startAccessingSecurityScopedResource(bookmark: bookmark);
        if (granted) _grantedBookmarks.add(bookmark);
      }
    }
    if (_disposed) return;
    if (!FileSystemEntity.isWatchSupported) {
      _startFallback('filesystem events are not supported');
      return;
    }
    try {
      for (final watch in directories) {
        final subscription = Directory(watch.path)
            .watch(recursive: watch.recursive)
            .listen(
              (event) {
                for (final change in watch.onEvent(event)) {
                  add(change);
                }
              },
              onError: (Object failure) => _startFallback(failure.toString()),
              onDone: () => _startFallback('filesystem watcher stopped'),
            );
        _subscriptions.add(subscription);
      }
    } on Object catch (failure) {
      _startFallback(failure.toString());
    }
  }

  void _startFallback(String reason) {
    if (_disposed || _fallbackStarted) return;
    _fallbackStarted = true;
    add(SourceWatchFailed(sourceName, reason));
    _fallbackTimer = Timer.periodic(
      DesktopSourceChangeMonitor.fallbackInterval,
      (_) => add(fallback),
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _fallbackTimer?.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    if (Platform.isMacOS) {
      for (final bookmark in _grantedBookmarks) {
        await DesktopDrop.instance.stopAccessingSecurityScopedResource(
          bookmark: bookmark,
        );
      }
    }
  }
}

Iterable<String> _eventPaths(FileSystemEvent event) sync* {
  yield event.path;
  if (event case FileSystemMoveEvent(:final destination?)) yield destination;
}

String _absolute(String path) =>
    File(path).absolute.path
        .replaceAll('\\', '/')
        .replaceAll(RegExp(r'/+$'), '');

String _canonical(String path) {
  final normalized = path.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
  return Platform.isWindows ? normalized.toLowerCase() : normalized;
}

bool _samePath(String first, String second) =>
    _canonical(_absolute(first)) == _canonical(_absolute(second));

String? _relativeTo(String root, String path) {
  final absoluteRoot = _absolute(root);
  final absolutePath = _absolute(path);
  final canonicalRoot = _canonical(absoluteRoot);
  final canonicalPath = _canonical(absolutePath);
  if (canonicalPath == canonicalRoot) return '';
  if (!canonicalPath.startsWith('$canonicalRoot/')) return null;
  return absolutePath.substring(absoluteRoot.length + 1);
}
