# Inline Composer

## Purpose and boundary

`InlineComposer` turns the domain's runs into Flutter spans, and sets the
punctuation properly on the way past
(`lib/api/render/inline_composer.dart`).

Its reason for existing is the seam it sits on. The document keeps what the
author typed; the page shows what a typographer would have set
(`lib/api/render/inline_composer.dart`). Straight quotes become the marks
they stand for, pairs of hyphens become dashes, three dots become an ellipsis
— and none of it touches code, which is composed verbatim. Doing this here
rather than in the parser is what keeps the domain's text honest: search,
outlines and the model itself still see the author's characters.

It owns span construction and punctuation. It owns no sizes or colours —
those come from [Reading Theme](14-reading-theme.md) — and no layout, which is
[Document View](12-document-view.md)'s.

## Present wiring

`compose(runs, {style, previous})` walks the runs, threading the last grapheme
actually emitted into the next one, because that decides whether a quote opens
or closes (`lib/api/render/inline_composer.dart`). The tail walk is
recursive, so whitespace or text inside nested emphasis and links still gives
the next quote its real context. It follows transformed output as well: an em
dash produced from three hyphens is punctuation, not a source hyphen.

Each run becomes a span (`lib/api/render/inline_composer.dart`):

| Run | Becomes |
|-----|---------|
| `TextRun` | A `TextSpan` whose text has been set (`lib/api/render/inline_composer.dart`) |
| `CodeRun` | Selectable verbatim text in contrast-safe accent mono; it rejects a link's decoration but retains authored insertion, subscript and superscript marks (`lib/api/render/inline_composer.dart`) |
| `MathRun` | A baseline-aligned `MathInlineSpan`, optically sized to the surrounding role and flattening back to authored TeX for copying (`lib/api/render/inline_composer.dart`) |
| `MarkedRun` | Italic, weight 700, deletion or insertion lines, or the face's designed subscript and superscript glyphs — one signal for each meaning (`lib/api/render/inline_composer.dart`) |
| `LinkRun` | `linkFor(base)`, which preserves the complete heading, table or marked style and adds only link colour, underline and interaction (`lib/api/render/inline_composer.dart`) |
| `FootnoteReferenceRun` | A designed superscript numeral with link colour, underline, definition navigation and an explicit accessibility label (`lib/api/render/inline_composer.dart`) |
| `FootnoteBackReferenceRun` | The authored return arrow, repeated-occurrence superscript, citation navigation and an accessibility label which names the return action (`lib/api/render/inline_composer.dart`) |
| `ImageRun` | A `DocumentImage` widget when the source is remote or a document loader is present; otherwise its alternative in `muted` (`lib/api/render/inline_composer.dart`) |
| `LineBreakRun` | One selectable newline in the surrounding style; no widget, extra gap or source marker (`lib/api/render/inline_composer.dart`) |

A link or code run keeps its full context. A link in an `h2` remains an `h2`,
a link in a table keeps lining tabular figures, and inline code in a heading
steps one logical pixel below that heading instead of collapsing to body-code
size
(`lib/api/render/reading_theme.dart`). Code is never promoted to an embedded
widget: the text remains in the paragraph's selectable, copyable and reflowable
span tree. Mono and code colour identify it; reserving the underline for actual
links keeps that interaction promise unambiguous. An `ins` container is the
explicit exception: its underline is authored meaning, so it remains present
when its recursive child is inline code.
Even an unbroken identifier stays in that flow and wraps inside a narrow
reading column (`test/presentation/inline_composer_test.dart`).
The explicit span type also stops widow binding from rewriting source text at
the end of a paragraph (`lib/api/render/inline_composer.dart`,
`lib/api/render/document_view.dart`). A
mouse-selection test copies only the code run and asserts its exact source text
(`test/presentation/inline_composer_test.dart`).

Inline mathematics is a painted widget because its fractions, limits and
radicals are not one font run. `MathInlineSpan` restores what an ordinary
`WidgetSpan` would lose: plain-text copying and semantics receive the TeX
source instead of an object-replacement character. Search still advances by
that source and paints a matching background behind the complete equation
(`lib/api/widgets/math_expression.dart`,
`test/presentation/math_expression_test.dart`).

An inline custom anchor is syntax rather than prose, but Flutter's keyed inline
geometry is a `WidgetSpan` and therefore one selectable placeholder code unit.
The parser removes that syntax before presentation. Exact navigation is
reserved for standalone `AnchorBlock` targets, while inline selection, copying,
search and semantics remain continuous
(`lib/infrastructure/markdown/safe_html_text.dart`,
`lib/infrastructure/markdown/markdown_document_parser.dart`,
`test/presentation/inline_composer_test.dart`).

