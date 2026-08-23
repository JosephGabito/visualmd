# Sample Library

## Purpose and boundary

A small library bundled in source so the reader is never empty-handed: it
is what "browse the sample library" opens on the welcome screen and what
`?open=sample` opens on the web
(`lib/infrastructure/memory/sample_folder_scanner.dart:4-5`,
`lib/api/reader_controller.dart:239`, `lib/main.dart:194`,
`lib/main.dart:222-225`). It is also the
fastest way to see every feature the renderer supports in one place.

It is an adapter like any other: it implements `FolderScanner` and returns
`FileEntry`s; the domain shelves them exactly as it would a dropped folder.

## Present wiring

| Member | Behaviour | Evidence |
|--------|-----------|----------|
| `SampleFolderScanner.ref` | the constant `FolderRef(id: 'sample', name: 'Welcome')` | `lib/infrastructure/memory/sample_folder_scanner.dart:6` |
| `scan(ref)` | throws `FolderUnavailable` unless `ref == SampleFolderScanner.ref`; otherwise returns `ScannedFolder('Welcome', _files)` | `:8-12` |
| `_files` | five `FileEntry`s, written as Dart multi-line strings | `:14-134` |

The ref reaches the controller as `sampleFolder` (`lib/main.dart:176-200`) and
the scanner sits first in the `RoutingFolderScanner` list (`lib/main.dart:57-60`),
so it is consulted before any platform scanner. See
[In-Memory Repository and Routing Scanner](01-in-memory-repository.md).

## Inputs and outputs

The bundled documents and what each one exercises:

| Path | Demonstrates | Evidence |
|------|--------------|----------|
| `README.md` | root README opens first; h2 outline; ordered list; blockquote; a paragraph opening with a quotation, so the hung mark is visible; a table; a fenced `dart` code block | `lib/infrastructure/memory/sample_folder_scanner.dart:15-56` |
| `guide/01-the-shelf.md` | YAML front matter with `title: The Shelf`; numbered file ordering; bullet lists | `:57-78` |
| `guide/02-the-outline.md` | headings to four levels; outline indentation relative to the shallowest level; an anchor-link example | `:79-101` |
| `guide/advanced/reference-links.md` | a second level of nesting; a reference-style link whose definition is at the bottom of the file | `:102-115` |
| `notes/colophon.md` | a second top-level shelf; emphasis, and a heading below the title | `:116-133` |

The resulting shelf has two folders at the root (`guide`, `notes`), one
nested folder (`guide/advanced`) and five documents — the count shown under
the shelf heading.

## Events

None. Opening the sample follows the same `AddFolder` use case as any other
folder, so application behavior stays consistent.

## Lifecycle

Stateless and constant; the content ships inside the binary and cannot be
edited by the reader.

## Failure and recovery

- Any ref other than the sample's is declined with `FolderUnavailable`, so
  the router moves on (`:10`).
- Because the same content is available everywhere, it is a useful visual
  check after changing typography, outlines, tables, or code blocks.

## Transition

The sample is intentionally short and representative rather than a second
manual. If it grows enough to become hard to maintain as Dart strings, it can
move to bundled assets behind the same `FolderScanner` port without changing
the welcome flow.
