# Platform Adapters

## Purpose and boundary

`PlatformAdapters` gathers everything the composition root needs from the host
platform. Application code receives ports, API code receives platform-neutral
capabilities and geometry, and neither learns which browser or operating system supplied
them (`lib/infrastructure/platform/platform_adapters.dart`).

## Present wiring

`platform.dart` selects web for `dart.library.js_interop`, desktop for
`dart.library.io`, and a stub that reports an unsupported target otherwise
(`lib/infrastructure/platform/platform.dart`). Both families expose one
asynchronous factory. Desktop measures macOS title-bar geometry and locates the
reader's private files before returning
(`lib/infrastructure/platform/platform_io.dart`).

| Capability | Web | Desktop |
|------------|-----|---------|
| source scanners | browser files and handles (`lib/infrastructure/platform/platform_web.dart`) | local files with security scope (`lib/infrastructure/platform/platform_io.dart`) |
| document images | retained browser folder handles and file lists (`lib/infrastructure/platform/platform_web.dart`) | canonical files within an offered source and its security scope (`lib/infrastructure/platform/platform_io.dart`) |
| source changes | five-second metadata checks for rereadable handles (`lib/infrastructure/platform/platform_web.dart`) | native directory events with a five-second failure fallback (`lib/infrastructure/platform/platform_io.dart`) |
| workspace persistence | browser file handles or upload/download, IndexedDB authority (`lib/infrastructure/platform/platform_web.dart`) | native panels, atomic files, local paths/bookmarks (`lib/infrastructure/platform/platform_io.dart`) |
| pickers | browser folder and Markdown pickers (`lib/infrastructure/platform/platform_web.dart`) | native pickers (`lib/infrastructure/platform/platform_io.dart`) |
| drops and drag | document streams (`lib/infrastructure/platform/platform_web.dart`) | desktop drop wrapper (`lib/infrastructure/platform/platform_io.dart`) |
| File commands | empty; Flutter shortcuts remain (`lib/infrastructure/platform/platform_web.dart`) | native menu command stream (`lib/infrastructure/platform/platform_io.dart`) |
| chrome | browser-owned (`lib/infrastructure/platform/platform_web.dart`) | draggable custom macOS top bar; native elsewhere (`lib/infrastructure/platform/platform_io.dart`) |
| preferences and themes | localStorage, built-ins only; no folder action (`lib/infrastructure/platform/platform_web.dart`) | `ReaderFiles`, plus a callback that reveals its theme directory (`lib/infrastructure/platform/platform_io.dart`) |
| shelf source actions | relative-path copying only; browser paths remain private (`lib/infrastructure/platform/platform_web.dart`) | Finder or Explorer reveal plus absolute local paths (`lib/infrastructure/platform/platform_io.dart`) |

The composition root is the sole consumer of the complete interface. It
routes scanners into use cases, Workspace ports into the lifecycle, commands
into the controller, and chrome callbacks into `VisualMdApp`.

## Inputs and outputs

| Direction | Contract | Consumer |
|-----------|----------|----------|
| out | scanners, `DocumentImageLoader`, and `SourceChangeMonitor` | Library mutation, rendering, and synchronization (`lib/main.dart`) |
| out | `WorkspaceFiles`, `WorkspaceSourceAccess` | Workspace lifecycle (`lib/main.dart`) |
| out | pickers and drop streams | controller (`lib/main.dart`) |
| out | `Stream<PlatformCommand>` | native command dispatch (`lib/main.dart`) |
| out | preference strings and theme documents | startup and controller (`lib/main.dart`) |
| out | links, chrome, theme-folder action, and shelf source actions | `VisualMdApp` (`lib/main.dart`) |

Opaque refs flow back into scanners and source-access ports. Concrete paths,
DOM files, bookmarks, and IndexedDB handles do not cross inward.

## Events

Drop, command, and source-change streams are platform input, not domain events.
Source changes are invalidations: adapters never send document bytes inward.

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
