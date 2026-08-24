# Code Block

## Purpose and boundary

`ReadableCodeBlock` renders fenced code so it can be read
(`lib/api/widgets/code_block.dart`). It exists because prose and code want
opposite things from a column.

The reading column is sized for prose — about 66 characters, see
[Reading Scale](../04-presentation/07-reading-scale.md) — and that is right for
sentences. Code is not sentences. It is written in lines of its own length, and
neither breaking them nor clipping them is harmless: a re-wrapped line changes
what the code appears to say, and a clipped one hides it. So this block scrolls
sideways instead.

It owns layout and scrolling only. It does not colour code: syntax highlighting
is a separate scope with its own entry in the
[backlog](../07-roadmap/02-backlog.md).

## Present wiring

A plain widget, built by [Document View](12-document-view.md) for every
`CodeBlock` in the document
(`lib/api/render/document_view.dart`), which supplies the mono style
and the padding and decoration derived from the theme and the palette — so a
code block is themed like everything else.

It is laid out at `wideWidth` rather than `proseWidth`
(`lib/api/render/document_view.dart`): code is given about a third more
room than prose before it has to scroll at all.

The `SizedBox` around each block is a fixed width, not a maximum, so the code
block is a band across the page rather than a label wrapped around its shortest
line (`lib/api/render/document_view.dart`).

**It sits on the beat, and it has no border.** Each line of code is set to
exactly one beat (`lib/api/render/reading_theme.dart`,
`lib/api/render/reading_theme.dart`) and the padding
is half a beat above and below
(`lib/api/render/document_view.dart`), so the whole block comes to a
whole number of beats and the prose beneath it resumes on the grid — see
[Vertical Rhythm](../04-presentation/11-vertical-rhythm.md). The border it used
to carry is gone (`lib/api/render/document_view.dart`): the block's own
ground already says what it is, so a border was a second signal, and it had a
height that broke the grid.

The block itself (`lib/api/widgets/code_block.dart`):

- A `Container` with the decoration it was given, clipped to its rounded
  corners so a scrolled line does not spill past the border
  (`lib/api/widgets/code_block.dart`).
- A `Scrollbar` over a horizontal `SingleChildScrollView`
  (`lib/api/widgets/code_block.dart`). `thumbVisibility` is true because
  the bar is the only immediate sign that there is more line to the right.
- `Text` with `softWrap: false` — the rule the whole widget exists to keep.

The fence's own trailing newline was already stripped by the parser, so it does
not render as a blank final line
(`lib/infrastructure/markdown/markdown_document_parser.dart`).

Selection is left to the reading pane's `SelectionArea`
(`lib/api/widgets/reading_pane.dart`); the text carries only its own
selection colour so a highlighted line still reads against the block's
background (`lib/api/widgets/code_block.dart`). Nesting a second
`SelectionArea` here would create a competing selection registrar.

Inline code stays a run inside its surrounding role. `inlineCodeFor(base)`
keeps the mono face while scaling relative to a paragraph, heading or table
cell (`lib/api/render/inline_composer.dart`,
`lib/api/render/reading_theme.dart`).

## Inputs and outputs

| In | Type | From |
|----|------|------|
| `source` | `String` | `CodeBlock.code`, verbatim |
| `textStyle` | `TextStyle` | `ReadingTheme.code` — mono at 0.94 of body, one beat per line, slashed zero |
| `padding` | `EdgeInsets` | Half a beat vertically (`lib/api/render/document_view.dart`) |
| `decoration` | `Decoration` | `codeBackground` and an 8 px radius, no border (`lib/api/render/document_view.dart`) |

Out: a widget. It reports nothing and calls nothing back — a code block is
read, not interacted with.

## Events

None today. When a fence-language contributor lands (see the
[plugin architecture](../07-roadmap/01-plugin-architecture.md)), it would be
consulted one level out, in `DocumentView`'s `CodeBlock` case, with this plain
scrolling block as the fallback when nothing claims the language.

## Lifecycle

One `ScrollController` per block, created with the state and disposed with it
(`lib/api/widgets/code_block.dart`). Blocks live as long as the document
they are in; changing document rebuilds them.

## Failure and recovery

- A block shorter than the column simply does not scroll — there is nothing to
  scroll to, and the bar stays out of the way
  (`test/presentation/code_block_test.dart`).
- A fence with no language, or an unknown one, renders the same way: this
  widget never looks at the language.
- Very long lines have no upper bound; they scroll as far as they need.

Guarded by `test/presentation/code_block_test.dart`: a long line can be
scrolled to its end rather than being cut off, code is never re-wrapped, code is
never re-punctuated, and a short block still fills its column. That the block
comes to whole beats is held one level out, in
`test/presentation/document_view_test.dart`.

## Transition

Code now runs wider than prose, but only to 1.35 × the measure
(`lib/api/render/reading_theme.dart`). On a large screen there is room to
go further, and the factor is a judgement rather than a measurement. That, and
syntax highlighting, are the two things this widget is shaped to receive.
