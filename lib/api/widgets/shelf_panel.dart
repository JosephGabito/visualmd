import 'package:flutter/material.dart';

import '../../domain/library/document.dart';
import '../../domain/library/document_id.dart';
import '../../domain/library/folder.dart';
import '../../domain/library/library.dart';
import '../../domain/library/library_root.dart';
import '../../domain/library/library_root_id.dart';
import '../../domain/workspace/workspace.dart';
import '../../domain/workspace/workspace_id.dart';
import '../../domain/workspace/workspace_source.dart';
import '../theme/library_theme.dart';
import 'panel_heading.dart';

part 'shelf_reorder_machine.dart';

/// The shelf: ordered top-level folders, each containing its own document tree.
class ShelfPanel extends StatefulWidget {
  final Library library;
  final DocumentId? selected;
  final ValueChanged<DocumentId> onSelect;
  final VoidCallback onOpenFolder;
  final ValueChanged<LibraryRootId> onRemoveFolder;
  final ValueChanged<DocumentId> onRemoveMarkdown;
  final void Function(LibraryRootId id, int toIndex) onMoveFolder;
  final ({DocumentId id, int revision})? expandRequest;
  final Workspace? workspace;
  final Set<WorkspaceSourceId> unavailableSources;
  final ValueChanged<WorkspaceSourceId>? onReconnectSource;
  final ValueChanged<WorkspaceSourceId>? onRemoveUnavailableSource;

  const ShelfPanel({
    super.key,
    required this.library,
    required this.selected,
    required this.onSelect,
    required this.onOpenFolder,
    required this.onRemoveFolder,
    required this.onRemoveMarkdown,
    required this.onMoveFolder,
    this.expandRequest,
    this.workspace,
    this.unavailableSources = const {},
    this.onReconnectSource,
    this.onRemoveUnavailableSource,
  });

  @override
  State<ShelfPanel> createState() => _ShelfPanelState();
}

class _ShelfPanelState extends State<ShelfPanel> {
  final _expandedRoots = <LibraryRootId>{};
  final _expandedFolders = <(LibraryRootId, String)>{};
  final _rootKeys = <LibraryRootId, GlobalKey>{};
  final _shelfKey = GlobalKey();
  final _reorder = _ShelfReorderMachine();
  EdgeDraggingAutoScroller? _autoScroller;
  ScrollableState? _dragScrollable;
  Offset? _lastDragPosition;

  @override
  void didUpdateWidget(ShelfPanel old) {
    super.didUpdateWidget(old);
    final live = widget.library.roots.map((root) => root.id).toSet();
    _expandedRoots.removeWhere((id) => !live.contains(id));
    _expandedFolders.removeWhere((key) => !live.contains(key.$1));
    _rootKeys.removeWhere((id, _) => !live.contains(id));
    if (_reorder.retain(live)) _stopAutoScroll();
    final expandRequestChanged =
        widget.expandRequest != null &&
        widget.expandRequest != old.expandRequest;
    if (expandRequestChanged) {
      final id = widget.expandRequest!.id;
      // Expanded means the root is open only as far as the active document:
      // unrelated branches minimize, then its ancestors are revealed.
      _expandedFolders.removeWhere((key) => key.$1 == id.rootId);
      _expandTo(id);
    }
    final selected = widget.selected;
    final navigatedWithinLibrary =
        !expandRequestChanged &&
        selected != null &&
        old.selected != selected &&
        old.library.rootById(selected.rootId) != null;
    if (navigatedWithinLibrary) {
      _expandTo(selected);
    }
  }

  /// Navigation reveals a hidden document without opening a newly added root.
  void _expandTo(DocumentId? selected) {
    if (selected == null) return;
    _expandedRoots.add(selected.rootId);
    if (selected.folderPath.isEmpty) return;
    var path = '';
    for (final segment in selected.folderPath.split('/')) {
      path = path.isEmpty ? segment : '$path/$segment';
      _expandedFolders.add((selected.rootId, path));
    }
  }

  void _startReorder(
    LibraryRootId source,
    int sourceIndex,
    ScrollableState scrollable,
  ) {
    if (!_reorder.start(source, sourceIndex)) return;
    _dragScrollable = scrollable;
    _autoScroller = EdgeDraggingAutoScroller(
      scrollable,
      velocityScalar: 50,
      onScrollViewScrolled: () {
        final position = _lastDragPosition;
        if (mounted && position != null) _targetReorder(position);
      },
    );
    setState(() {});
  }

