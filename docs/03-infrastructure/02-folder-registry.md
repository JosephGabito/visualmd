# Folder Registry

## Purpose and boundary

A platform hands the app a folder as something specific to that platform — a
browser directory handle, a list of picked `File`s, or a filesystem path with
a macOS security bookmark. The application still needs to say “open *that*
one” without carrying any of those platform types.
`FolderRegistry<T>` is the exchange desk: it keeps the platform handle and
issues an opaque `FolderRef` in its place
(`lib/infrastructure/folder_registry.dart:3-26`).

The boundary is the `FolderRef` itself: an id and a display name, nothing
else (`lib/application/ports/folder_scanner.dart:5-19`). Handles stay out of
`application/`; they are looked up again only by the scanner of the same
family. See [Ports](../02-application/03-ports.md) for the application side of
the boundary.

## Present wiring

| Member | Behaviour | Evidence |
|--------|-----------|----------|
| `FolderRegistry(prefix)` | keeps one handle map for an adapter family | `lib/infrastructure/folder_registry.dart:7-12` |
| `register(name, handle)` | stores an anonymous handle under a fresh, hard-to-collide opaque id | `lib/infrastructure/folder_registry.dart:28-36`, `lib/infrastructure/opaque_ids.dart:3-15` |
| `register(name, handle, identity:)` | refreshes the existing id and handle when stable session identity is known | `lib/infrastructure/folder_registry.dart:28-36` |
| `register(name, handle, preferredId:)` | restores a workspace source under its durable source id | `lib/infrastructure/folder_registry.dart:20-27` |
| `lookup(ref)` | returns the latest handle for `ref.id`, or `null` | `lib/infrastructure/folder_registry.dart:46` |

Each family declares a typedef over its own handle type and creates one
registry with its own prefix:

| Typedef | Handle type | Created at |
|---------|-------------|------------|
| `BrowserFolderRegistry` — `lib/infrastructure/web/browser_folder.dart:41` | `BrowserFolder` (`HandleDirectory`, `DroppedDirectory`, `PickedFiles`) — `lib/infrastructure/web/browser_folder.dart:6-38` | `BrowserFolderRegistry('browser')` — `lib/infrastructure/platform/platform_web.dart:26` |
| `LocalFolderRegistry` — `lib/infrastructure/io/local_folder.dart:31` | `LocalFolder` (`LocalDirectory`, `LocalFiles`) — `lib/infrastructure/io/local_folder.dart:6-29` | `LocalFolderRegistry('local')` — `lib/infrastructure/platform/platform_io.dart:42` |

Producers call `register`: the web drop (`lib/infrastructure/web/browser_folder_drop.dart:64-76`),
the web picker (`lib/infrastructure/web/browser_folder_picker.dart:17-25`,
`:50-64`), the desktop drop
(`lib/infrastructure/io/desktop_folder_drop.dart:47-53`) and the desktop picker
(`lib/infrastructure/io/desktop_folder_picker.dart:13-21`).
Consumers call `lookup`: the two scanners
(`lib/infrastructure/web/browser_folder_scanner.dart:24-26`,
`lib/infrastructure/io/local_folder_scanner.dart:22-24`). Workspace restoration
also uses `preferredId` so the runtime ref matches the source id stored in the
workspace (`lib/infrastructure/web/browser_workspace_source_access.dart:84-106`,
`lib/infrastructure/io/desktop_workspace_source_access.dart:99-119`).

The sample library does not use a registry at all; its ref is a constant
(`lib/infrastructure/memory/sample_folder_scanner.dart:6`), and the
`RoutingFolderScanner` routes by trying scanners in turn rather than by
inspecting the id (`lib/infrastructure/routing_folder_scanner.dart:11-19`).

## Inputs and outputs

| Direction | What | Notes |
|-----------|------|-------|
| in | `name`, handle `T`, optional identity or preferred id | `T extends Object`; the registry treats the handle as opaque |
| out | `FolderRef` | equality is by `id` only (`lib/application/ports/folder_scanner.dart:11-15`) |
| in | `FolderRef` | from the use case, via the scanner |
| out | `T?` | `null` when the ref belongs to another family or was never issued |

## Events

None. A future library event could safely carry the `FolderRef` because it
contains no platform handle.

## Lifecycle

One registry per family is kept for the process. Entries are not currently
evicted.
Desktop paths are registered with a normalised identity, so picking or dropping
the same directory refreshes one root and its latest sandbox handle
(`lib/infrastructure/io/local_folder.dart:41-43`). Browser handles and loose
file groups are not currently assigned a cross-drop identity. Workspace restore
reconnects a newly obtained or persisted handle to the source's
existing id rather than persisting the process-local registry itself.

## Failure and recovery

- `lookup` returning `null` means the registry does not have that ref. Each
  scanner turns it
  into `FolderUnavailable(ref)` (`lib/infrastructure/web/browser_folder_scanner.dart:26`,
  `lib/infrastructure/io/local_folder_scanner.dart:24`), which
  `RoutingFolderScanner` treats as "not mine, ask the next one"
  (`lib/infrastructure/routing_folder_scanner.dart:13-17`).
- The test suite exercises stable refresh and anonymous append directly
  (`test/infrastructure/folder_registry_test.dart:6-21`), along with restored
  ids and legacy-id reuse (`test/infrastructure/folder_registry_test.dart:24-74`).

## Transition

Durability already lives beside the registry: desktop stores paths and
bookmarks, while capable browsers store permission-bearing handles. The
workspace keeps the stable source id and the adapter re-registers the local
handle when reopening it. Registry eviction is unnecessary at normal reader
scale; it can be added if measurement shows long sessions accumulating a
meaningful number of replaced handles.
