import 'package:flutter/widgets.dart';

import '../../application/ports/folder_document_scanner.dart';
import '../../application/ports/folder_scanner.dart';
import '../../application/ports/markdown_scanner.dart';
import '../../application/ports/reader_source_picker.dart';
import '../../application/ports/source_change_monitor.dart';
import '../../application/ports/workspace_files.dart';
import '../../application/ports/workspace_source_access.dart';
import 'platform_command.dart';

/// Everything the composition root needs from "wherever we are running".
/// One implementation per platform family; `platform.dart` picks it.
abstract interface class PlatformAdapters {
  FolderScanner get folderScanner;
  FolderDocumentScanner get folderDocumentScanner;
  MarkdownScanner get markdownScanner;
  SourceChangeMonitor get sourceChangeMonitor;
  WorkspaceFiles get workspaceFiles;
  WorkspaceSourceAccess get workspaceSourceAccess;
  ReaderSourcePicker? get readerSourcePicker;

  Future<FolderRef?> pickFolder();
  Future<MarkdownRef?> pickMarkdown();

  Stream<FolderRef> get folderDrops;
  Stream<MarkdownRef> get markdownDrops;

  Stream<bool> get dragging;

  /// Commands selected from native application menus, where the host has one.
  Stream<PlatformCommand> get commands;

  void openExternal(String url);

  /// Key/value options the app was launched with (URL query on the web).
  Map<String, String> get launchOptions;

  /// Wraps the UI so drops can be captured where the platform requires it.
  Widget dropRegion(Widget child);

  /// Shape of the app's top bar: tall enough for the platform's window
  /// controls, inset so it doesn't sit under them.
  ({double height, double leadingInset}) get topBar;

  /// Wraps the top bar so the window can be dragged by it where the system
  /// title bar has been hidden; identity elsewhere.
  Widget windowDragRegion(Widget child);

  /// Small per-reader settings that survive a restart. Strings in, strings
  /// out; what they mean is the caller's business.
  Future<String?> readPreference(String key);
  Future<void> writePreference(String key, String value);

  /// Theme documents the reader has added, as (origin, JSON text). The
  /// schema is the UI's; adapters only find and read the files.
  Future<List<({String origin, String json})>> readThemeDocuments();

  /// Reveals the reader's theme directory; absent where custom files are not
  /// available (the web).
  Future<void> Function()? get openThemesFolder;
}

/// A top bar with nothing to make room for.
const ({double height, double leadingInset}) plainTopBar = (
  height: 44,
  leadingInset: 8,
);