  void _updateReorder(DragUpdateDetails details) {
    if (_reorder.dragging == null) return;
    _lastDragPosition = details.globalPosition;
    _targetReorder(details.globalPosition);
    final scrollable = _dragScrollable;
    if (scrollable == null) return;
    final box = scrollable.context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final local = box.globalToLocal(details.globalPosition);
    _autoScroller?.startAutoScrollIfNecessary(
      Rect.fromCenter(center: local, width: 1, height: 1),
    );
  }

  void _targetReorder(Offset globalPosition) {
    final dragging = _reorder.dragging;
    if (dragging == null) return;
    final shelfBox = _shelfKey.currentContext?.findRenderObject();
    if (shelfBox is! RenderBox || !shelfBox.hasSize) return;
    final local = shelfBox.globalToLocal(globalPosition);
    if (!(Offset.zero & shelfBox.size).contains(local)) {
      if (_reorder.target(null)) setState(() {});
      return;
    }
    final remaining = widget.library.roots
        .where((root) => root.id != dragging.source)
        .toList(growable: false);
    var next = remaining.length;
    for (var index = 0; index < remaining.length; index++) {
      final box = _rootKeys[remaining[index].id]?.currentContext
          ?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      final middle = box.localToGlobal(Offset.zero).dy + box.size.height / 2;
      if (globalPosition.dy < middle) {
        next = index;
        break;
      }
    }
    if (_reorder.target(next)) setState(() {});
  }

  void _toggleRoot(LibraryRootId id) {
    if (_reorder.blocksRootInteractions) return;
    setState(() {
      _expandedRoots.contains(id)
          ? _expandedRoots.remove(id)
          : _expandedRoots.add(id);
    });
  }

  void _endReorder(DraggableDetails details) {
    _targetReorder(details.offset);
    final drop = _reorder.drop();
    if (drop == null) return;
    _stopAutoScroll();
    setState(() {});
    if (drop.moved) {
      widget.onMoveFolder(drop.source, drop.insertionIndex!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_reorder.settle()) return;
      setState(() {});
    });
  }

  void _stopAutoScroll() {
    _autoScroller?.stopAutoScroll();
    _autoScroller = null;
    _dragScrollable = null;
    _lastDragPosition = null;
  }

  @override
  void dispose() {
    _stopAutoScroll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = widget.library;
    final workspaceFolders = widget.workspace?.folders;
    final dragging = _reorder.dragging;
    final remaining = dragging == null
        ? const <LibraryRoot>[]
        : library.roots
              .where((root) => root.id != dragging.source)
              .toList(growable: false);
    final target = dragging?.insertionIndex;
    final dropBefore = target != null && target < remaining.length
        ? remaining[target].id
        : null;
    final dropAfter = target == remaining.length && remaining.isNotEmpty
        ? remaining.last.id
        : null;
    return SizedBox.expand(
      key: _shelfKey,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: (workspaceFolders?.length ?? library.roots.length) + 1,
        itemBuilder: (context, listIndex) {
          if (listIndex == 0) {
            return _ShelfHeader(
              library: library,
              selected: widget.selected,
              onSelect: widget.onSelect,
              onOpenFolder: widget.onOpenFolder,
              onRemoveMarkdown: widget.onRemoveMarkdown,
              workspace: widget.workspace,
              unavailableSources: widget.unavailableSources,
              onReconnectSource: widget.onReconnectSource,
              onRemoveUnavailableSource: widget.onRemoveUnavailableSource,
            );
          }
          final index = listIndex - 1;
          final source = workspaceFolders?[index];
          final root = source == null
              ? library.roots[index]
              : library.rootById(LibraryRootId(source.id.value));
          if (root == null) {
            final unavailableSource = source!;
            assert(widget.unavailableSources.contains(unavailableSource.id));
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _UnavailableSourceRow(
                source: unavailableSource,
                folder: true,
                onReconnect: widget.onReconnectSource == null
                    ? null
                    : () => widget.onReconnectSource!(unavailableSource.id),
                onRemove: widget.onRemoveUnavailableSource == null
                    ? null
                    : () => widget.onRemoveUnavailableSource!(
                        unavailableSource.id,
                      ),
              ),
            );
          }
          final rootIndex = library.roots.indexWhere(
            (candidate) => candidate.id == root.id,
          );
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _RootSection(
              key: ValueKey(root.id),
              rootRowKey: _rootKeys.putIfAbsent(
                root.id,
                () => GlobalKey(debugLabel: 'library-root-${root.id.value}'),
              ),
              root: root,
              index: rootIndex,
              rootCount: library.roots.length,
              open: _expandedRoots.contains(root.id),
              selected: widget.selected,
              expandedFolders: _expandedFolders,
              dropBefore: root.id == dropBefore,
              dropAfter: root.id == dropAfter,
              interactionsEnabled: !_reorder.blocksRootInteractions,
              onDragStarted: (scrollable) =>
                  _startReorder(root.id, rootIndex, scrollable),
              onDragUpdate: _updateReorder,
              onDragEnd: _endReorder,
              onToggleRoot: () => _toggleRoot(root.id),
              onToggleFolder: (path) => setState(() {
                final key = (root.id, path);
                _expandedFolders.contains(key)
                    ? _expandedFolders.remove(key)
                    : _expandedFolders.add(key);
              }),
              onSelect: widget.onSelect,
              onMove: (toIndex) => widget.onMoveFolder(root.id, toIndex),
              onRemove: () => widget.onRemoveFolder(root.id),
            ),
          );
        },
      ),
    );
  }
}

