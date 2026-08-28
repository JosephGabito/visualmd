# Mathematical Expression

## Purpose and boundary

Mathematical Expression typesets authored TeX as inline or display notation
without turning an equation into code, HTML, or an image. The API ring owns
painting, optical size, local overflow, copying and accessible fallback
(`lib/api/widgets/math_expression.dart`).

The domain retains only the equation and whether it belongs to a sentence or
the block sequence. The Markdown adapter owns delimiter grammar, while the
KaTeX dependency remains behind this one API component. A different typesetter
can therefore replace it without changing a document, search result or saved
workspace.

## Present wiring

`MathRun` reaches `InlineComposer`, which asks `ReadingTheme.mathSizeFor` for an
x-height-normalised KaTeX em and contributes a baseline-aligned
`MathInlineSpan` (`lib/api/render/inline_composer.dart`,
`lib/api/render/reading_theme.dart`). The span writes the TeX source into plain
text and semantics instead of Flutter's object-replacement character, so
copying the surrounding sentence does not silently lose the equation.

`MathBlock` receives the wider document column and becomes a
`ReadableMathBlock` (`lib/api/render/document_view.dart`). The notation is
centred when it fits and scrolls horizontally inside its own region when it
does not. It has no permanent panel, border, language label or background:
mathematics is part of the paper, not source shown for transcription. A copy
action appears on pointer hover or keyboard focus without changing the
component's geometry and places the original TeX on the clipboard. Its brief
fade becomes an immediate state change when the system requests reduced motion
(`lib/api/widgets/math_expression.dart`).

Numbered display equations remain centred on the reading measure while their
tags sit at its right edge. The selected renderer accepts `\tag` syntax but
does not yet include it in the painted tree, so this component separates only
a trailing top-level `\tag{...}` or `\tag*{...}` and paints the label through
the same math-font system. The complete authored source remains authoritative
for copying and semantics.

KaTeX Main has an x-height of 0.431 em, measured from the font bundled by the
package. `mathSizeFor` converts the surrounding role to its quoted letter size,
then chooses the KaTeX em that produces the same x-height. Display notation
uses the body role; KaTeX's display style supplies the larger operators and
limits. Accessibility text scaling participates in that calculation.

Both inline and display widgets preserve the active theme's ink. A display
equation is reconciled after layout so its complete height and outgoing gap
consume whole body beats. An inline equation may make its prose line taller;
the completed paragraph is reconciled in the same way. The next ordinary line
therefore returns to the running-text grid.

## Inputs and outputs

| In | Type | Meaning |
|----|------|---------|
| `source` | `String` | Exact TeX between the Markdown delimiters |
| `theme` | `ReadingTheme` | Ink, optical size, baseline and fallback style |
| surrounding style | `TextStyle` | The role an inline equation must remain part of |

The block output is one locally scrollable widget. The inline output is one
`InlineSpan` whose plain text remains the authored source.

## Events

None. Copying changes the operating-system clipboard, not application or
domain state.

## Lifecycle

Display components live for the current document build. Their horizontal
scroll controller and brief copy confirmation live in widget state and are
disposed with the block. Inline equations are immutable spans rebuilt with the
paragraph, theme or text scale (`lib/api/widgets/math_expression.dart`).

## Failure and recovery

Malformed or unsupported TeX never replaces the page with a Flutter error.
Inline notation becomes ordinary source text in the surrounding role. Display
notation becomes quiet selectable source in the mono face. Both retain a
semantic label containing the TeX, and the display copy action still returns
the original (`lib/api/widgets/math_expression.dart`).

An equation wider than its column remains reachable by local horizontal
scrolling; it cannot widen the document. Rendering, equation tags, failure,
overflow, optical size, grid reconciliation and clipboard behavior are covered in
`test/presentation/math_expression_test.dart`. Grammar and malformed-delimiter
behavior are covered in
`test/infrastructure/markdown_document_parser_test.dart`.

## Transition

The selected renderer is young, so it is pinned and contained. Its supported
TeX surface is guarded with notation taken from the research-paper specimen.
Natural spoken mathematics remains open: exposing authored TeX is faithful and
better than silence, but it is not a generated verbal interpretation.
Mermaid is a separate block contributor and does not enter this component.