An authored line stays inside the same span tree as its surrounding emphasis or
link. Its newline advances the same offset cursor used by document search, so a
match after the break highlights the intended characters while selection and
assistive technology receive the line itself
(`test/presentation/inline_composer_test.dart`).

An image remains an inline run, but its pixels need layout and asynchronous
loading that a `TextSpan` cannot provide. The composer therefore contributes a
middle-aligned `WidgetSpan` and gives [Document Image](23-document-image.md)
the current document, source, alternative and title. The alternative still
advances the source cursor even when pixels are painted, so a later search
match keeps its authored offset. Without a loader, the same words remain
visible instead of disappearing (`lib/api/render/inline_composer.dart`,
`test/presentation/inline_composer_test.dart`).

A Markdown link title remains domain data, but it is not used as the Flutter
span's semantics label. A semantics label replaces visible text for assistive
technology, while the link title is only advisory. `_LinkTextSpan` instead
presents the complete recursive label as one logical range: nested code,
strength and emphasis still paint independently, but hit testing and semantics
own the whole phrase. The visible words form one link node with a tap action,
and a real pointer tap reaches the same callback
(`lib/api/render/inline_composer.dart`,
`test/presentation/inline_composer_test.dart`).

The destination and title never enter the span tree, so neither can widen the
page. A long label remains ordinary inline text: Flutter may use emergency
breaks inside an otherwise unbreakable token, but never splits a grapheme, and
every resulting line still maps back to the one `_LinkTextSpan` interaction.
An empty label paints no glyph, creates no hit rectangle, and therefore exposes
no phantom link action (`lib/api/render/inline_composer.dart`,
`test/presentation/inline_composer_test.dart`).

Composition advances by extended grapheme cluster rather than UTF-16 code
unit. Search and syntax boundaries that land inside a combining sequence,
emoji modifier, flag, or ZWJ sequence are expanded to the complete visible
character before spans are cut. The background may therefore cover more code
units than the literal query, but the glyph can never be broken by a style
boundary (`lib/api/render/inline_composer.dart`).

### Emphasis

The parser has already resolved both delimiter spellings to
`InlineMark.emphasis`, so composition never sees or paints a star or
underscore. It adds `FontStyle.italic` to the surrounding role and nothing
else: colour, weight, size, leading, decoration, direction and the selectable
text all remain inherited. Search background is an independent layer, so a
matched phrase stays italic without gaining a second semantic or accessible
label (`lib/api/render/inline_composer.dart`).

That restraint is the typography. Emphasis is a local change of voice inside
running text, not a miniature heading. Its long hostile specimen wraps on the
ordinary measure and baseline grid, and its Unicode clusters use the same
composition path as roman prose (`test/presentation/inline_composer_test.dart`).

### Strong emphasis

`InlineMark.strong` inherits the surrounding role and changes only its weight
to 700. It does not borrow italic from emphasis, shift toward the accent, add a
box, or alter size and leading. Search paint remains independent, and the
delimiter-free words remain the selectable and accessible text
(`lib/api/render/inline_composer.dart`).

The bundled variable reading faces receive that weight through
`TextStyle.fontWeight`; the long hostile specimen proves the heavier glyphs may
reflow naturally without pushing the paragraph off its baseline grid
(`test/presentation/paragraph_setting_test.dart`).

### Combined and nested emphasis

Composition is recursive, so a child begins with the complete style inherited
from its parent. Emphasis inside strength retains weight and adds italic;
strength inside emphasis retains italic and adds weight. Triple delimiters use
that same pair of ordinary marks rather than inventing a third visual role
(`lib/api/render/inline_composer.dart`).

The result remains one selectable and accessible string. No delimiter is
painted or spoken, no nested span supplies a replacement semantics label, and
search background remains an independent layer. A long combined specimen may
wrap differently because its glyphs are wider, but every rendered line returns
to the prose baseline grid (`test/presentation/inline_composer_test.dart`,
`test/presentation/paragraph_setting_test.dart`).

### Strikethrough

Both eligible GFM spellings reach composition as
`InlineMark.strikethrough`. The composer inherits the complete surrounding
role and adds only `TextDecoration.lineThrough`: no muted tone, accent, weight,
italic, size or leading change. A deletion is still legible prose, and the
continuous line is already its editorial signal
(`lib/api/render/inline_composer.dart`).