class _ShelfHeader extends StatelessWidget {
  final Library library;
  final DocumentId? selected;
  final ValueChanged<DocumentId> onSelect;
  final VoidCallback onOpenFolder;
  final ValueChanged<DocumentId> onRemoveMarkdown;
  final Workspace? workspace;
  final Set<WorkspaceSourceId> unavailableSources;
  final ValueChanged<WorkspaceSourceId>? onReconnectSource;
  final ValueChanged<WorkspaceSourceId>? onRemoveUnavailableSource;

  const _ShelfHeader({
    required this.library,
    required this.selected,
    required this.onSelect,
    required this.onOpenFolder,
    required this.onRemoveMarkdown,
    required this.workspace,
    required this.unavailableSources,
    required this.onReconnectSource,
    required this.onRemoveUnavailableSource,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (library.markdowns.isNotEmpty ||
            (workspace?.markdowns.isNotEmpty ?? false)) ...[
          const PanelHeading('Markdowns'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                if (workspace == null)
                  for (final document in library.markdowns)
                    _StandaloneDocumentRow(
                      document: document,
                      selected: document.id == selected,
                      onTap: () => onSelect(document.id),
                      onRemove: () => onRemoveMarkdown(document.id),
                    )
                else
                  for (final source in workspace!.markdowns)
                    _workspaceMarkdownRow(source),
              ],
            ),
          ),
        ],
        PanelHeading(
          'Library',
          trailing: Tooltip(
            message: 'Add folder',
            child: IconButton(
              onPressed: onOpenFolder,
              icon: const Icon(Icons.create_new_folder_outlined, size: 18),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          child: Text(
            '${workspace?.folders.length ?? library.roots.length} ${(workspace?.folders.length ?? library.roots.length) == 1 ? 'folder' : 'folders'} · '
            '${library.folderDocumentCount} ${library.folderDocumentCount == 1 ? 'document' : 'documents'}',
            style: context.type.sans(color: p.muted, size: 12),
          ),
        ),
      ],
    );
  }

  Widget _workspaceMarkdownRow(WorkspaceSource source) {
    final rootId = LibraryRootId('standalone-markdown:${source.id.value}');
    Document? document;
    for (final candidate in library.markdowns) {
      if (candidate.id.rootId == rootId) {
        document = candidate;
        break;
      }
    }
    if (document != null) {
      return _StandaloneDocumentRow(
        document: document,
        selected: document.id == selected,
        onTap: () => onSelect(document!.id),
        onRemove: () => onRemoveMarkdown(document!.id),
      );
    }
    assert(unavailableSources.contains(source.id));
    return _UnavailableSourceRow(
      source: source,
      folder: false,
      onReconnect: onReconnectSource == null
          ? null
          : () => onReconnectSource!(source.id),
      onRemove: onRemoveUnavailableSource == null
          ? null
          : () => onRemoveUnavailableSource!(source.id),
    );
  }
}

class _UnavailableSourceRow extends StatefulWidget {
  final WorkspaceSource source;
  final bool folder;
  final VoidCallback? onReconnect;
  final VoidCallback? onRemove;

  const _UnavailableSourceRow({
    required this.source,
    required this.folder,
    required this.onReconnect,
    required this.onRemove,
  });

  @override
  State<_UnavailableSourceRow> createState() => _UnavailableSourceRowState();
}

