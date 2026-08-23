# Inline Composer

## Purpose and boundary

`InlineComposer` turns the domain's runs into Flutter spans, and sets the
punctuation properly on the way past
(`lib/api/render/inline_composer.dart:15-31`).

Its reason for existing is the seam it sits on. The document keeps what the
author typed; the page shows what a typographer would have set
(`lib/api/render/inline_composer.dart:8-14`). Straight quotes become the marks
they stand for, pairs of hyphens become dashes, three dots become an ellipsis
— and none of it touches code, which is composed verbatim. Doing this here
rather than in the parser is what keeps the domain's text honest: search,
outlines and the model itself still see the author's characters.

It owns span construction and punctuation. It owns no sizes or colours —
those come from [Reading Theme](14-reading-theme.md) — and no layout, which is
[Document View](12-document-view.md)'s.

## Present wiring

`compose(runs, {style, previous})` walks the runs, threading the last character
actually emitted into the next one, because that decides whether a quote opens
or closes (`lib/api/render/inline_composer.dart:21-52`). The tail walk is
recursive, so whitespace or text inside nested emphasis and links still gives
the next quote its real context. It follows transformed output as well: an em
dash produced from three hyphens is punctuation, not a source hyphen.

Each run becomes a span (`lib/api/render/inline_composer.dart:54-108`):

| Run | Becomes |
|-----|---------|
| `TextRun` | A `TextSpan` whose text has been set (`:56-57`) |
| `CodeRun` | A selectable `InlineCodeSpan` in the surrounding role, set verbatim in contrast-safe accent mono with a translucent muted underline (`:59-60`) |
| `MarkedRun` | Italic, weight 700, or a strikethrough in `muted` — one mark each, since one mark is enough (`:62-76`) |
| `LinkRun` | `linkFor(base)`, which preserves the complete heading, table or marked style and adds only link colour, underline and interaction (`:78-93`) |
| `ImageRun` | Its alt text in `muted`; images are not resolved yet, and the alt is what the author meant the reader to get either way (`:95-103`) |
| `LineBreakRun` | A newline (`:105-106`) |

A link or code run keeps its full context. A link in an `h2` remains an `h2`,
a link in a table keeps lining tabular figures, and inline code in a heading
scales with that heading instead of collapsing to body-code size
(`lib/api/render/reading_theme.dart:184-212`). Code is never promoted to an
embedded widget: its muted underline is only a painted decoration, while
the text remains in the paragraph's selectable, copyable and reflowable span tree.
The explicit span type also stops widow binding from rewriting source text at
the end of a paragraph (`lib/api/render/inline_composer.dart:145-152`,
`lib/api/render/document_view.dart:607-616`). A
mouse-selection test copies only the code run and asserts its exact source text
(`test/presentation/inline_composer_test.dart:162-234`).

### Setting the punctuation

`_set` walks a run character by character
(`lib/api/render/inline_composer.dart:110-142`), delegating the rules to
[Typographic Punctuation](../04-presentation/README.md) in the presentation
ring: a quote is opened or closed based on what precedes it, two or three
hyphens become an en or em dash, three dots become an ellipsis. A lone hyphen
stays a hyphen — `well-known` is not `well–known`.

Because `CodeRun` never reaches `_set`, `git log --oneline "HEAD"...` is
composed exactly as written
(`test/presentation/inline_composer_test.dart:118-123`).

## Inputs and outputs

| In | Type | From |
|----|------|------|
| `theme` | `ReadingTheme` | The pane |
| `onTapLink` | `void Function(String href)?` | The pane's link handler |
| `compose(runs, {style, previous})` | `List<Inline>`, optional base `TextStyle` and preceding character | Each block, as it builds |

Out: `List<InlineSpan>`. Tapping a link calls `onTapLink(href)` with the href
exactly as the author wrote it; resolving it against the current document is
`ReaderController.resolveLink`'s job
([Reader Controller](01-reader-controller.md)).

## Events

None today. A contributor that wanted to render a custom inline — a footnote
marker, a wiki link — would attach in `_run`
(`lib/api/render/inline_composer.dart:54-108`); see the
[plugin architecture](../07-roadmap/01-plugin-architecture.md).

## Lifecycle

`InlineComposer` is `const` and stateless
(`lib/api/render/inline_composer.dart:15-19`).

`DocumentView` builds one for each render and discards it with that render
(`lib/api/render/document_view.dart:51-72`).

## Failure and recovery

Nothing throws. The switch over runs is exhaustive over a sealed hierarchy, so
a new run type cannot be added without deciding how it is composed. A link
with no handler simply gets no recogniser
(`lib/api/render/inline_composer.dart:78-93`). Behaviour is covered by
`test/presentation/inline_composer_test.dart:49-338`.

## Transition

Two things are deliberately outside this component. Hanging punctuation is
applied after composition by [Paragraph](15-paragraph.md). Primes remain open:
`5'2"` is set as quotes today, where a typographer would want hatch marks. It
is noted in the [backlog](../07-roadmap/02-backlog.md).
