import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/ports/shelf_source_actions.dart';
import '../../domain/library/document.dart';
import '../../domain/library/document_id.dart';
import '../../domain/library/folder.dart';
import '../../domain/library/library.dart';
import '../../domain/library/library_root.dart';
import '../../domain/library/library_root_id.dart';
import '../../domain/workspace/workspace.dart';
import '../../domain/workspace/workspace_id.dart';
import '../../domain/workspace/workspace_source.dart';
import '../../presentation/shelf/shelf_label_mode.dart';
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
  final ShelfLabelMode labelMode;
  final ValueChanged<ShelfLabelMode>? onLabelModeChanged;
  final ShelfSourceActions? sourceActions;

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
    this.labelMode = ShelfLabelMode.title,
    this.onLabelModeChanged,
    this.sourceActions,
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
              labelMode: widget.labelMode,
              onLabelModeChanged: widget.onLabelModeChanged,
              sourceActions: widget.sourceActions,
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
              labelMode: widget.labelMode,
              sourceActions: widget.sourceActions,
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
  final ShelfLabelMode labelMode;
  final ValueChanged<ShelfLabelMode>? onLabelModeChanged;
  final ShelfSourceActions? sourceActions;

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
    required this.labelMode,
    required this.onLabelModeChanged,
    required this.sourceActions,
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
                      labelMode: labelMode,
                      sourceActions: sourceActions,
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
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onLabelModeChanged != null)
                _ShelfHeaderButton(
                  key: const ValueKey('shelf-label-mode-toggle'),
                  label: labelMode == ShelfLabelMode.title
                      ? 'Show file names'
                      : 'Show Markdown titles',
                  icon: labelMode == ShelfLabelMode.title
                      ? Icons.title_outlined
                      : Icons.description_outlined,
                  onPressed: () => onLabelModeChanged!(
                    labelMode == ShelfLabelMode.title
                        ? ShelfLabelMode.fileName
                        : ShelfLabelMode.title,
                  ),
                ),
              _ShelfHeaderButton(
                label: 'Add folder',
                icon: Icons.create_new_folder_outlined,
                onPressed: onOpenFolder,
              ),
            ],
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
        labelMode: labelMode,
        sourceActions: sourceActions,
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

