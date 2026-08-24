import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../../application/ports/folder_document_scanner.dart';
import '../../application/ports/folder_scanner.dart';
import '../../application/ports/markdown_scanner.dart';
import '../../application/ports/reader_source_picker.dart';
import '../../application/ports/source_change_monitor.dart';
import '../../application/ports/workspace_files.dart';
import '../../application/ports/workspace_source_access.dart';
import '../web/browser_folder.dart';
import '../web/browser_folder_drop.dart';
import '../web/browser_folder_picker.dart';
import '../web/browser_folder_scanner.dart';
import '../web/browser_handle_store.dart';
import '../web/browser_markdown.dart';
import '../web/browser_markdown_picker.dart';
import '../web/browser_markdown_scanner.dart';
import '../web/browser_source_identity.dart';
import '../web/browser_source_change_monitor.dart';
import '../web/browser_workspace_files.dart';
import '../web/browser_workspace_source_access.dart';
import '../web/browser_links.dart';
import 'platform_adapters.dart';
import 'platform_command.dart';

Future<PlatformAdapters> createPlatformAdapters() async => _WebAdapters();

final class _WebAdapters implements PlatformAdapters {
  final _registry = BrowserFolderRegistry('browser');
  final _markdownRegistry = BrowserMarkdownRegistry('browser-markdown');
  final _sourceIdentities = BrowserSourceIdentity();
  late final _drop = BrowserFolderDrop(_registry, _markdownRegistry)..listen();
  late final _picker = BrowserFolderPicker(_registry);
  late final _markdownPicker = BrowserMarkdownPicker(_markdownRegistry);

  late final _folderScanner = BrowserFolderScanner(
    _registry,
    _sourceIdentities,
  );

  @override
  FolderScanner get folderScanner => _folderScanner;

  @override
  FolderDocumentScanner get folderDocumentScanner => _folderScanner;

  @override
  late final MarkdownScanner markdownScanner = BrowserMarkdownScanner(
    _markdownRegistry,
    _sourceIdentities,
  );

  @override
  late final SourceChangeMonitor sourceChangeMonitor =
      BrowserSourceChangeMonitor(_registry, _markdownRegistry);

  @override
  final WorkspaceFiles workspaceFiles = BrowserWorkspaceFiles();

  @override
  late final WorkspaceSourceAccess workspaceSourceAccess =
      BrowserWorkspaceSourceAccess(
        _registry,
        _markdownRegistry,
        BrowserHandleStore(),
      );

  @override
  ReaderSourcePicker? get readerSourcePicker => null;

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
  Stream<PlatformCommand> get commands => const Stream.empty();

  @override
  void openExternal(String url) => openInBrowser(url);

  @override
  Map<String, String> get launchOptions =>
      Uri.parse(web.window.location.href).queryParameters;

  @override
  Widget dropRegion(Widget child) => child; // the document itself is the target

  @override
  ({double height, double leadingInset}) get topBar => plainTopBar;

  @override
  Widget windowDragRegion(Widget child) => child; // the browser owns its chrome

  @override
  Future<String?> readPreference(String key) async =>
      web.window.localStorage.getItem('visualmd.$key');

  @override
  Future<void> writePreference(String key, String value) async =>
      web.window.localStorage.setItem('visualmd.$key', value);

  @override
  Future<List<({String origin, String json})>> readThemeDocuments() async =>
      const [];

  @override
  String? get themesLocation => null;
}
