# Paragraph

## Purpose and boundary

One paragraph, set: its first line indented when the rules call for it, its
opening mark hung outside the column, and its last two words bound so neither
is left standing alone.

It is the widget that *applies* three presentation rules — the
[hanging table](../04-presentation/08-hanging-punctuation.md), the
[widow remedy](../04-presentation/09-widow-binding.md) and the indent from the
[Reading Scale](../04-presentation/07-reading-scale.md) — none of which it
decides. Those rules are framework-free data one ring in; measuring a glyph
and placing it needs a text engine, which is why this half lives in `api/`.

It does not decide *whether* it is indented either: `DocumentView` works that
out from what came before it and passes a number
(see [Document View](12-document-view.md)).

## Present wiring

`Paragraph` takes the spans, the style they are set in, the active text scaler,
a strut and an indent (`lib/api/render/document_view.dart`). Building
it happens in three steps (`lib/api/render/document_view.dart`):

1. **Split the mark.** `splitHangingMark` takes an opening mark off the front
   of the spans if there is one (`lib/api/render/document_view.dart`).
2. **Bind the widow.** `bindWidow` counts the whole paragraph, then descends
   through styled wrappers to bind its last eligible text leaf
   (`lib/api/render/document_view.dart`).
3. **Set the line.** The indent goes into the flow as a `WidgetSpan` sized to
   it, baseline-aligned, so it moves the first line and nothing else
   (`lib/api/render/document_view.dart`).

**The strut is what keeps the paragraph on the beat.** It holds every line box
to the same height whatever is set inside it
(`lib/api/render/document_view.dart`, applied at `lib/api/render/document_view.dart`), so a line
carrying an inline code span — set smaller than the prose around it — cannot
grow to fit and push itself off the grid. It is supplied by the theme
(`lib/api/render/document_view.dart`); see
[Vertical Rhythm](../04-presentation/11-vertical-rhythm.md).

When a mark was split off, the paragraph is wrapped in a `Stack` with
`clipBehavior: Clip.none` and the mark painted at `indent - hang`
(`lib/api/render/document_view.dart`). Two consequences of doing it
this way:

- The mark is **out of the flow**, so the text begins on the column edge and
  every line of the paragraph starts in the same place.
- Same style and same top means the mark and the first line share a baseline
  exactly, with no vertical nudging to get wrong.

`hang` is the mark's own advance, measured in the face actually in use
(`ReadingMeasure.widthOf`), multiplied by the table's fraction
(`lib/api/render/document_view.dart`). The measurement receives the
same `TextScaler` that draws the paragraph. A hanging mark hangs from the
*indent*, not from the column edge: the indent moves the line, and the mark
hangs off the line (`lib/api/render/document_view.dart`).

### What deliberately does not hang or bind

- A paragraph opening with a link or an emphasised run
  (`lib/api/render/document_view.dart`). Pulling those into the margin
  would move meaning rather than ink.
- A paragraph ending in code or a link
  (`lib/api/render/document_view.dart`). It ends with something the
  reader can see is deliberate, and its source spacing remains unchanged.
- A paragraph shorter than `WidowBinding.leastWords`, counted across the whole
  paragraph rather than the last run alone
  (`lib/api/render/document_view.dart`).

## Inputs and outputs

| In | Type | Meaning |
|----|------|---------|
| `spans` | `List<InlineSpan>` | The composed runs, from [Inline Composer](13-inline-composer.md) |
| `style` | `TextStyle` | The style the paragraph is set in; the hung mark is set in the same one |
| `textScaler` | `TextScaler` | The accessibility scaling shared by drawing and mark measurement |
| `strut` | `StrutStyle?` | Holds every line box to one beat, from `ReadingTheme.strutFor` |
| `indent` | `double` | First-line indent, 0 when the paragraph is flush |

Out: a widget. Nothing is reported back.

## Events

None today. When UI slots land, a paragraph is not where a contribution would
attach — a block renderer is (see
[the plugin architecture](../07-roadmap/01-plugin-architecture.md)).

## Lifecycle

Stateless, rebuilt with the page. The mark is measured on every build;
`ReadingMeasure` caches by the complete shaped style and scaled size, so a
document of many quoted paragraphs measures each distinct rendering once.

## Failure and recovery

- Empty spans, a first span that is not text, or an empty first run all return
  the paragraph unchanged (`lib/api/render/document_view.dart`).
- A character not in the table returns a fraction of 0, so nothing hangs.
- `Clip.none` is what lets the mark paint outside its box. The column is
  centred with margin either side, so there is room; a window narrow enough to
  clamp the column to its full width is the case where a hung mark could reach
  the pane's edge.

`test/presentation/paragraph_setting_test.dart` covers both halves:
that a mark is split only when the line opens with plain text, and — measured,
not eyeballed — that the words line up with an unquoted paragraph while the
mark sits exactly its own advance to the left of them.

## Transition

- **Only the opening mark hangs.** A line further down the paragraph that
  begins with a quotation mark stays in the column. Hanging those needs
  per-line control Flutter's text engine does not expose.
- **The indent is one rendered em**
  (`lib/api/render/reading_theme.dart`). A reader who wanted a deeper
  or shallower one would need a new scale parameter rather than a pixel here.
