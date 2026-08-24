# Shelf Panel

## Purpose and boundary

`ShelfPanel` presents standalone markdowns followed by arrangeable top-level
folders. Each root contains the existing nested folder tree. The
widget receives domain values and reports select, add, remove and move intent;
it never changes the aggregate itself
(`lib/api/widgets/shelf_panel.dart`).

Root order comes from `Library.roots`; nested document and folder order comes
from the domain's [Shelving Rules](../01-domain/02-shelving-rules.md).

## Present wiring

When standalone sources exist, “Markdowns” and their document rows appear
above “Library.” The Library heading offers an add-folder action and its count
describes folders only (`lib/api/widgets/shelf_panel.dart`). Each
standalone row reserves the same quiet action space as a root: its delete icon
appears only on hover, while semantic dismiss remains available. That intent
reports the document id and never reaches disk
(`lib/api/widgets/shelf_panel.dart`). The body is a
stable `ListView`: dragging a root never removes its expanded section from the
shelf, inserts a proxy, or displaces its documents. Only the prospective root
boundary changes while the pointer moves
(`lib/api/widgets/shelf_panel.dart`).

Expansion has two scopes. `_expandedRoots` decides whether one top-level root
shows its tree. `_expandedFolders` keys every nested path by both root id and
path, preventing two `guide/` folders from sharing state
(`lib/api/widgets/shelf_panel.dart`). Removed roots are pruned from both
sets. A newly added root stays minimized even though its opening document is
already in the reader. Later navigation within the existing library reveals
only the selected document's root and ancestors. An explicit expand request
first minimizes every branch in the target root, then opens the root and only
the active document's ancestor chain (`lib/api/widgets/shelf_panel.dart`).

`_RootSection` renders its root row, then recursively emits that root's own
documents and open child folders (`lib/api/widgets/shelf_panel.dart`).
Minimized descendants are not built, which keeps the first frame small for
folders containing hundreds or thousands of markdown files.

The minimized root row is itself the drag surface, so arrangement needs no
permanent handle or action menu. Hover reveals only a delete icon; deletion
means session membership, never a disk operation. Semantics retain arrange and
dismiss actions for assistive navigation
(`lib/api/widgets/shelf_panel.dart`). Its drag feedback is an invisible
one-pixel token, not a copy of the root section. Pointer movement compares the
pointer with stable root-header centres and marks the resulting boundary with a
two-pixel blue line. Edge auto-scroll repeats that calculation as a long shelf
moves beneath the pointer (`lib/api/widgets/shelf_panel.dart`,
`lib/api/widgets/shelf_panel.dart`, `lib/api/widgets/shelf_panel.dart`).

Reordering is one explicit state machine. `idle` accepts a drag; `dragging`
owns the source and current insertion boundary; release enters `settling` and
produces at most one move intent; the frame after release returns to `idle`.
If the active root disappears during a library update, the machine returns to
`idle` immediately (`lib/api/widgets/shelf_reorder_machine.dart`). Root
toggle, remove and semantic arrange actions exist only in `idle`. Keeping them
disabled through `settling` prevents both the active drag recognizer and a tap
captured before the drag threshold from minimizing the root on release
(`lib/api/widgets/shelf_panel.dart`, `lib/api/widgets/shelf_panel.dart`, `lib/api/widgets/shelf_panel.dart`).

Nested folder and document rows retain the quiet existing treatment. Depth
adds a fixed indent; the selected document receives one ground and one weight
change, and README files keep their book icon
(`lib/api/widgets/shelf_panel.dart`).

## Inputs and outputs

| Input | Output |
|-------|--------|
| `Library` | standalone markdowns plus roots and their immutable trees |
| selected `DocumentId?` | marked row; later navigation reveals hidden ancestors |
| add button | `onOpenFolder()` |
| document row | `onSelect(document.id)` |
| standalone hover delete or semantic dismiss | `onRemoveMarkdown(document.id)` |
| root-row drag or semantic arrange action | `onMoveFolder(root.id, index)` |
| hover delete or semantic dismiss action | `onRemoveFolder(root.id)` |

The shell wires these callbacks directly to `ReaderController`
(`lib/api/screens/reader_screen.dart`).

## Events

None. This widget reports intent. Application use cases own successful
mutation and any future events emitted after it.

## Lifecycle

Expansion state is session-local widget state. Adding, arranging or removing a
root preserves expansion for every surviving identity and prunes only removed
identities. A library mutation therefore does not snap unrelated roots shut
(`lib/api/widgets/shelf_panel.dart`).

Widget tests cover standalone placement, hover removal, and the expand contract—including
minimizing an unrelated open branch while revealing the active nested
document—alongside minimized startup, navigation, dragging and hover removal
(`test/presentation/shelf_panel_test.dart`).

## Failure and recovery

The widget cannot delete a disk folder or markdown: it never receives a path or
filesystem adapter. Stale move or remove intent is harmless in the application. Long names
truncate rather than changing panel geometry. An empty aggregate never reaches
the shelf; removing the last folder still leaves it visible when standalone
markdowns remain.

## Transition

Workspace files preserve root order, while expansion remains session-local UI
state. Persisting expansion later would be a separate workspace-format and
interaction decision; the existing durable root identities can support it
without changing the callbacks. A future shelf slot for recents or bookmarks
belongs beside these root sections, not inside their domain ordering.
