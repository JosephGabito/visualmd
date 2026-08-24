# Memory Adapters

The memory adapters provide the parts of Visual MD that can run without a
browser or filesystem. They hold the current library for the life of the
process, route folder references to the right scanner, and supply the bundled
welcome library.

This small family is useful in the app and in tests: the inner rings can be
exercised on the Dart VM without first creating a window or granting file
access.

## On this shelf

| Document | What it introduces | Source |
|----------|--------------------|--------|
| [In-Memory Repository and Routing Scanner](01-in-memory-repository.md) | Session library state and one `FolderScanner` over several sources | `lib/infrastructure/memory/in_memory_library_repository.dart:5`, `lib/infrastructure/routing_folder_scanner.dart:5` |
| [Sample Library](02-sample-library.md) | The bundled “Welcome” folder available on every platform | `lib/infrastructure/memory/sample_folder_scanner.dart:5` |

The composition root shares one `InMemoryLibraryRepository` across the folder
mutation use cases and `ReadDocument` (`lib/main.dart:60-121`). It also places
`SampleFolderScanner` first in the routing list, so the sample's constant
reference is handled before the active platform scanner is consulted
(`lib/main.dart:49-63`).

| Adapter | Application port | Declaration |
|---------|------------------|-------------|
| `InMemoryLibraryRepository` | `LibraryRepository` | `lib/application/ports/library_repository.dart:4-7` |
| `RoutingFolderScanner` | `FolderScanner` | `lib/application/ports/folder_scanner.dart:30-32` |
| `SampleFolderScanner` | `FolderScanner` | `lib/application/ports/folder_scanner.dart:30-32` |

## Why each part exists

The repository keeps the use cases focused on library behavior rather than a
storage technology. Application tests still use a smaller fake repository so
they describe the use case contract directly
(`test/application/use_cases_test.dart:19-27`).

The sample library gives every target a real document to render before a reader
opens local content. It is especially useful when working on typography or the
outline. The routing scanner, meanwhile, lets another folder source join the
application by adding one scanner to the list in `main.dart`; the use cases do
not need to change.

The in-memory repository itself is intentionally session-scoped. Saving and
reopening a workspace is a separate responsibility implemented by the platform
adapters and described in
[Workspace Persistence](../03-workspace-persistence.md). Parsed libraries are
also rebuilt when opened rather than cached between launches; that keeps the
current behavior simple and observable.