The words remain ordinary selectable and accessible text. Search background
can paint either spelling without replacing the line-through or supplying a
semantics label, and a long deleted passage may reflow while every line returns
to the prose baseline grid (`test/presentation/inline_composer_test.dart`,
`test/presentation/paragraph_setting_test.dart`).

### Scientific and inserted text

`InlineMark.subscript` and `InlineMark.superscript` add the OpenType `subs` or
`sups` feature to the complete surrounding style. The bundled reading faces
provide those substitutions, so the result uses glyphs drawn for the role
instead of a scaled and manually shifted widget. Font size, leading, colour,
selection, semantics, nested Markdown roles, and the prose baseline grid stay
unchanged (`lib/api/render/inline_composer.dart`).

The bundled-font contract is checked from each font's own GSUB table
(`test/presentation/bundled_scientific_feature_test.dart`). A custom theme may
name any Google Fonts family, so its author must choose a serif and mono face
that also provides `subs` and `sups`; a face without those substitutions keeps
the affected glyph on the ordinary baseline.

`InlineMark.insertion` adds one inherited-ink underline. GitHub documents
`ins` as underline, while a link retains the stronger interaction pair of an
accent colour and underline. Decorations combine when marks nest, so insertion
inside deletion does not erase either authored meaning. All three marks remain
ordinary selectable and searchable text
(`lib/api/render/inline_composer.dart`,
`test/presentation/inline_composer_test.dart`,
`test/presentation/paragraph_setting_test.dart`).

### Setting the punctuation

`_text` walks a run grapheme by grapheme
(`lib/api/render/inline_composer.dart`), delegating the rules to
[Typographic Punctuation](../04-presentation/README.md) in the presentation
ring: a quote is opened or closed based on what precedes it, two or three
hyphens become an en or em dash, three dots become an ellipsis. A lone hyphen
stays a hyphen — `well-known` is not `well–known`.

Because `CodeRun` never reaches `_set`, `git log --oneline "HEAD"...` is
composed exactly as written
(`test/presentation/inline_composer_test.dart`).

The same rules also expose `TypographicProjection` in
`lib/presentation/theme/typographic_punctuation.dart`. It keeps the displayed
string beside sparse contraction boundaries, so a windowed consumer can map a
selection after an en dash or ellipsis back to the exact authored source in
O(log substitutions), without allocating one offset per character
(`test/presentation/typographic_punctuation_test.dart`). A bounded projection
also accepts the displayed character immediately to its left and reports the
character before any later boundary. Adjacent viewport ranges therefore make
the same opening-quote decision as one continuous composition without scanning
their prefix. This is a presentation projection only; copied and searched text
remains the domain's source.

## Inputs and outputs

| In | Type | From |
|----|------|------|
| `theme` | `ReadingTheme` | The pane |
| `document` | `DocumentId?` | The reading whose directory owns relative sources |
| `imageLoader` | `DocumentImageLoader?` | The application capability for document-local bytes |
| `onTapLink` | `void Function(String href)?` | The pane's link handler |
| `compose(runs, {style, previous})` | `List<Inline>`, optional base `TextStyle` and preceding character | Each block, as it builds |

Out: `List<InlineSpan>`. Tapping a link calls `onTapLink(href)` with the href
exactly as the author wrote it; resolving it against the current document is
`ReaderController.resolveLink`'s job
([Reader Controller](01-reader-controller.md)).

## Events

None today. A contributor that wanted to render another custom inline — for
example a wiki link — would attach in `_run`
(`lib/api/render/inline_composer.dart`); see the
[plugin architecture](../07-roadmap/01-plugin-architecture.md).

## Lifecycle

`InlineComposer` is `const` and stateless
(`lib/api/render/inline_composer.dart`).

`DocumentView` builds one for each render and discards it with that render
(`lib/api/render/document_view.dart`).

## Failure and recovery

Span construction obeys Flutter's text invariants. The switch over runs is
exhaustive over a sealed hierarchy, so a new run type cannot be added without
deciding how it is composed. A link with no handler simply gets no recogniser
and an image without a usable loader keeps its alternative as text
(`lib/api/render/inline_composer.dart`). Behaviour is covered by
`test/presentation/inline_composer_test.dart`.

## Transition

Two things are deliberately outside this component. Hanging punctuation is
applied after composition by [Paragraph](15-paragraph.md). Primes remain open:
`5'2"` is set as quotes today, where a typographer would want hatch marks. It
is noted in the [backlog](../07-roadmap/02-backlog.md).
