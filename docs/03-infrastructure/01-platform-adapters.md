# Platform Adapters

## Purpose and boundary

`PlatformAdapters` gathers everything the composition root needs from the host
platform. Application code receives ports, API code receives plain callbacks
and geometry, and neither learns which browser or operating system supplied
them (`lib/infrastructure/platform/platform_adapters.dart:9-55`).

## Present wiring

`platform.dart` selects web for `dart.library.js_interop`, desktop for
`dart.library.io`, and a stub that reports an unsupported target otherwise
(`lib/infrastructure/platform/platform.dart:1-5`). Both families expose one
asynchronous factory. Desktop measures macOS title-bar geometry and locates the
reader's private files before returning
(`lib/infrastructure/platform/platform_io.dart:26-36`).

| Capability | Web | Desktop |
|------------|-----|---------|
| source scanners | browser files and handles (`lib/infrastructure/platform/platform_web.dart:33-43`) | local files with security scope (`lib/infrastructure/platform/platform_io.dart:52-62`) |
| workspace persistence | browser file handles or upload/download, IndexedDB authority (`lib/infrastructure/platform/platform_web.dart:45-54`) | native panels, atomic files, local paths/bookmarks (`lib/infrastructure/platform/platform_io.dart:64-69`) |
| pickers | browser folder and Markdown pickers (`lib/infrastructure/platform/platform_web.dart:56-60`) | native pickers (`lib/infrastructure/platform/platform_io.dart:71-75`) |
| drops and drag | document streams (`lib/infrastructure/platform/platform_web.dart:62-69`) | desktop drop wrapper (`lib/infrastructure/platform/platform_io.dart:77-84`) |
| File commands | empty; Flutter shortcuts remain (`lib/infrastructure/platform/platform_web.dart:71-72`) | native menu command stream (`lib/infrastructure/platform/platform_io.dart:86-87`) |
| chrome | browser-owned (`lib/infrastructure/platform/platform_web.dart:81-88`) | draggable custom macOS top bar; native elsewhere (`lib/infrastructure/platform/platform_io.dart:95-109`) |
| preferences and themes | localStorage, built-ins only (`lib/infrastructure/platform/platform_web.dart:90-103`) | `ReaderFiles` (`lib/infrastructure/platform/platform_io.dart:112-124`) |

The composition root is the sole consumer of the complete interface. It
routes scanners into use cases, Workspace ports into the lifecycle, commands
into the controller, and chrome callbacks into `VisualMdApp`.

## Inputs and outputs

| Direction | Contract | Consumer |
|-----------|----------|----------|
| out | `FolderScanner`, `MarkdownScanner` | Library mutation use cases (`lib/main.dart:79-110`) |
| out | `WorkspaceFiles`, `WorkspaceSourceAccess` | Workspace lifecycle (`lib/main.dart:135-173`) |
| out | pickers and drop streams | controller (`lib/main.dart:175-203`) |
| out | `Stream<PlatformCommand>` | native command dispatch (`lib/main.dart:204-219`) |
| out | preference strings and theme documents | startup and controller (`lib/main.dart:112-134`) |
| out | link and chrome functions | `VisualMdApp` (`lib/main.dart:247-255`) |

Opaque refs flow back into scanners and source-access ports. Concrete paths,
DOM files, bookmarks, and IndexedDB handles do not cross inward.

## Events

None. Drop and command streams are platform input, not domain events.

## Lifecycle

One adapter family is created before the first frame and lives for the process.
Registries preserve ref identity for that run. Durable workspace bindings live
in reader files or IndexedDB rather than relying on process memory.

## Failure and recovery

An unsupported target fails at startup. Picker cancellation returns null.
Expected missing or denied source authority becomes an unavailable Workspace
source. Scanner and write failures cross their application ports and become
visible controller errors; adapters do not silently replace them with empty
content.

## Transition

A new platform family adds one implementation and a conditional export. A
capability used by the application first becomes an inward-facing port; a
capability used only by Flutter can remain a plain platform callback.
