# Shelving Rules

## Purpose and boundary

`LibraryBuilder.buildRoot` is the single place that turns one flat folder scan
into a `LibraryRoot` (`lib/domain/library/library_builder.dart:21-62`). It owns
every decision about what goes on the shelf and in what order. Adapters hand
it `FileEntry(path, content)` pairs
(`lib/domain/library/library_builder.dart:11-18`) and nothing else; they do
not sort, prune or filter — even when they skip non-markdown files early to
save I/O, they are applying this module's rules, not their own.

## Present wiring

The builder walks the input once and assembles a tree of private `_Node`s,
then converts the tree to immutable `Folder`s:

1. **Markdown only.** A file whose name lacks one of the recognised
   extensions is skipped (`lib/domain/library/library_builder.dart:34`).
   The extension set is `.md`, `.markdown`, `.mdown`, `.mkd`, compared
   case-insensitively (`lib/domain/library/markdown_file.dart:3-9`).
2. **Hidden folders.** A path with any *folder* segment that starts with `.`
   or has a recognised dependency/runtime-tree name is skipped
   (`lib/domain/library/library_builder.dart:35`,
   `lib/domain/library/hidden_folders.dart:3-35`). The fixed names cover Node,
   Python, PHP/Go, CocoaPods/Carthage and legacy browser package trees. Generic
   names such as `build`, `dist`, `out`, and `target` remain visible because
   they can contain authored documentation. The file name itself is never
   tested, so `.hidden.md` at the root is shelved.
3. **Duplicates keep the first.** Paths are normalised into a root-scoped `DocumentId`;
   a second entry with the same id is ignored
   (`lib/domain/library/library_builder.dart:36-37`).
4. **Folders are created on demand** for each segment above the file
   (`lib/domain/library/library_builder.dart:39-50`).
5. **Empty folders are pruned.** When converting, any sub-folder with a
   `documentCount` of zero is dropped
   (`lib/domain/library/library_builder.dart:73-79`). Because pruning happens
   after recursion, a folder whose only content is deeper empty folders is
   pruned too.
6. **Natural order.** Folders sort by name and documents by file name using
   `NaturalOrder.compare`: case-insensitive, with digit runs compared as
   numbers (`lib/domain/library/natural_order.dart:6-17`), so `2-setup`
   precedes `10-deploy`.
7. **README first.** Within a folder, READMEs sort before everything else,
   then natural order applies (`lib/domain/library/library_builder.dart:81-85`).

## Inputs and outputs

| Input paths (in arrival order) | Resulting tree |
|--------------------------------|----------------|
| `10-deploy.md`, `2-setup.md`, `README.md`, `1-intro.md`, `Zebra.md`, `apple.md` | root: `README.md`, `1-intro.md`, `2-setup.md`, `10-deploy.md`, `apple.md`, `Zebra.md` |
| `README.md`, `assets/logo.png`, `guide/intro.markdown`, `guide/images/diagram.svg` | root: `README.md`; `guide/`: `intro.markdown` — `assets/` and `guide/images/` never built |
| `01-system-wiring/a.md`, `00-foundation/b.md`, `00-foundation/deep/er/c.md` | `00-foundation/` (`b.md`, `deep/er/c.md`) before `01-system-wiring/` (`a.md`) |
| `a\b.md` (content "first"), `/a/b.md` (content "second") | `a/`: one document `b.md` with content "first" |
| `notes/.git/x.md`, `notes/.drafts/y.md`, `node_modules/p/README.md`, `vendor/p/README.md`, `notes/z.md` | `notes/`: `z.md` only |
| `a.txt` | an empty root (`documentCount` is zero, `openingDocument` is `null`) |

Rows one to four and six are the exact fixtures of
`test/domain/library_builder_test.dart:23-44`, `:7-21`, `:46-64`, `:84-94`
and `:146-153`; row five is covered by `:108-144`.

## Events

None today. The builder is a pure function. If folder events are introduced,
they belong to [Library Mutations](../02-application/01-library-mutations.md),
where scanning and persistence complete.

## Lifecycle

Called once per add, refresh, or workspace restoration. It runs synchronously
over an in-memory list and keeps no state between calls (`abstract final class`
with a static method, `lib/domain/library/library_builder.dart:24-25`). Large
folder performance should be judged with representative scans rather than an
assumed file-count threshold.

## Failure and recovery

- Unwanted file types and hidden paths are skipped rather than rejected. A
  retained entry is normalized into a `DocumentId` before its `Document` is
  constructed (`lib/domain/library/library_builder.dart:33-58`).
- An input with no markdown yields an empty library rather than an error; the
  UI shows an empty state (`test/domain/library_builder_test.dart:157-167`).

## Transition

- Adding a file type (`.mdx`, `.txt`) is one entry in
  `lib/domain/library/markdown_file.dart:3`; every adapter and the builder
  follow automatically.
- Hidden-folder names are a fixed set today
  (`lib/domain/library/hidden_folders.dart:9-22`). A user-editable ignore list
  would become a parameter of `buildRoot`, still decided here.
- Ordering is global. A per-folder `_order` file or front-matter `order:` key
  would be read by the builder, not by the shelf widget.
