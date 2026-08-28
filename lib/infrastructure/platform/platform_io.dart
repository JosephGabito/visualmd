import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../../application/ports/document_image_loader.dart';
import '../../application/ports/external_open_item.dart';
import '../../application/ports/folder_document_scanner.dart';
import '../../application/ports/folder_scanner.dart';
import '../../application/ports/markdown_scanner.dart';
import '../../application/ports/reader_source_picker.dart';
import '../../application/ports/shelf_source_actions.dart';
import '../../application/ports/source_change_monitor.dart';
import '../../application/ports/workspace_files.dart';
import '../../application/ports/workspace_recovery_store.dart';
import '../../application/ports/workspace_source_access.dart';
import '../io/desktop_folder_drop.dart';
import '../io/desktop_external_open_items.dart';
import '../io/desktop_commands.dart';
import '../io/desktop_folder_picker.dart';
import '../io/desktop_links.dart';
import '../io/desktop_markdown_picker.dart';
import '../io/desktop_reader_source_picker.dart';
import '../io/desktop_security_scope.dart';
import '../io/desktop_shelf_source_actions.dart';
import '../io/desktop_source_change_monitor.dart';
import '../io/desktop_workspace_files.dart';
import '../io/desktop_workspace_recovery_store.dart';
import '../io/desktop_workspace_source_access.dart';
import '../io/local_folder.dart';
import '../io/local_document_image_loader.dart';
import '../io/local_folder_scanner.dart';
import '../io/local_markdown.dart';
import '../io/local_markdown_scanner.dart';
import '../io/reader_files.dart';
import '../workspace/workspace_json_codec.dart';
import 'platform_adapters.dart';
import 'platform_command.dart';

Future<PlatformAdapters> createPlatformAdapters() async {
  var topBar = plainTopBar;
  if (Platform.isMacOS) {
    // MainFlutterWindow.swift hides the system title bar; the traffic lights
    // remain at the top left, so the top bar grows to their height and
    // starts to their right.
    await windowManager.ensureInitialized();
    final titleBar = (await windowManager.getTitleBarHeight()).toDouble();
    topBar = (height: titleBar > 0 ? titleBar : 52.0, leadingInset: 84.0);
  }
  return _DesktopAdapters(topBar, await ReaderFiles.locate());
}

final class _DesktopAdapters implements PlatformAdapters {
  @override
  final ({double height, double leadingInset}) topBar;
  final _registry = LocalFolderRegistry('local');
  final _markdownRegistry = LocalMarkdownRegistry('local-markdown');
  final ReaderFiles _files;

  _DesktopAdapters(this.topBar, this._files);
  late final _drop = DesktopFolderDrop(_registry, _markdownRegistry);
  late final _picker = DesktopFolderPicker(_registry);
  late final _markdownPicker = DesktopMarkdownPicker(_markdownRegistry);
  late final DesktopExternalOpenItems? _externalOpenItems = Platform.isMacOS
      ? DesktopExternalOpenItems(_markdownRegistry, _workspaceFiles)
      : null;
  late final _shelfSourceActions = DesktopShelfSourceActions(
    _registry,
    _markdownRegistry,
    access: const DesktopSecurityScope(),
  );
  late final _commands = DesktopCommands();

  late final _folderScanner = LocalFolderScanner(
    _registry,
    access: const DesktopSecurityScope(),
  );

  @override
  late final DocumentImageLoader documentImageLoader = LocalDocumentImageLoader(
    _registry,
    _markdownRegistry,
    access: const DesktopSecurityScope(),
  );

  @override
  FolderScanner get folderScanner => _folderScanner;

  @override
  FolderDocumentScanner get folderDocumentScanner => _folderScanner;

  @override
  late final MarkdownScanner markdownScanner = LocalMarkdownScanner(
    _markdownRegistry,
    access: const DesktopSecurityScope(),
  );

  @override
  late final SourceChangeMonitor sourceChangeMonitor =
      DesktopSourceChangeMonitor(_registry, _markdownRegistry);

  final DesktopWorkspaceFiles _workspaceFiles = DesktopWorkspaceFiles();

  @override
  WorkspaceFiles get workspaceFiles => _workspaceFiles;

  @override
  late final WorkspaceRecoveryStore workspaceRecoveryStore =
      DesktopWorkspaceRecoveryStore(_files, const WorkspaceJsonCodec());

  @override
  late final WorkspaceSourceAccess workspaceSourceAccess =
      DesktopWorkspaceSourceAccess(_registry, _markdownRegistry, _files);

  @override
  late final ReaderSourcePicker? readerSourcePicker = Platform.isMacOS
      ? DesktopReaderSourcePicker(_registry, _markdownRegistry)
      : null;

  @override
  ShelfSourceActions get shelfSourceActions => _shelfSourceActions;

  @override
  Future<FolderRef?> pickFolder() => _picker.pick();

  @override
  Future<MarkdownRef?> pickMarkdown() => _markdownPicker.pick();

  @override
  Stream<FolderRef> get folderDrops => _drop.drops;

  @override
  Stream<MarkdownRef> get markdownDrops => _drop.markdownDrops;

  @override
  Stream<bool> get dragging => _drop.dragging;

  @override
  Stream<ExternalOpenItem> get externalOpenItems =>
      _externalOpenItems?.stream ?? const Stream.empty();

  @override
  Stream<PlatformCommand> get commands => _commands.stream;

  @override
  void openExternal(String url) => openWithSystem(url);

  @override
  Map<String, String> get launchOptions => const {};

  @override
  Widget dropRegion(Widget child) => _drop.wrap(child);

  @override
  Widget windowDragRegion(Widget child) {
    if (!Platform.isMacOS) return child; // the system title bar is still there
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTap: () async {
        await windowManager.isMaximized()
            ? windowManager.unmaximize()
            : windowManager.maximize();
      },
      child: DragToMoveArea(child: child),
    );
  }

  @override
  Future<String?> readPreference(String key) => _files.readPreference(key);

  @override
  Future<void> writePreference(String key, String value) =>
      _files.writePreference(key, value);

  @override
  Future<List<({String origin, String json})>> readThemeDocuments() =>
      _files.readThemeDocuments();

  @override
  Future<void> Function()? get openThemesFolder =>
      () => openWithSystem(_files.themesDirectory.path);
}