class _UnavailableSourceRowState extends State<_UnavailableSourceRow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onReconnect,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(
            children: [
              Icon(
                widget.folder
                    ? Icons.folder_off_outlined
                    : Icons.description_outlined,
                size: 17,
                color: p.muted,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  widget.source.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.sans(color: p.muted, size: 13.5),
                ),
              ),
              if (_hovered) ...[
                Tooltip(
                  message: 'Reconnect',
                  child: Icon(Icons.link_outlined, size: 16, color: p.accent),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Remove from workspace',
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onRemove,
                  icon: Icon(Icons.delete_outline, size: 16, color: p.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RootSection extends StatelessWidget {
  final GlobalKey rootRowKey;
  final LibraryRoot root;
  final int index;
  final int rootCount;
  final bool open;
  final DocumentId? selected;
  final Set<(LibraryRootId, String)> expandedFolders;
  final bool dropBefore;
  final bool dropAfter;
  final bool interactionsEnabled;
  final ValueChanged<ScrollableState> onDragStarted;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final ValueChanged<DraggableDetails> onDragEnd;
  final VoidCallback onToggleRoot;
  final ValueChanged<String> onToggleFolder;
  final ValueChanged<DocumentId> onSelect;
  final ValueChanged<int> onMove;
  final VoidCallback onRemove;

  const _RootSection({
    super.key,
    required this.rootRowKey,
    required this.root,
    required this.index,
    required this.rootCount,
    required this.open,
    required this.selected,
    required this.expandedFolders,
    required this.dropBefore,
    required this.dropAfter,
    required this.interactionsEnabled,
    required this.onDragStarted,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onToggleRoot,
    required this.onToggleFolder,
    required this.onSelect,
    required this.onMove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    if (open) _addFolder(rows, root.folder, 0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RootRow(
              key: rootRowKey,
              root: root,
              index: index,
              rootCount: rootCount,
              open: open,
              interactionsEnabled: interactionsEnabled,
              onDragStarted: onDragStarted,
              onDragUpdate: onDragUpdate,
              onDragEnd: onDragEnd,
              onTap: onToggleRoot,
              onMove: onMove,
              onRemove: onRemove,
            ),
            ...rows,
          ],
        ),
        if (dropBefore) const _DropIndicator(top: -1),
        if (dropAfter) const _DropIndicator(bottom: -1),
      ],
    );
  }

  void _addFolder(List<Widget> rows, Folder folder, int depth) {
    for (final document in folder.documents) {
      rows.add(
        _DocumentRow(
          document: document,
          depth: depth,
          selected: document.id == selected,
          onTap: () => onSelect(document.id),
        ),
      );
    }
    for (final child in folder.folders) {
      final open = expandedFolders.contains((root.id, child.path));
      rows.add(
        _FolderRow(
          folder: child,
          depth: depth,
          open: open,
          onTap: () => onToggleFolder(child.path),
        ),
      );
      if (open) _addFolder(rows, child, depth + 1);
    }
  }
}

class _DropIndicator extends StatelessWidget {
  final double? top;
  final double? bottom;

  const _DropIndicator({this.top, this.bottom});

  @override
  Widget build(BuildContext context) => Positioned(
    key: const ValueKey('library-drop-indicator'),
    left: 6,
    right: 6,
    top: top,
    bottom: bottom,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF60A5FA)
            : const Color(0xFF3B82F6),
        borderRadius: BorderRadius.circular(1),
      ),
      child: const SizedBox(height: 2),
    ),
  );
}

class _RootRow extends StatefulWidget {
  final LibraryRoot root;
  final int index;
  final int rootCount;
  final bool open;
  final bool interactionsEnabled;
  final ValueChanged<ScrollableState> onDragStarted;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final ValueChanged<DraggableDetails> onDragEnd;
  final VoidCallback onTap;
  final ValueChanged<int> onMove;
  final VoidCallback onRemove;

  const _RootRow({
    super.key,
    required this.root,
    required this.index,
    required this.rootCount,
    required this.open,
    required this.interactionsEnabled,
    required this.onDragStarted,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onTap,
    required this.onMove,
    required this.onRemove,
  });

  @override
  State<_RootRow> createState() => _RootRowState();
}

