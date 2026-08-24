# 0007 — Plugins as Typed Hooks

Status: Accepted as direction · not yet implemented · 2026-08-22

Persistence note: [0008 — Workspace as the Durable Unit](0008-workspace-as-durable-unit.md)
supersedes this record's earlier “remember last folder” reactor direction.
Plugin typing remains accepted.

## Context

When this direction was recorded, the reader's centre — open a folder, shelve
it, and read with an outline — was already small and coherent. Candidate
extensions included recent documents, syntax highlighting, diagrams, images,
and bookmarks. Search and durable workspaces have since landed as kernel
behavior rather than plugins.

WordPress provides a familiar reference for a small core with extension hooks
and decades of practical use. It also shows the design risks to avoid:
string-named hooks are difficult to trace, priority numbers can hide ordering
dependencies, and plugins can become coupled through shared global state.

There is also a risk in building a plugin *framework* before real extensions
have shown which abstractions they share.

## Decision

Three kinds of plugin, all typed, all attached at the composition root:

| WordPress | Visual MD | Shape |
|-----------|-----------|-------|
| `do_action` / `add_action` | domain **events** → **reactors** | Use cases publish typed event objects (`LibraryOpened`, `DocumentOpened`) through an `EventPublisher` port; reactors subscribe. Fire-and-forget; for side effects, state, persistence, indexes. |
| `apply_filters` / `add_filter` | **extension points** → **contributors** | A typed registry the kernel consults for a value, e.g. "who renders `mermaid` fences?". Synchronous, ordered, returns a value. |
| admin menus, widgets, blocks | **UI slots** | Named, enumerated places in the shell (shelf panel, top-bar actions, reading-pane block, document footer, status strip) a plugin may render into. |

Proposed constraints:

- Hooks are types, not strings: an event is a class, a slot is an enum
  member, a contributor implements an interface. The compiler lists every
  plugin that touches a hook.
- Contributor order is declared once, in a plugin manifest, not at each
  registration site.
- A plugin depends on the kernel's public contract and events rather than on
  another plugin. Cooperation goes through a kernel-owned type so the
  dependency remains visible.
- A plugin receives its dependencies at registration instead of reading global
  state.
- Features that *write into the aggregate* — bookmarks, reading position,
  annotations — are new domain behavior and are modelled there.
- Rule of three: the first two plugins are built through explicit extension
  points; the plugin contract is extracted only when the third makes the
  shape obvious.

## Consequences

- The kernel never imports a plugin. Adding one is a line in `main.dart`.
- Events answer "what happened"; they do not answer "what should this look
  like". Routing rendering through events would hide output ordering in
  asynchronous subscribers, so rendering goes through contributors instead.
- Until the first reactor exists there is no event bus in the code. Workspace
  persistence is now kernel behavior under 0008; recent documents remains the
  first likely reactor and shelf-slot combination.
- The `PlatformAdapters` interface already demonstrates the pattern at the
  infrastructure edge: capabilities arrive through `main.dart` as typed
  values, and the UI consumes them without knowing their source.

## Evidence

This record describes a direction; there is no plugin code to cite. The
places the first plugins will attach are visible today:

- Where an `EventPublisher` port will sit alongside the existing ports: `lib/application/ports/folder_scanner.dart`, `lib/application/ports/library_repository.dart`.
- The use cases that will publish folder-mutation and `DocumentOpened` events:
  `lib/application/use_cases/add_folder.dart`,
  `lib/application/use_cases/read_document.dart`.
- The precedent for typed capabilities crossing the composition root: `lib/api/app.dart`, `lib/main.dart`.
- The written plan: [Plugin Architecture](../07-roadmap/01-plugin-architecture.md).
