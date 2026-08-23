import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visualmd/api/theme/library_theme.dart';
import 'package:visualmd/api/widgets/shelf_panel.dart';
import 'package:visualmd/domain/library/document.dart';
import 'package:visualmd/domain/library/document_id.dart';
import 'package:visualmd/domain/library/library.dart';
import 'package:visualmd/domain/library/library_builder.dart';
import 'package:visualmd/domain/library/library_root_id.dart';
import 'package:visualmd/domain/workspace/workspace.dart';
import 'package:visualmd/domain/workspace/workspace_id.dart';
import 'package:visualmd/domain/workspace/workspace_source.dart';
import 'package:visualmd/domain/workspace/workspace_theme.dart';
import 'package:visualmd/presentation/theme/built_in_themes.dart';

const _notesId = LibraryRootId('notes');
final _notesRoot = LibraryBuilder.buildRoot(
  id: _notesId,
  name: 'notes',
  files: const [
    FileEntry('README.md', '# Notes'),
    FileEntry('guide/README.md', '# Guide'),
    FileEntry('guide/setup.md', '# Setup'),
    FileEntry('guide/advanced/internals.md', '# Internals'),
    FileEntry('reference/api.md', '# API'),
  ],
);
final _library = Library(roots: [_notesRoot]);

void main() {
  Widget shelf({
    Library? library,
    DocumentId? selected,
    ValueChanged<LibraryRootId>? onRemove,
    ValueChanged<DocumentId>? onRemoveMarkdown,
    void Function(LibraryRootId, int)? onMove,
    ({DocumentId id, int revision})? expandRequest,
    ValueChanged<DocumentId>? onSelect,
    Workspace? workspace,
    Set<WorkspaceSourceId> unavailableSources = const {},
    ValueChanged<WorkspaceSourceId>? onReconnectSource,
    ValueChanged<WorkspaceSourceId>? onRemoveUnavailableSource,
  }) => MaterialApp(
    theme: libraryTheme(BuiltInThemes.paper),
    home: Scaffold(
      body: SizedBox(
        width: 320,
        child: ShelfPanel(
          library: library ?? _library,
          selected: selected ?? DocumentId(_notesId, 'README.md'),
          onSelect: onSelect ?? (_) {},
          onOpenFolder: () {},
          onRemoveFolder: onRemove ?? (_) {},
          onRemoveMarkdown: onRemoveMarkdown ?? (_) {},
          onMoveFolder: onMove ?? (_, _) {},
          expandRequest: expandRequest,
          workspace: workspace,
          unavailableSources: unavailableSources,
          onReconnectSource: onReconnectSource,
          onRemoveUnavailableSource: onRemoveUnavailableSource,
        ),
      ),
    ),
  );

  testWidgets('a newly added root starts minimized despite its open document', (
    tester,
  ) async {
    await tester.pumpWidget(shelf());

    expect(find.text('notes'), findsOneWidget);
    expect(find.text('Notes'), findsNothing);
    expect(find.text('guide'), findsNothing);
    expect(find.text('reference'), findsNothing);
    expect(find.text('Guide'), findsNothing);
  });

  testWidgets('standalone markdowns sit above the folder library', (
    tester,
  ) async {
    final markdown = Document(
      id: DocumentId(
        const LibraryRootId('standalone-markdown:plan'),
        'plan.md',
      ),
      content: '# Build plan',
    );
    DocumentId? selected;
    await tester.pumpWidget(
      shelf(
        library: Library(roots: [_notesRoot], markdowns: [markdown]),
        onSelect: (id) => selected = id,
      ),
    );

    expect(find.text('MARKDOWNS'), findsOneWidget);
    expect(find.text('LIBRARY'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('MARKDOWNS')).dy,
      lessThan(tester.getTopLeft(find.text('LIBRARY')).dy),
    );
    expect(find.text('Build plan'), findsOneWidget);
    await tester.tap(find.text('Build plan'));
    expect(selected, markdown.id);
  });

  testWidgets('standalone markdowns reveal remove only on hover', (
    tester,
  ) async {
    final markdown = Document(
      id: DocumentId(
        const LibraryRootId('standalone-markdown:plan'),
        'plan.md',
      ),
      content: '# Build plan',
    );
    DocumentId? selected;
    DocumentId? removed;
    await tester.pumpWidget(
      shelf(
        library: Library(roots: [_notesRoot], markdowns: [markdown]),
        onSelect: (id) => selected = id,
        onRemoveMarkdown: (id) => removed = id,
      ),
    );

    expect(find.byIcon(Icons.delete_outline), findsNothing);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Build plan')));
    await tester.pump();
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await tester.tap(find.byTooltip('Remove from Markdowns'));

    expect(removed, markdown.id);
    expect(selected, isNull);
    await mouse.removePointer();
  });

  testWidgets(
    'an unavailable source keeps its slot and offers reconnect or remove',
    (tester) async {
      final missing = WorkspaceSource(
        id: const WorkspaceSourceId('missing'),
        displayName: 'Missing handbook',
        relativePath: 'Missing handbook',
      );
      final live = WorkspaceSource(
        id: const WorkspaceSourceId('notes'),
        displayName: 'notes',
        relativePath: 'notes',
      );
      final workspace = Workspace(
        id: const WorkspaceId('workspace'),
        documentRootAbsolutePath: '/work',
        theme: const FixedWorkspaceTheme('paper'),
        folders: [missing, live],
      );
      WorkspaceSourceId? reconnected;
      WorkspaceSourceId? removed;

      await tester.pumpWidget(
        shelf(
          workspace: workspace,
          unavailableSources: {missing.id},
          onReconnectSource: (id) => reconnected = id,
          onRemoveUnavailableSource: (id) => removed = id,
        ),
      );

      expect(find.text('2 folders · 5 documents'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Missing handbook')).dy,
        lessThan(tester.getTopLeft(find.text('notes')).dy),
      );
      await tester.tap(find.text('Missing handbook'));
      expect(reconnected, missing.id);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Missing handbook')));
      await tester.pump();
      await tester.tap(find.byTooltip('Remove from workspace'));
      expect(removed, missing.id);
      await mouse.removePointer();
    },
  );

  testWidgets(
    'expand reveals the active path and minimizes unrelated branches',
    (tester) async {
      await tester.pumpWidget(shelf());
      await tester.tap(find.text('notes'));
      await tester.pump();
      await tester.tap(find.text('guide'));
      await tester.pump();
      await tester.tap(find.text('reference'));
      await tester.pump();
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Setup'), findsOneWidget);
      expect(find.text('API'), findsOneWidget);

      final active = DocumentId(_notesId, 'guide/advanced/internals.md');
      await tester.pumpWidget(
        shelf(selected: active, expandRequest: (id: active, revision: 1)),
      );

      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('guide'), findsOneWidget);
      expect(find.text('Setup'), findsOneWidget);
      expect(find.text('advanced'), findsOneWidget);
      expect(find.text('Internals'), findsOneWidget);
      expect(find.text('reference'), findsOneWidget);
      expect(find.text('API'), findsNothing);
    },
  );

  testWidgets(
    'a folder expands and minimizes without disturbing its siblings',
    (tester) async {
      await tester.pumpWidget(shelf());

      await tester.tap(find.text('notes'));
      await tester.pump();

      await tester.tap(find.text('guide'));
      await tester.pump();
      expect(find.text('Guide'), findsOneWidget);
      expect(find.text('Setup'), findsOneWidget);
      expect(find.text('advanced'), findsOneWidget);
      expect(find.text('Internals'), findsNothing);
      expect(find.text('API'), findsNothing);

      await tester.tap(find.text('guide'));
      await tester.pump();
      expect(find.text('Guide'), findsNothing);
      expect(find.text('Setup'), findsNothing);
      expect(find.text('advanced'), findsNothing);
    },
  );

  testWidgets('navigating opens only the selected document ancestors', (
    tester,
  ) async {
    await tester.pumpWidget(shelf());
    await tester.pumpWidget(
      shelf(selected: DocumentId(_notesId, 'guide/advanced/internals.md')),
    );

    expect(find.text('Guide'), findsOneWidget);
    expect(find.text('Setup'), findsOneWidget);
    expect(find.text('advanced'), findsOneWidget);
    expect(find.text('Internals'), findsOneWidget);
    expect(find.text('API'), findsNothing);
  });

  testWidgets('navigating to a hidden document reveals its location', (
    tester,
  ) async {
    await tester.pumpWidget(shelf());
    expect(find.text('Internals'), findsNothing);

    await tester.pumpWidget(
      shelf(selected: DocumentId(_notesId, 'guide/advanced/internals.md')),
    );

    expect(find.text('guide'), findsOneWidget);
    expect(find.text('advanced'), findsOneWidget);
    expect(find.text('Internals'), findsOneWidget);
  });

  testWidgets(
    'replacing every root discards expansion owned by removed roots',
    (tester) async {
      await tester.pumpWidget(shelf());
      await tester.tap(find.text('notes'));
      await tester.pump();
      await tester.tap(find.text('guide'));
      await tester.pump();
      expect(find.text('Setup'), findsOneWidget);

      final replacement = Library(
        roots: [
          LibraryBuilder.buildRoot(
            id: const LibraryRootId('replacement'),
            name: 'replacement',
            files: const [
              FileEntry('README.md', '# Replacement'),
              FileEntry('guide/new.md', '# New document'),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        shelf(
          library: replacement,
          selected: DocumentId(const LibraryRootId('replacement'), 'README.md'),
        ),
      );

      expect(find.text('replacement'), findsOneWidget);
      expect(find.text('Replacement'), findsNothing);
      expect(find.text('guide'), findsNothing);
      expect(find.text('New document'), findsNothing);
    },
  );

  testWidgets('root rows drag directly and reveal remove only on hover', (
    tester,
  ) async {
    const guidesId = LibraryRootId('guides');
    final library = Library(
      roots: [
        _notesRoot,
        LibraryBuilder.buildRoot(
          id: guidesId,
          name: 'guides',
          files: const [FileEntry('README.md', '# Guides')],
        ),
      ],
    );
    (LibraryRootId, int)? moved;
    LibraryRootId? removed;
    await tester.pumpWidget(
      shelf(
        library: library,
        onMove: (id, index) => moved = (id, index),
        onRemove: (id) => removed = id,
      ),
    );

    expect(find.text('notes'), findsOneWidget);
    expect(find.text('guides'), findsOneWidget);
    expect(find.byIcon(Icons.drag_indicator), findsNothing);
    expect(find.byIcon(Icons.more_horiz), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    await tester.tap(find.text('notes'));
    await tester.pump();
    final pendingRootClick = tester
        .widget<InkWell>(find.byKey(const ValueKey('root-toggle-notes')))
        .onTap!;
    final notesPosition = tester.getTopLeft(find.text('notes'));
    final guidesPosition = tester.getTopLeft(find.text('guides'));

    final drag = await tester.startGesture(
      tester.getCenter(find.text('notes')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await drag.moveBy(const Offset(0, 90));
    await tester.pump(const Duration(milliseconds: 16));
    await drag.moveBy(const Offset(0, 90));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('library-drop-indicator')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('library-drag-feedback')), findsOneWidget);
    expect(find.byKey(const ValueKey('library-drag-proxy')), findsNothing);
    expect(tester.getTopLeft(find.text('notes')), notesPosition);
    expect(tester.getTopLeft(find.text('guides')), guidesPosition);
    pendingRootClick();
    await tester.pump();
    expect(find.text('Notes'), findsOneWidget);

    await drag.up();
    pendingRootClick();
    await drag.removePointer();
    await tester.pumpAndSettle();
    expect(moved, (_notesId, 1));
    expect(find.text('Notes'), findsOneWidget);
    expect(find.byKey(const ValueKey('library-drop-indicator')), findsNothing);
    await tester.tap(find.text('notes'));
    await tester.pump();
    expect(find.text('Notes'), findsNothing);
    await tester.tap(find.text('notes'));
    await tester.pump();
    expect(find.text('Notes'), findsOneWidget);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('notes')));
    await tester.pump();
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await tester.tap(find.byTooltip('Remove from library'));
    expect(removed, _notesId);
    await mouse.removePointer();
  });

  testWidgets('a no-op drop also restores the folder click', (tester) async {
    const guidesId = LibraryRootId('guides');
    final library = Library(
      roots: [
        _notesRoot,
        LibraryBuilder.buildRoot(
          id: guidesId,
          name: 'guides',
          files: const [FileEntry('README.md', '# Guides')],
        ),
      ],
    );
    (LibraryRootId, int)? moved;
    await tester.pumpWidget(
      shelf(library: library, onMove: (id, index) => moved = (id, index)),
    );
    await tester.tap(find.text('notes'));
    await tester.pump();
    final pendingRootClick = tester
        .widget<InkWell>(find.byKey(const ValueKey('root-toggle-notes')))
        .onTap!;

    final drag = await tester.startGesture(
      tester.getCenter(find.text('notes')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await drag.moveBy(const Offset(0, 20));
    await tester.pump();
    expect(find.byKey(const ValueKey('library-drag-feedback')), findsOneWidget);
    await drag.moveBy(const Offset(0, -20));
    await tester.pump();
    pendingRootClick();
    await tester.pump();
    expect(find.text('Notes'), findsOneWidget);

    await drag.up();
    pendingRootClick();
    await drag.removePointer();
    await tester.pumpAndSettle();
    expect(moved, isNull);
    await tester.tap(find.text('notes'));
    await tester.pump();
    expect(find.text('Notes'), findsNothing);
  });

  testWidgets('dragging a minimized root never expands it', (tester) async {
    await tester.pumpWidget(shelf());
    expect(find.text('Notes'), findsNothing);

    final drag = await tester.startGesture(
      tester.getCenter(find.text('notes')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await drag.moveBy(const Offset(0, 40));
    await tester.pump();
    await drag.up();
    await drag.removePointer();
    await tester.pumpAndSettle();

    expect(find.text('Notes'), findsNothing);
  });

  testWidgets('dragging one minimized root preserves every minimized sibling', (
    tester,
  ) async {
    const guidesId = LibraryRootId('guides');
    final guidesRoot = LibraryBuilder.buildRoot(
      id: guidesId,
      name: 'guides',
      files: const [FileEntry('README.md', '# Guides')],
    );
    final library = Library(roots: [_notesRoot, guidesRoot]);
    (LibraryRootId, int)? moved;
    await tester.pumpWidget(
      shelf(library: library, onMove: (id, index) => moved = (id, index)),
    );
    await tester.tap(find.text('notes'));
    await tester.tap(find.text('guides'));
    await tester.pump();
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Guides'), findsOneWidget);

    final drag = await tester.startGesture(
      tester.getCenter(find.text('notes')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await drag.moveBy(const Offset(0, 160));
    await tester.pump();
    await drag.up();
    await drag.removePointer();
    await tester.pumpAndSettle();
    expect(moved, (_notesId, 1));
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Guides'), findsOneWidget);

    await tester.pumpWidget(
      shelf(library: Library(roots: [guidesRoot, _notesRoot])),
    );
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Guides'), findsOneWidget);
  });

  testWidgets('library mutations preserve every surviving expansion', (
    tester,
  ) async {
    const guidesId = LibraryRootId('guides');
    const archiveId = LibraryRootId('archive');
    final guidesRoot = LibraryBuilder.buildRoot(
      id: guidesId,
      name: 'guides',
      files: const [FileEntry('README.md', '# Guides')],
    );
    final archiveRoot = LibraryBuilder.buildRoot(
      id: archiveId,
      name: 'archive',
      files: const [FileEntry('README.md', '# Archive')],
    );

    await tester.pumpWidget(
      shelf(library: Library(roots: [_notesRoot, guidesRoot])),
    );
    await tester.tap(find.text('notes'));
    await tester.tap(find.text('guides'));
    await tester.pump();
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Guides'), findsOneWidget);

    await tester.pumpWidget(
      shelf(
        library: Library(roots: [_notesRoot, guidesRoot, archiveRoot]),
        selected: DocumentId(archiveId, 'README.md'),
      ),
    );
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Guides'), findsOneWidget);
    expect(find.text('Archive'), findsNothing);

    await tester.pumpWidget(
      shelf(
        library: Library(roots: [guidesRoot, _notesRoot, archiveRoot]),
        selected: DocumentId(archiveId, 'README.md'),
      ),
    );
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Guides'), findsOneWidget);
    expect(find.text('Archive'), findsNothing);

    await tester.pumpWidget(
      shelf(
        library: Library(roots: [guidesRoot, _notesRoot]),
        selected: DocumentId(_notesId, 'README.md'),
      ),
    );
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Guides'), findsOneWidget);
  });
}