class _RootRowState extends State<_RootRow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(
        label:
            '${widget.root.name}, folder ${widget.index + 1} of ${widget.rootCount}',
        onIncrease:
            widget.interactionsEnabled && widget.index < widget.rootCount - 1
            ? () => widget.onMove(widget.index + 1)
            : null,
        onDecrease: widget.interactionsEnabled && widget.index > 0
            ? () => widget.onMove(widget.index - 1)
            : null,
        onDismiss: widget.interactionsEnabled ? widget.onRemove : null,
        child: Row(
          children: [
            Expanded(
              child: Draggable<LibraryRootId>(
                data: widget.root.id,
                axis: Axis.vertical,
                affinity: Axis.vertical,
                maxSimultaneousDrags: 1,
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: const SizedBox(
                  key: ValueKey('library-drag-feedback'),
                  width: 1,
                  height: 1,
                ),
                onDragStarted: () =>
                    widget.onDragStarted(Scrollable.of(context)),
                onDragUpdate: widget.onDragUpdate,
                onDragEnd: widget.onDragEnd,
                child: InkWell(
                  key: ValueKey('root-toggle-${widget.root.id.value}'),
                  onTap: widget.interactionsEnabled ? widget.onTap : null,
                  borderRadius: BorderRadius.circular(6),
                  hoverColor: p.accentSoft.withValues(alpha: 0.5),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 2, 2, 2),
                    child: Row(
                      children: [
                        Icon(
                          widget.open ? Icons.expand_more : Icons.chevron_right,
                          size: 16,
                          color: p.muted,
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          widget.open
                              ? Icons.folder_open_outlined
                              : Icons.folder_outlined,
                          size: 17,
                          color: p.muted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.root.name,
                            overflow: TextOverflow.ellipsis,
                            style: context.type.sans(
                              color: p.ink,
                              size: 13,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 24,
              height: 24,
              child: _hovered && widget.interactionsEnabled
                  ? Tooltip(
                      message: 'Remove from library',
                      child: IconButton(
                        onPressed: widget.onRemove,
                        icon: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: p.muted,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 24,
                          height: 24,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

const _indent = 16.0;

class _FolderRow extends StatelessWidget {
  final Folder folder;
  final int depth;
  final bool open;
  final VoidCallback onTap;

  const _FolderRow({
    required this.folder,
    required this.depth,
    required this.open,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      hoverColor: p.accentSoft.withValues(alpha: 0.5),
      child: Padding(
        padding: EdgeInsets.fromLTRB(22.0 + depth * _indent, 5, 8, 5),
        child: Row(
          children: [
            Icon(
              open ? Icons.expand_more : Icons.chevron_right,
              size: 16,
              color: p.muted,
            ),
            const SizedBox(width: 4),
            Icon(
              open ? Icons.folder_open_outlined : Icons.folder_outlined,
              size: 16,
              color: p.muted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                folder.name,
                overflow: TextOverflow.ellipsis,
                style: context.type.sans(
                  color: p.ink,
                  size: 13,
                  weight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  final Document document;
  final int depth;
  final double leading;
  final bool selected;
  final VoidCallback onTap;

  const _DocumentRow({
    required this.document,
    required this.depth,
    this.leading = 42,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tooltip(
      message: document.fileName,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        hoverColor: p.accentSoft.withValues(alpha: 0.5),
        child: Container(
          padding: EdgeInsets.fromLTRB(leading + depth * _indent, 5, 8, 5),
          decoration: BoxDecoration(
            color: selected ? p.accentSoft : null,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                document.isReadme
                    ? Icons.auto_stories_outlined
                    : Icons.description_outlined,
                size: 15,
                color: selected ? p.ink : p.muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  document.title,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.sans(
                    color: p.ink,
                    size: 13,
                    weight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StandaloneDocumentRow extends StatefulWidget {
  final Document document;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _StandaloneDocumentRow({
    required this.document,
    required this.selected,
    required this.onTap,
    required this.onRemove,
  });

  @override
  State<_StandaloneDocumentRow> createState() => _StandaloneDocumentRowState();
}

class _StandaloneDocumentRowState extends State<_StandaloneDocumentRow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return MouseRegion(
      key: ValueKey('standalone-document-${widget.document.id}'),
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(
        label: widget.document.title,
        onDismiss: widget.onRemove,
        child: Row(
          children: [
            Expanded(
              child: _DocumentRow(
                document: widget.document,
                depth: 0,
                leading: 18,
                selected: widget.selected,
                onTap: widget.onTap,
              ),
            ),
            SizedBox(
              width: 24,
              height: 24,
              child: _hovered
                  ? Tooltip(
                      message: 'Remove from Markdowns',
                      child: IconButton(
                        onPressed: widget.onRemove,
                        icon: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: p.muted,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 24,
                          height: 24,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
