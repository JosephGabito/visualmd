# Code Block

## Purpose and boundary

`ReadableCodeBlock` presents verbatim source as a quiet reference surface
(`lib/api/widgets/code_block.dart`). Prose is the page speaking to the reader;
code is supporting evidence. It is therefore smaller and more compact, while
remaining selectable, searchable and exact.

The widget owns the language header, local scrolling or wrapping, copying and
the completed block's geometry. It does not parse fences or understand a
grammar. The domain supplies `CodeBlock.code` and `CodeBlock.language`; the
framework-free [Code Highlighting](../04-presentation/12-code-highlighting.md)
contract supplies optional source ranges.

## Present wiring

[Document View](12-document-view.md) builds one `ReadableCodeBlock` for every
domain `CodeBlock` (`lib/api/render/document_view.dart`). The author's exact
source paints immediately. `CodeHighlighter.highlight` runs asynchronously;
when valid tokens arrive, [Inline Composer](13-inline-composer.md) divides the
same source into styled ranges without replacing any character
(`lib/api/render/inline_composer.dart`).

The header is one prose beat high. It shows a human language name and two icon
actions with tooltips and semantics:

- **Wrap long lines** changes only this block. Off is the default because a
  wrapped line can resemble source indentation. Turning it on removes local
  horizontal scrolling and lets the source reflow.
- **Copy code** sends the exact source to the clipboard, including tabs, blank
  lines and trailing spaces. A check briefly confirms completion.

Unwrapped source lives in a horizontal `SingleChildScrollView` with a subdued
four-pixel scrollbar. The page itself never gains horizontal overflow
(`lib/api/widgets/code_block.dart`). Code receives `wideWidth`, about a third
more room than prose, before local scrolling begins
(`lib/api/render/reading_theme.dart`).

The colour surface uses one signal with two tones. On a dark theme the code
body is darker than its header; on a light theme it is brighter. The header
uses `codeBackground`, while `ReadingTheme.codeBodyBackground` derives the
body in the correct luminance direction (`lib/api/render/reading_theme.dart`).
There is no border or shadow.

Geist Mono is measured and normalised before it is set. Source letters are
three logical pixels smaller than prose: 15 px on a 22 px line at the
comfortable 18 px reading size
(`lib/presentation/theme/reading_scale.dart`). The complete body is then
rounded to the prose grid and the small correction shared above and below the
source. Code stays internally dense while the paragraph after it returns in
phase (`lib/api/widgets/code_block.dart`).

Search and syntax use different channels. Syntax supplies foreground colour;
the current search match supplies the background. Both therefore survive on
the same `TextSpan`, and selection remains owned by the reading pane's single
`SelectionArea` (`lib/api/render/inline_composer.dart`).

## Inputs and outputs

| In | Meaning |
|----|---------|
| `source` | Exact source text; the authority for painting and copying |
| `language` | First word of the fence info string, or null |
| `highlighter` / `scheme` | Optional semantic source ranges for light or dark ground |
| `spansFor` | Merges ranges with search without surrendering source ownership |
| `textStyle` | Compact Geist Mono style from `ReadingTheme.code` |
| `bodyBackground` | Derived second tone beneath source |
| `beat` / `headerHeight` | Prose rhythm used to reconcile the complete surface |
| `padding` / `decoration` | Theme-bound internal space and rounded header surface |

Out: one selectable widget. The only external side effect is an explicit
clipboard write after the reader invokes Copy.

## Events

None. Wrap and copied confirmation are local ephemeral state. No domain event
is emitted because reading or copying an example does not mutate the library.

## Lifecycle

One state object and horizontal `ScrollController` live with each rendered
block (`lib/api/widgets/code_block.dart`). A source, language, scheme or
highlighter change invalidates the pending request and starts another. A
request number prevents a late result from an earlier document repainting the
new one. Copy confirmation owns a short timer; both timer and controller are
disposed with the block.

The application creates one `ShikiCodeHighlighter` at composition and shares
it across blocks so grammars and themes remain cached (`lib/main.dart`).

## Failure and recovery

Highlighting is enhancement, never a precondition. A plain fence, unknown
language, failed grammar, thrown contributor or invalid source range leaves
the exact plain source visible (`lib/api/widgets/code_block.dart`,
`lib/api/highlighting/shiki_code_highlighter.dart`). A package update cannot
insert, remove or reorder text because ranges are accepted only when they
match the corresponding source substring.

A short line has no scroll extent. A long line remains reachable. Wrapped
source grows vertically and the rhythmic body reconciles its new shaped
height before returning to prose. These contracts, keyboard access, copying,
semantics, theme direction and fallback are held by
`test/presentation/code_block_test.dart`.

## Transition

Diagram fences such as `mermaid` need a different block renderer, not special
cases in this text widget. The existing `CodeHighlighter` proves one narrow
typed contributor; a general plugin registry should wait until more real
contributors reveal the common shape.
