import '../../application/ports/folder_scanner.dart';
import '../../domain/library/library_builder.dart';

/// Adapter: a small bundled library so the reader is never empty-handed.
final class SampleFolderScanner implements FolderScanner {
  static const ref = FolderRef(id: 'sample', name: 'Welcome');

  @override
  Future<ScannedFolder> scan(FolderRef ref) async {
    if (ref != SampleFolderScanner.ref) throw FolderUnavailable(ref);
    return ScannedFolder(name: ref.name, files: _files);
  }

  static const _files = [
    FileEntry('README.md', '''
# Welcome to Visual MD

A quiet place to read Markdown. Open one document, add a folder, or restore a
workspace; everything you bring in settles onto the shelf to your left.

## How it works

1. **Drop Markdown files or folders** anywhere on the window, or use *Open…*.
2. Pick a document from the shelf.
3. Use the **outline** on the right to move through long documents.

Your files stay on your device.

## What you're looking at

This sample library lives inside the app. It has a few documents and a nested
folder so you can see how a real one feels before you bring your own.

> Take a seat. The reading chair is the comfortable one.

"Quotation marks are mostly white space," a typographer will tell you, and a
mark left sitting in the column carves a notch out of the left edge. Notice
that the words above begin exactly where these ones do -- the mark hangs
outside the column, where it belongs.

## Keyboard

| Keys | Does |
|------|------|
| `⌘` / `Ctrl` + `O` | Open Markdown or a folder |
| `⇧⌘O` / `Ctrl+Shift+O` | Open a saved workspace |
| `⌥⌘O` / `Ctrl+Alt+O` | Open this sample library |
| `⌘` / `Ctrl` + `B` | Toggle the shelf |
| `⌘` / `Ctrl` + `.` | Toggle the outline |

## A bit of code, for good measure

```dart
final library = LibraryBuilder.build(name: 'notes', files: files);
print(library.openingDocument?.title); // "Welcome to Visual MD"
```

Now go open something of your own.
'''),
    FileEntry('guide/01-the-shelf.md', '''
---
title: The Shelf
---

# The Shelf

Folders become shelves, documents become books. A few things the shelf does for you:

- Folders with no markdown in them are left out, so the tree stays clean.
- Names sort the way you'd expect: `2-setup` before `10-deploy`.
- A `README` always sits first on its shelf, and the root one opens first.

## Titles

A document is shown by its title — the first `# Heading` or a `title:` in its
front matter. No title? The file name does the job.

## Hidden folders

Dot-prefixed tooling and dependency trees such as `node_modules`, `vendor`,
`venv`, and `Pods` stay out of sight.
'''),
    FileEntry('guide/02-the-outline.md', '''
# The Outline

Every heading in a document lands in the outline on the right. Click one to
go there. As you scroll, the outline follows along.

## Levels

Headings are indented relative to the shallowest level in the document, so a
file that starts at `##` still reads cleanly.

### Deeper

Up to six levels, like markdown itself.

#### And deeper

You get the idea.

## Anchors

Anchors are GitHub-style, so links like `[Levels](#levels)` behave.
'''),
    FileEntry('guide/advanced/reference-links.md', '''
# Reference Links

Some writers keep destinations at the bottom of a file. A [full reference][docs],
a [collapsed reference][], and a [shortcut reference] keep the prose quiet
while remaining ordinary links to the reader.

## [Why mention it?][reason]

The three spellings resolve to one kind of link. Definitions may live before
or after their use, the first duplicate wins, and a missing definition such as
[this missing reference][nowhere] remains visible source rather than becoming a
false action. A reference-linked heading also keeps the same words and anchor
in the page and the outline.

## Automatic links

Angle brackets make a CommonMark URI or email explicit:
<https://visualmd.dev/guide> and <reader@visualmd.dev>. GFM also recognises
https://visualmd.dev/notes, www.visualmd.dev/help, and reader@visualmd.dev in
ordinary prose. Sentence punctuation stays outside each interaction.

## Local navigation

Fragments stay inside the open document. [Visit the first repeated note](#repeated-note)
or [the second one](#repeated-note-1); duplicate headings receive numbered
anchors in source order.

### Repeated note

The first heading owns `repeated-note`.

### Repeated note

The duplicate owns `repeated-note-1`, exactly as shown by the outline's shared
anchor rule.

The page keeps reading after the destination, so following the fragment can
settle the named heading at the top of the pane instead of merely revealing it
at the bottom edge.

That distinction matters when the same words appear twice: the destination
should be obvious before the reader resumes the surrounding prose.

[docs]: https://commonmark.org/help/
[collapsed reference]: https://spec.commonmark.org/0.31.2/#collapsed-reference-link
[shortcut reference]: https://spec.commonmark.org/0.31.2/#shortcut-reference-link
[reason]: https://spec.commonmark.org/0.31.2/#link-reference-definitions
'''),
    FileEntry('guide/advanced/images.md', '''
# Images

An image description is reading text when artwork cannot be shown. A title is
advisory: hover the image to read it without adding another caption to the page.

## Relative artwork

![The Visual MD open-book mark](../../images/visual-md-logo.png "Visual MD")

The artwork keeps its intrinsic square shape, but its 2048-pixel source never
forces the reading column wider than the window.

## Reference image

![The same open-book mark by reference][visual-mark]

Both spellings become the same image run. The definition stays out of the
rendered document, just as it does for a reference link.

## Remote artwork

![The CommonMark mark](https://commonmark.org/help/images/favicon.png)

[visual-mark]: ../../images/visual-md-logo.png "The same Visual MD artwork"
'''),
    FileEntry('guide/advanced/containers.md', '''
# Quotes and Lists

Containers organise prose without changing how prose itself is read. Wrapped
lines keep the body leading; only the relationships between blocks become more
compact.

## Quotations

> A quotation can carry more than one paragraph without turning the entire
> passage italic or shrinking its text.
>
> ## Structure remains structure
>
> - A list can live inside quoted matter.
> - Its markers remain quiet signposts.
>
> > A nested quotation adds one reading-edge rule and no extra ornament.

## Tight and loose lists

- Tight items follow one another as continuously as lines of prose.
- A long item may wrap over several lines while every continuation keeps the
  body's ordinary leading and aligns with the first word rather than the mark.
- Density belongs between items, not between their baselines.

Loose items ask for a visible relationship:

- The first loose item has an opening paragraph.

  Its second paragraph remains part of the same item.

- The next item begins after a restrained half-line interval.

## Ordered, nested, and task lists

7. This sequence starts where its author started it.
8. Its next marker uses the established text edge.

1) Parenthesis delimiters are ordinary ordered lists.
2) Their authoring punctuation does not change their reading hierarchy.

1. A mixed tree begins here.
   - Its unordered child aligns under the parent's text.
     1. An ordered grandchild can contain `code` and **strong text**.
     2. Long wrapping prose keeps its readable measure as the available column
        narrows through the hierarchy.
   - [x] A completed nested task
   - [ ] An incomplete task with [a CommonMark reference](https://spec.commonmark.org/0.31.2/#lists)
2. The parent sequence resumes at the same text edge.

123456789. A nine-digit marker receives the room it actually needs without
           clipping, wrapping, or pushing earlier items onto another edge.

## Deep but valid nesting

- Level one has a long sentence which wraps before its descendants begin, so
  the parent item's continuation and the child's marker cannot share a gutter.
  - Level two
    - Level three
      - Level four
        - Level five
          - Level six
            - Level seven with `code`, **strength**, and the
              [CommonMark nesting rules](https://spec.commonmark.org/0.31.2/#lists)
              1. Ordered level eight
              2. The tree must remain finite, aligned, and reachable

The completed tree returns directly to prose with one ordinary root-level gap.

Repeated Markdown marks remain individually legible: `######`, `===`, and
`---` show every character the author wrote.
'''),
    FileEntry('notes/colophon.md', '''
# Colophon

Choose a serif or sans reading voice; code keeps its own measured mono face.

Paper by day, lamplight by night — that pair follows your system, and the
swatch in the top bar swaps it for something else: Catppuccin, Nord, Gruvbox.

## Bring your own

A theme is a small JSON file — nine colours and three typefaces, no code. Drop
one in the app's themes folder, named in the theme menu, and it appears
alongside the rest. Give it the same `id` as a built-in and it replaces it.

*Built with Flutter, shaped with a hexagonal architecture: domain at the
center, use cases around it, adapters at the edge, and a presentation ring in
between holding the contracts a theme is written against.*
'''),
  ];
}
