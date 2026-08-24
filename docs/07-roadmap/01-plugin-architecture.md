# Plugin Architecture

Visual MD may eventually grow through a model familiar from WordPress: a small
reader with explicit places where optional behavior can attach. Dart gives
those attachment points concrete types, so contributors can discover them in
code and the dependency direction remains visible.

This document records a direction, not an implemented framework. The current
application has one narrow typed contributor, `CodeHighlighter`, but no plugin
loader, event bus, manifest, registry, or public plugin API.

## Three kinds of plugin

WordPress has actions, filters and admin UI. Visual MD maps them one to one,
with Dart's type system making each hook discoverable.

| WordPress | Visual MD | Answers |
|-----------|-----------|---------|
| `do_action` / `add_action` | **Reactor** — subscribes to a domain event | "something happened" |
| `apply_filters` / `add_filter` | **Contributor** — registers into a typed extension point | "what should this be?" |
| menus, widgets, blocks | **UI slot** — renders into a named place in the shell | "where does this show?" |

### Reactors

The kernel publishes domain events; reactors subscribe. Planned events:
`LibraryOpened(library)` and `DocumentOpened(document)`. The port is an
`EventPublisher` in application/ports; the only implementation is an
in-process bus in infrastructure; subscribers are registered in the
composition root. Use cases publish and do nothing else with the event.

Reactors own side effects and derived state such as indexes or reading history.
They observe a completed action without returning a value into that action, so
the read path does not depend on subscriber order.

### Contributors

Some extensions must *return* a value into the render path — a widget for a
fenced `mermaid` block, or syntax ranges for a `dart` block. Those need a
request-and-response contract rather than a notification. `CodeHighlighter`
is the first concrete example: the composition root injects one implementation
and the kernel falls back to plain source when it returns null
(`lib/presentation/code/code_highlighter.dart`). Registration and competing
contributors do not exist yet.

### UI slots

An enumerated set of places the shell exposes, each with a fixed size and
the house style applied by the shell, not the plugin:

- **Shelf panel** — extra tabs beside the folder tree (recents, search, bookmarks).
- **Top bar actions** — buttons to the right of the title.
- **Reading-pane block** — a custom block within the rendered document.
- **Document footer** — below the last section.
- **Status strip** — a one-line strip at the bottom of the window.

## Proposed constraints

1. **Hooks are typed.** An event is a class, a slot is an
   enum value, a contributor implements an interface. The compiler lists every
   plugin that touches a hook.
2. **Order is declared in one manifest.** When two contributors claim the same
   key, the plugin manifest in the composition root decides — not a priority
   number at the call site.
3. **Plugins depend on public hooks rather than on one another.** Cooperation
   happens through an event or another kernel-owned type, keeping the
   dependency visible.
4. **Dependencies arrive at registration.** Plugins receive what they need
   instead of finding global state.
5. **Domain changes remain domain behavior.** Bookmarks, reading position and
   annotations change the aggregate. They are modelled in
   [the domain](../01-domain/01-library-aggregate.md) with invariants and
   tests; plugins may present or react to those changes.

## Rule of three

The first capabilities should use explicit, minimal extension points. A shared
plugin contract can be extracted only after several real uses reveal which
parts are genuinely common.

First capabilities:

| Plugin | Kind | Hooks |
|--------|------|-------|
| Recents in the shelf | Reactor + slot | `DocumentOpened` → recent list; rendered in the shelf-panel slot |
| Syntax highlighting | Contributor, implemented | fence language → semantic source ranges; plain code remains the fallback |

## Where hooks attach today

Evidence for each attachment point in the current kernel:

- **`LibraryOpened`** could be published after a successful folder mutation,
  once the workspace and library projections have both committed
  (`lib/application/use_cases/add_folder.dart`).
- **`DocumentOpened`** would be published at the end of
  `lib/application/use_cases/read_document.dart`, once the document is
  found.
- **The bus and the manifest** belong in the composition root, next to the
  existing platform and use-case wiring in `lib/main.dart`.
- **Shelf-panel slot** — the shelf column is laid out in
  `lib/api/screens/reader_screen.dart`; a slot could add tabs beside
  `ShelfPanel` there.
- **Code highlighting contributor** — every document is rendered by one
  `DocumentView`, which already consults the injected `CodeHighlighter` for
  fenced source (`lib/api/render/document_view.dart`). A future block-widget
  contributor would be a separate contract for fences such as `mermaid`.
- **Document footer slot** — after `DocumentView`, before the reading column
  closes, in `lib/api/widgets/reading_pane.dart`.
- **Top-bar actions slot** — the action row in `_TopBar`,
  `lib/api/screens/reader_screen.dart`, to the left of the theme
  picker and outline button. The picker is the working precedent: the bar
  takes it as a widget without owning its behavior
  (`lib/api/screens/reader_screen.dart`).
- **Status strip slot** — a new row in the shell's main column,
  `lib/api/screens/reader_screen.dart`.

These are candidate seams visible in the current layout. Their final contracts
should be designed alongside the first capabilities that use them.

## What this preserves

The dependency direction in
[the foundation](../00-foundation/03-dependency-direction.md) stays intact:
events are domain types, the publisher is a port, the bus is infrastructure,
slots are API-owned. The
[architecture test](../09-contributing/02-testing-and-validation.md) keeps
enforcing it, plugins included.
