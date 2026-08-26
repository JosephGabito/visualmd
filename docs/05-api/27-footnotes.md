# Footnotes

## Purpose and boundary

Footnotes let a sentence acknowledge supporting matter without forcing that
matter into the reading flow. Visual MD keeps each citation reachable, moves
its resolved definition to the document's final annotation section, and gives
every return link a stable place to come back to.

The Markdown adapter owns recognition and order. The domain owns reference and
definition identity. `InlineComposer`, `DocumentView`, and `ReadingTheme` own
the visible numeral, navigation targets, annotation typography, and completed
section rhythm (`lib/domain/reading/content/inline.dart`,
`lib/domain/reading/content/block.dart`).

## Present wiring

The configured Markdown grammar resolves `[^label]` and its definition before
the adapter maps the tree. A complete `sup.footnote-ref` becomes
`FootnoteReferenceRun`; `section.footnotes` becomes one
`FootnoteSectionBlock`. Percent-encoded package ids are decoded into one local
identity, and definitions are restored to the order their first references
appear rather than where their source declarations happen to sit. A repeated
citation keeps the same number and receives a distinct named return
(`lib/infrastructure/markdown/markdown_document_parser.dart`).

The numeral remains text inside the paragraph's selectable span tree. It uses
the reading face's designed superscript feature, then adds the same accent and
underline that promise interaction everywhere else. Its accessibility label
says “Footnote” and the number rather than announcing an unexplained digit
(`lib/api/render/inline_composer.dart`).

Each definition return is a typed `FootnoteBackReferenceRun`. Its visible arrow
stays faithful to GitHub, while its accessibility label names the footnote and
repeated occurrence it returns to. The return target is the citation's
containing reading block: that is the smallest geometry Flutter can key without
replacing a selectable inline glyph with a widget
(`lib/domain/reading/content/inline.dart`,
`lib/api/render/inline_composer.dart`, `lib/api/render/document_view.dart`).

The final section uses one quiet top rule and an ordered list. Its reading face
is exactly two logical pixels smaller than running prose, with the same
x-height normalisation and measured leading. Internal lines use that annotation
beat; `_RhythmicContainer` reconciles the complete section to the parent body
grid before ordinary prose can resume
(`lib/presentation/theme/reading_scale.dart`,
`lib/api/render/reading_theme.dart`, `lib/api/render/document_view.dart`).

## Inputs and outputs

| In | Meaning |
|----|---------|
| `FootnoteReferenceRun.number` | Visible ordinal assigned by first reference |
| `definitionAnchor` | Local target reached from the citation |
| `referenceAnchor` | Unique return target for this occurrence |
| `FootnoteBackReferenceRun` | Visible arrow plus the number, occurrence, and decoded local return identity |
| `FootnoteDefinition.blocks` | Complete resolved note, including multiple paragraphs and inline roles |

Out: one superscript link in reading text and one ordered definition at the
document's end. Both directions report ordinary fragment hrefs through the
existing link handler; neither enters the heading outline.

## Events

None. Citation and return taps use the page's existing link event.

## Lifecycle

References and definitions live in `DocumentContent` for the current parsed
reading. Their `GlobalKey` targets are rebuilt with the page and cleared with
the other custom anchors when the reading changes. Standalone HTML anchors and
footnote targets share one first-wins namespace, so conflicting authored names
remain deterministic and never mount one key twice. That ownership is carried
by document content rather than consumed during widget build, so resizing the
reader cannot make a target disappear.

## Failure and recovery

An incomplete footnote-shaped node does not acquire false navigation meaning;
its readable children follow the adapter's generic fail-readable path. An
unreferenced definition contributes no rendered content because the grammar
never includes it in the resolved document. Multi-paragraph notes retain their
block boundaries, while repeated citations retain every return link
(`test/infrastructure/markdown_document_parser_test.dart`).

Unicode and reserved label characters are tested through decoded
first-reference order and both generated target directions
(`test/infrastructure/markdown_document_parser_test.dart`,
`test/presentation/document_view_test.dart`).

The presentation tests require a designed superscript, a named accessibility
link, both anchor directions, a smaller note role, and final baseline phase
(`test/presentation/inline_composer_test.dart`,
`test/presentation/document_view_test.dart`).

## Transition

No separate footnote popover is planned. The endnote shape is portable,
selectable, printable, and faithful to GitHub's writing contract. A future
preview may contribute at the interaction edge without replacing these anchors
or changing document content.