final class _ShelfHeaderButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _ShelfHeaderButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    excludeFromSemantics: true,
    child: Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        visualDensity: VisualDensity.compact,
      ),
    ),
  );
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
  final ShelfLabelMode labelMode;
  final ShelfSourceActions? sourceActions;

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
    required this.labelMode,
    required this.sourceActions,
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
              sourceActions: sourceActions,
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
          labelMode: labelMode,
          sourceActions: sourceActions,
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
          rootId: root.id,
          sourceActions: sourceActions,
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
  final ShelfSourceActions? sourceActions;

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
    required this.sourceActions,
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
                child: _ShelfContextShortcuts(
                  source: ShelfFolderLocation(
                    rootId: widget.root.id,
                    relativePath: '.',
                  ),
                  sourceActions: widget.sourceActions,
                  enabled: widget.interactionsEnabled,
                  child: InkWell(
                    key: ValueKey('root-toggle-${widget.root.id.value}'),
                    onTap: widget.interactionsEnabled ? widget.onTap : null,
                    onSecondaryTapDown: widget.interactionsEnabled
                        ? (details) => _showShelfContextMenu(
                            context,
                            details.globalPosition,
                            ShelfFolderLocation(
                              rootId: widget.root.id,
                              relativePath: '.',
                            ),
                            widget.sourceActions,
                          )
                        : null,
                    borderRadius: BorderRadius.circular(6),
                    hoverColor: p.accentSoft.withValues(alpha: 0.5),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 2, 2, 2),
                      child: Row(
                        children: [
                          Icon(
                            widget.open
                                ? Icons.expand_more
                                : Icons.chevron_right,
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
  final LibraryRootId rootId;
  final ShelfSourceActions? sourceActions;

  const _FolderRow({
    required this.folder,
    required this.depth,
    required this.open,
    required this.onTap,
    required this.rootId,
    required this.sourceActions,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final source = ShelfFolderLocation(
      rootId: rootId,
      relativePath: folder.path,
    );
    return _ShelfContextShortcuts(
      source: source,
      sourceActions: sourceActions,
      child: InkWell(
        onTap: onTap,
        onSecondaryTapDown: (details) => _showShelfContextMenu(
          context,
          details.globalPosition,
          source,
          sourceActions,
        ),
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
  final ShelfLabelMode labelMode;
  final ShelfSourceActions? sourceActions;

  const _DocumentRow({
    required this.document,
    required this.depth,
    this.leading = 42,
    required this.selected,
    required this.onTap,
    required this.labelMode,
    required this.sourceActions,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final label = labelMode == ShelfLabelMode.title
        ? document.title
        : document.fileName;
    final source = ShelfDocumentLocation(document.id);
    return Tooltip(
      message: labelMode == ShelfLabelMode.title
          ? document.fileName
          : document.title,
      child: _ShelfContextShortcuts(
        source: source,
        sourceActions: sourceActions,
        child: InkWell(
          onTap: onTap,
          onSecondaryTapDown: (details) => _showShelfContextMenu(
            context,
            details.globalPosition,
            source,
            sourceActions,
          ),
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
                    label,
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
      ),
    );
  }
}

class _StandaloneDocumentRow extends StatefulWidget {
  final Document document;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final ShelfLabelMode labelMode;
  final ShelfSourceActions? sourceActions;

  const _StandaloneDocumentRow({
    required this.document,
    required this.selected,
    required this.onTap,
    required this.onRemove,
    required this.labelMode,
    required this.sourceActions,
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
        label: widget.labelMode == ShelfLabelMode.title
            ? widget.document.title
            : widget.document.fileName,
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
                labelMode: widget.labelMode,
                sourceActions: widget.sourceActions,
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

enum _ShelfContextCommand { reveal, copyRelativePath, copyFullPath }

final class _ShelfContextShortcuts extends StatelessWidget {
  final ShelfSourceLocation source;
  final ShelfSourceActions? sourceActions;
  final bool enabled;
  final Widget child;

  const _ShelfContextShortcuts({
    required this.source,
    required this.sourceActions,
    this.enabled = true,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: enabled
        ? {
            const SingleActivator(LogicalKeyboardKey.contextMenu): () =>
                _showFromKeyboard(context),
            const SingleActivator(LogicalKeyboardKey.f10, shift: true): () =>
                _showFromKeyboard(context),
          }
        : const {},
    child: child,
  );

  void _showFromKeyboard(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final localX = box.size.width.clamp(0.0, 180.0).toDouble();
    final position = box.localToGlobal(Offset(localX, box.size.height));
    _showShelfContextMenu(context, position, source, sourceActions);
  }
}

Future<void> _showShelfContextMenu(
  BuildContext context,
  Offset position,
  ShelfSourceLocation source,
  ShelfSourceActions? sourceActions,
) async {
  final absolutePath = sourceActions?.absolutePath(source);
  final entries = <(_ShelfContextCommand, IconData, String)>[
    if (absolutePath != null)
      (
        _ShelfContextCommand.reveal,
        Icons.folder_open_outlined,
        sourceActions!.revealLabel,
      ),
    (
      _ShelfContextCommand.copyRelativePath,
      Icons.short_text_outlined,
      'Copy relative path',
    ),
    if (absolutePath != null)
      (
        _ShelfContextCommand.copyFullPath,
        Icons.content_copy_outlined,
        'Copy full path',
      ),
  ];
  final command = await showGeneralDialog<_ShelfContextCommand>(
    context: context,
    barrierColor: Colors.transparent,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    transitionDuration: Duration.zero,
    pageBuilder: (context, _, _) =>
        _ShelfContextMenu(anchor: position, entries: entries),
  );

  try {
    switch (command) {
      case _ShelfContextCommand.reveal:
        await sourceActions!.reveal(source);
      case _ShelfContextCommand.copyRelativePath:
        await Clipboard.setData(ClipboardData(text: source.relativePath));
      case _ShelfContextCommand.copyFullPath:
        await Clipboard.setData(ClipboardData(text: absolutePath!));
      case null:
        return;
    }
  } catch (_) {
    if (!context.mounted) return;
    final action = switch (command) {
      _ShelfContextCommand.reveal => 'reveal this source',
      _ShelfContextCommand.copyRelativePath ||
      _ShelfContextCommand.copyFullPath => 'copy this path',
      null => 'complete this command',
    };
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text("Couldn't $action.")));
  }
}

final class _ShelfContextMenu extends StatelessWidget {
  static const width = 196.0;
  static const itemHeight = 34.0;
  static const _inset = 8.0;

  final Offset anchor;
  final List<(_ShelfContextCommand, IconData, String)> entries;

  const _ShelfContextMenu({required this.anchor, required this.entries});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final size = MediaQuery.sizeOf(context);
    final menuHeight = entries.length * itemHeight + 12;
    final left = anchor.dx
        .clamp(_inset, size.width - width - _inset)
        .toDouble();
    final top = anchor.dy
        .clamp(_inset, size.height - menuHeight - _inset)
        .toDouble();
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: width,
          child: DecoratedBox(
            key: const ValueKey('shelf-context-menu'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.26 : 0.13),
                  blurRadius: 22,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.panel.withValues(alpha: dark ? 0.76 : 0.70),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: p.border.withValues(alpha: dark ? 0.70 : 0.82),
                      width: 0.75,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final entry in entries)
                          _ShelfContextMenuItem(
                            command: entry.$1,
                            icon: entry.$2,
                            label: entry.$3,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

final class _ShelfContextMenuItem extends StatelessWidget {
  final _ShelfContextCommand command;
  final IconData icon;
  final String label;

  const _ShelfContextMenuItem({
    required this.command,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      key: ValueKey('shelf-context-item-${command.name}'),
      height: _ShelfContextMenu.itemHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).pop(command),
          borderRadius: BorderRadius.circular(7),
          hoverColor: p.accentSoft.withValues(alpha: 0.72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            child: Row(
              children: [
                Icon(icon, size: 15, color: p.muted),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.sans(
                      color: p.ink,
                      size: 13,
                      height: 1,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
