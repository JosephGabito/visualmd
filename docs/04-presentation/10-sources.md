# Sources

The reading decisions in this shelf have traceable sources. This document
records both the evidence that shaped the page and the places where Visual MD
made a project-specific choice, so either can be reviewed independently.

## Books

**Ellen Lupton, *Thinking with Type*, 2nd edition** — the source for how this
reader marks structure.

| What it settled | Where |
|---|---|
| An elegant economy of signals: no more than three cues per level, and emphasis needs only one | *Hierarchy* |
| Italic is the standard mark of emphasis — which is also why a quotation is not set in it | *Hierarchy* |
| Indents and paragraph spacing are alternatives; using both is the mark of an overloaded page | *Marking paragraphs* |
| Never indent the opening line of a body of text — an indent signals a break, and nothing has been broken from yet | *Marking paragraphs* |
| Hanging punctuation keeps opening marks from carving a notch out of the left edge | *Punctuation*, p. 58 |
| Old-style figures sit in the line; lining figures stand up out of it | *Numerals* |
| Light type on a dark ground reads better tracked a little looser | *Tracking*, p. 56 |
| A good rag is pleasantly uneven, with hyphenation kept to a minimum | *Alignment* |
| A baseline grid aligns text across a field | *Grid*, p. 198 |
| Decorative rules divide content, while ornament should echo structure rather than compete with it | *Ornaments*, pp. 60–63 |
| Reducing leading creates denser colour but risks collisions; increasing it separates lines into independent elements | *Line spacing*, p. 108 |
| Long lists depend on hierarchy, alignment and consistent styles for scanning | *Exercise: long lists*, p. 146 |

Lupton's paragraph specimens on p. 126 warn that a full blank line is often
too open and show a half-line alternative. Visual MD's **spaced** mode therefore
uses half a beat after consecutive paragraphs. Its **indented** mode uses the
book's one-em first-line indent and no gap; the opening paragraph stays flush.
Both are pair-aware outcomes of `spaceAfter`, never combined signals.
The book also cautions that white space is not automatically a kindness to the
reader. A thematic break therefore uses a quiet hairline inside the existing
grid rather than manufacturing a larger empty field around itself.

The line-spacing and long-list guidance settle a related distinction. Lists
should be denser than consecutive root paragraphs, but reducing the leading of
wrapped item prose would change its typographic colour and risk collisions.
Visual MD therefore keeps the body strut inside every container and reduces
only the external interval: none in a tight list and half a beat in a loose
list or quotation. Marker alignment and a shared text edge supply the remaining
hierarchy (`lib/api/render/reading_theme.dart`,
`lib/api/render/document_view.dart`).

**Robert Bringhurst, *The Elements of Typographic Style*** — the source for
the vertical rhythm.

The rule taken from it is that the vertical space consumed by any departure
from the running text should be an even multiple of the basic leading, so the
main text returns after each variation on the beat and in phase. Everything on
this page is spent in whole beats because of it — see
[Vertical Rhythm](11-vertical-rhythm.md).

## Legibility research

Summarised in the overview at [legible-typography.com](https://legible-typography.com/en/5-overview-of-research-type),
and consistent across the studies it collects.

- **Serif against sans is a dead end.** Lund's review of 72 studies found no
  valid conclusion in favour of either. The family of the face is not the
  lever it is assumed to be.
- **X-height, not nominal size, decides how large text reads.** This is why a
  size in this reader is a size of letters, worked out per face — see
  [Font Metrics](../05-api/16-font-metrics.md) and
  `lib/api/theme/font_metrics.dart`. Measuring it caught a real defect:
  body text was rendering about 7 % smaller than the sans beside it at the
  same nominal size.
- **Letter differentiation matters, and old-style faces can be worse at it.**
  In one study Garamond's `e` was identified correctly a tenth as often as
  Verdana's. For documents full of identifiers, that argues against the
  bookish face and for one drawn for screens.
- **Italic slows continuous reading; bold does not.** Both are kept for
  emphasis and headings rather than for passages.
- **Capitals slow reading.** They appear only on short chrome labels, never
  in a document.
- **Making text harder to read does not aid memory.** The disfluency effect
  behind fonts such as Sans Forgetica did not survive a meta-analysis of
  seventeen studies.

The overarching finding put the choice of face in perspective:
typeface choice matters far less than designers assume, *provided the face is
conventional and drawn for its medium*. That keeps the larger investment on
measure, leading, rhythm, and character differentiation rather than treating a
font swap as the main source of clarity.

**Dyson and Kipping, “The Effects of Line Length and Method of Movement on
Patterns of Reading from Screen” (1998)** tested 25-, 55- and 100-character
lines. The 100-character condition was read faster than the 25-character one,
comprehension stayed constant, and readers judged 55 characters easiest. The
reader therefore uses 55 as its lower comfortable measure, not as a claimed
comprehension cliff, while its 66-character target remains inside the familiar
middle band. [Read the paper](https://journals.uc.edu/index.php/vl/article/view/5671).

The reader now sets its page in **Alegreya**, drawn by Huerta Tipográfica for
literature and long-form text. Literata — drawn for long reading on screens,
across rendering technologies, with a real optical-size axis — remains bundled
and selectable. See [Theme Binding](../05-api/06-theme.md).

## Heading rhythm

[Butterick](https://practicaltypography.com/headings.html) treats headings as
signposts: prefer subtle space, bold rather than italic, and the smallest size
change that makes the hierarchy visible. Production reading systems confirm
that display leading tightens as type grows. [NICE](https://design-system.nice.org.uk/foundations/typography/)
uses 1.2 for `h1`/`h2`, opening toward 1.6 at body-sized `h6`; the tested
[GOV.UK scale](https://design-system.service.gov.uk/styles/type-scale/) is
tighter still at its largest sizes. Visual MD's `[1.14, 1.18, 1.24, 1.30,
1.40]` follows that progression, then uses measured body leading at `h6`
(`lib/api/render/reading_theme.dart`). The completed heading, not each
display line, is reconciled with the body grid. Flutter may therefore expand a
mixed-script line before the renderer measures it.

[CommonMark 0.31.2](https://spec.commonmark.org/0.31.2/#setext-headings)
defines a Setext heading as one or more uninterrupted paragraph lines followed
by its underline, with all of those lines parsed as inline content. The
outline therefore joins the same source paragraph that the page parser renders
instead of treating only its last physical line as the title.
[GitHub's section-link rules](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#section-links)
establish the reader's anchor contract: remove markup and punctuation, preserve
the words including Unicode, replace spaces with hyphens, and number repeats.
[Flutter's heading-level semantics](https://api.flutter.dev/flutter/semantics/SemanticsProperties/headingLevel.html)
carry the authored level to screen readers and map it to `aria-level` on the
web; the renderer supplies that structure in addition to its visual hierarchy.
[Unicode UAX #9](https://www.unicode.org/reports/tr9/) defines a paragraph's
base direction from its first strong `L`, `R`, or `AL` character. Visual MD
uses that rule for a heading's base direction, while a heading made only of
punctuation inherits the surrounding page direction instead of guessing.

## Thematic breaks

[CommonMark 0.31.2](https://spec.commonmark.org/0.31.2/#thematic-breaks)
defines the complete syntax and its precedence: three or more matching
asterisks, hyphens or underscores; spaces or tabs between marks; no more than
three leading spaces; Setext precedence after paragraph text; thematic-break
precedence over a competing list marker. The parser's hostile cases are taken
from those rules rather than from only the three shortest spellings.

[WAI-ARIA 1.2](https://www.w3.org/TR/wai-aria/#separator) treats a non-focusable
horizontal separator as static document structure with an implicit horizontal
orientation. Flutter does not currently expose a separator member in its
[`SemanticsRole`](https://api.flutter.dev/flutter/dart-ui/SemanticsRole.html)
enum, so Visual MD supplies the nearest cross-platform contract: a dedicated,
non-interactive semantics node named “Thematic break.” It does not invent a
button, focus target or visible caption.

## Soft line breaks

[CommonMark 0.31.2](https://spec.commonmark.org/0.31.2/#soft-line-breaks)
defines an ordinary line ending inside inline content as a soft break unless
two spaces or a backslash make it explicit. Whitespace at the end of the first
source line and beginning of the next is removed, and a conforming renderer may
join the lines with a space. Visual MD chooses reflow rather than a hard break:
an editor's wrapping is source formatting, not document structure.

That space cannot be unconditional. The current
[CSS Text Module](https://www.w3.org/TR/css-text-4/#line-break-transform)
describes segment-break transformation as “unbreaking” source text: languages
with word separators need a space, while Chinese source lines join with no
intervening whitespace. Its model also removes adjoining spaces and tabs before
the join. Visual MD applies that distinction to Han, Hiragana, Katakana and
Bopomofo context, even when punctuation or an inline mark sits beside the
break; Korean, Arabic, Hebrew and Latin keep a word separator
(`lib/infrastructure/markdown/markdown_document_parser.dart`). Flutter then
chooses actual rendered lines from the available measure. This follows
[Unicode UAX #14](https://www.unicode.org/reports/tr14/): the source supplies
text and legal break opportunities, while the layout system selects line
positions for the width in hand.

Lupton's *Alignment* chapter supplies the typographic consequence. Flush-left,
ragged-right text respects the flow of language, and its rag should be
pleasantly uneven rather than an editor's repeated column shape. The narrow and
wide rendering test therefore compares source-wrapped and unwrapped paragraphs
and requires identical text geometry
(`test/presentation/paragraph_setting_test.dart`).

## Hard line breaks

[CommonMark 0.31.2](https://spec.commonmark.org/0.31.2/#hard-line-breaks)
defines the authored opposite of a soft break. Two or more spaces or a
backslash before a line ending produces one hard break inside inline content;
leading indentation on the next source line is removed. The break may live
inside emphasis, links and other inline constructs, but neither spelling works
inside a code span or at the end of a paragraph or heading. Visual MD keeps
those boundaries as one `LineBreakRun` and verifies both spellings against the
same domain shape (`lib/infrastructure/markdown/markdown_document_parser.dart`).

The [WHATWG HTML standard](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-br-element)
states the semantic reason: a `br` represents a line break that is part of the
content, as in a poem or address, rather than spacing between thematic groups.
Visual MD therefore emits a newline in the existing selectable span tree. It
does not create a widget, a new paragraph or a decorative gap
(`lib/api/render/inline_composer.dart`).

Lupton's *Marking Paragraphs* makes the typographic distinction operational: a
line break is used when the author needs a new line without the additional
space of a paragraph return. A hard break consequently adds exactly one body
beat. Consecutive hard breaks add consecutive beats; widow binding does not
rewrite across an authored line (`test/presentation/paragraph_setting_test.dart`).

## Backslash escapes

[CommonMark 0.31.2](https://spec.commonmark.org/0.31.2/#backslash-escapes)
defines the escape alphabet and its boundaries. A backslash may expose any
ASCII punctuation mark as literal text, but it stays visible before every
other character. An escaped backslash does not protect the delimiter after it;
a backslash at a line ending is instead a hard break. Escapes do not operate
inside code spans, code blocks, autolinks or raw HTML, while link destinations,
titles, reference definitions and fenced info strings do resolve them.

This is grammar, not a fourth emphasis signal. Lupton describes punctuation as
part of the standardised, rule-bound apparatus of the printed page and asks the
designer to replace manuscript notation with the marks it represents. Visual
MD follows that division: the source backslash disappears, then the exposed
punctuation enters the ordinary prose setting. Quotes may become typographic
quotes and manuscript dash or ellipsis sequences may be set normally; code and
autolinks remain literal because their grammar says they are literal
(`lib/api/render/inline_composer.dart`). The reader sees punctuation, never a
special “escaped” colour or run.

## Character references

[CommonMark 0.31.2](https://spec.commonmark.org/0.31.2/#entity-and-numeric-character-references)
defines named, decimal and hexadecimal references as alternate source
spellings for Unicode. It delegates the valid named set to WHATWG, requires a
semicolon, bounds decimal forms to seven digits and hexadecimal forms to six,
and replaces invalid scalar values with `U+FFFD`. Recognition is inactive in
code but active in destinations, titles and fenced info strings. Most
importantly, a decoded punctuation mark cannot retroactively become Markdown
structure.

The authoritative [WHATWG character-reference table](https://html.spec.whatwg.org/entities.json)
contains far more than the familiar `amp`, `copy` and `nbsp` names, including
values composed from multiple Unicode code points. Visual MD therefore
generates its domain lookup from that table and keeps only semicolon-terminated
keys; a partial handwritten dictionary would silently make the page and
outline disagree (`tool/generate_character_references.dart`).

There is no typographic style for an encoded character. CommonMark explicitly
permits parsers to discard whether Unicode came directly from source or from a
reference. Visual MD follows that semantic boundary: once decoded, the
character enters normal prose setting, search and navigation exactly as if the
author typed it directly.

## Plain Unicode text

[Unicode UAX #29](https://www.unicode.org/reports/tr29/) defines an extended
grapheme cluster as the practical unit for a user-perceived character. A base
plus combining marks, an emoji plus skin tone, a flag pair, and an emoji ZWJ
sequence can each contain several code points and still be one indivisible
reading unit. [Unicode UTS #51](https://unicode.org/reports/tr51/) makes the
emoji case explicit: every emoji sequence is one grapheme cluster. Visual MD
therefore composes prose and partitions search highlighting with Dart's
[`characters`](https://api.flutter.dev/flutter/package-characters_characters/)
implementation of those boundaries. A query may match one constituent in the
stored text, but the page paints the complete visible character; code and
prose remain exact strings.

[Unicode UAX #9](https://www.unicode.org/reports/tr9/) resolves bidirectional
text per paragraph. Rules P2 and P3 skip neutrals, numbers, and isolated
segments until the first strong `L`, `R`, or `AL` character establishes the
embedding level. Flutter requires that level as a
[`TextDirection`](https://api.flutter.dev/flutter/dart-ui/TextDirection.html)
to disambiguate mixed-script rendering and `TextAlign.start`. Visual MD
generates its strong-character ranges from Unicode 17's official
[`DerivedBidiClass.txt`](https://www.unicode.org/Public/17.0.0/ucd/extracted/DerivedBidiClass.txt)
rather than a BMP-only script heuristic, then applies the result independently
to paragraphs, headings, list items, table cells, and visible raw text
(`tool/generate_bidi_classes.dart`).

[Unicode UAX #14](https://www.unicode.org/reports/tr14/) treats combining
sequences as indivisible for line breaking and distinguishes the Western
space-and-hyphen model from East Asian text, where a line can generally break
between ideographs unless punctuation rules prohibit it. Visual MD leaves
those legal break choices to Flutter's text engine while preserving the
author's code-point sequence and supplying a real paragraph direction. Narrow
CJK prose can consequently reflow without inserted Western spaces or a break
inside a combining or emoji sequence.

Flutter's [`fontFamilyFallback`](https://api.flutter.dev/flutter/painting/TextStyle/fontFamilyFallback.html)
is an ordered search after the preferred family and before the platform's
default font. The bundled reading faces deliberately cover Latin; they should
not counterfeit scripts they do not draw. Visual MD names common native emoji,
Arabic, Hebrew, CJK and Indic reading faces for desktop hosts while preserving
the authored string (`lib/api/theme/library_theme.dart`). Flutter Web's
[open CanvasKit preload issue](https://github.com/flutter/flutter/issues/78422)
documents the different web boundary: the engine downloads its own split Noto
fallback and cannot preload it through the public API.

## Emphasis

[CommonMark 0.31.2](https://spec.commonmark.org/0.31.2/#emphasis-and-strong-emphasis)
defines emphasis through left- and right-flanking delimiter runs rather than a
simple pair of matching characters. A single asterisk or underscore may mark
emphasis when its edges satisfy those rules; whitespace at an interior edge
prevents it. The two spellings intentionally differ inside words:
`foo*bar*` may emphasize `bar`, while `foo_bar_` remains literal. Visual MD
delegates that grammar to the current CommonMark parser and carries either
valid spelling as one delimiter-free `InlineMark.emphasis`
(`lib/infrastructure/markdown/markdown_document_parser.dart`).

Lupton's *Hierarchy* supplies the visual rule already recorded above: italic
is the standard mark of emphasis, and an economy of signals gives emphasis one
cue rather than several. The legibility evidence also warns that italic slows
continuous reading, which fixes its scope: a phrase may change voice, a passage
must not. Visual MD therefore inherits every surrounding text property and
changes only `fontStyle`; it adds no weight, colour, size, box or spacing
(`lib/api/render/inline_composer.dart`).

## Strong emphasis

The same [CommonMark delimiter-run grammar](https://spec.commonmark.org/0.31.2/#emphasis-and-strong-emphasis)
applies to paired `**` and `__` runs. Double asterisks may delimit strength
inside a word, while double underscores may not; interior edge spaces still
invalidate the pair. Both valid spellings become the same delimiter-free
`InlineMark.strong` (`lib/infrastructure/markdown/markdown_document_parser.dart`).

Strong emphasis marks importance rather than a change of voice. Lupton's
economy of signals still permits only one cue, while the legibility evidence
above distinguishes the cue from italic: bold does not carry italic's measured
penalty in continuous reading. Visual MD therefore adds one weight and inherits
the surrounding colour, size, leading and decoration. A phrase can become
important without turning into a label or disturbing the reading grid
(`lib/api/render/inline_composer.dart`).

## Combined and nested emphasis

[CommonMark 0.31.2](https://spec.commonmark.org/0.31.2/#emphasis-and-strong-emphasis)
does not define triple delimiters as a third mark. Its ambiguity rules prefer
fewer nestings and, for a triple run, emphasis outside strength. The same rules
allow either role inside the other, resolve overlapping candidates by source
order, prefer the later opener when candidates share a closer, and use the
rule of three to prevent runs such as `*foo**bar*` from being split into marks
the author did not write. Code, links, images and HTML bind more tightly than
emphasis. Visual MD preserves the resulting recursive mark tree and removes
only the delimiter characters which that grammar consumed
(`lib/domain/reading/document_outline.dart`,
`lib/infrastructure/markdown/markdown_document_parser.dart`).

Typography does not need a new combined style. Lupton's economy of signals
still applies to each meaning: italic marks a local change of voice and weight
marks importance. When both meanings apply, the two inherited cues accumulate;
neither adds colour, size, a box, spacing or an accessibility label. The prose
remains one selectable line of thought even when its mark tree is several
levels deep (`lib/api/render/inline_composer.dart`).

## Strikethrough

The formal [GitHub Flavored Markdown specification](https://github.github.com/gfm/#strikethrough-extension-)
defines strikethrough as text wrapped by one or two tildes, ends the construct
at a new paragraph, and makes runs of three or more tildes literal. Visual MD
enforces that final boundary ahead of `package:markdown`, then carries either
eligible spelling as the same recursive `InlineMark.strikethrough`
(`lib/infrastructure/markdown/markdown_document_parser.dart`).

The [CSS Text Decoration specification](https://www.w3.org/TR/css-text-decor-4/)
names line-through as a continuous line through the middle of each line of
text and records editorial deletion as one of text decoration's traditional
uses. That is already the entire signal. Lupton's economy of signals gives no
reason to dim the words as well, and the legibility rule keeps body ink at its
full contrast. Visual MD therefore inherits colour, weight, style, size and
leading and adds only `TextDecoration.lineThrough`; search background remains
an independent paint layer (`lib/api/render/inline_composer.dart`).

## Inline links

[CommonMark 0.31.2](https://spec.commonmark.org/0.31.2/#links) defines an inline
link as visible link text followed immediately by a destination and an optional
title. The title may be double quoted, single quoted or parenthesised; link
components permit limited source-line separation but never a blank line. Link
labels may carry other inline roles, while links themselves cannot nest. That
grammar is the parser contract. Visual MD carries the resolved label,
destination and advisory title as separate data, so the label alone remains
reading text (`lib/domain/reading/content/inline.dart`,
`lib/infrastructure/markdown/markdown_document_parser.dart`).

[WCAG technique G182](https://www.w3.org/WAI/WCAG22/Techniques/general/G182)
uses an underline as the conventional non-colour cue for links, and
[Link Purpose in Context](https://www.w3.org/WAI/WCAG22/Understanding/link-purpose-in-context.html)
grounds that purpose in the visible link words and their context. Visual MD
therefore gives links accent plus underline and exposes those same visible
words as one actionable link to assistive technology. Inline code deliberately
loses its former underline: mono and code colour already say “technical
token,” while an underline should continue to mean “this can be followed”
(`lib/api/render/reading_theme.dart`,
`lib/api/render/inline_composer.dart`).

CommonMark explicitly permits zero inline elements in link text and allows the
title, text, and even destination to be omitted. That means an empty-label link
is valid data but has no words from which a reader can discover or understand
an action. Visual MD preserves the domain shape without manufacturing a
phantom hit target or accessible name.

For long labels, the [CSS Text overflow-wrapping model](https://www.w3.org/TR/css-text-3/#overflow-wrap-property)
provides the relevant reading rule: an otherwise unbreakable sequence may break
at an arbitrary point to prevent overflow, but a grapheme cluster stays whole
and no hyphen is invented. [WCAG Reflow](https://www.w3.org/WAI/WCAG22/Understanding/reflow.html)
keeps ordinary multi-line reading content in one scrolling direction. Visual
MD therefore lets the label reflow inside the prose measure while its hidden
destination and title contribute no geometry. Every rendered line remains part
of the same pointer and assistive action
(`lib/api/render/inline_composer.dart`).

The same CommonMark link chapter defines three reference forms:
[full](https://spec.commonmark.org/0.31.2/#full-reference-link),
[collapsed](https://spec.commonmark.org/0.31.2/#collapsed-reference-link), and
[shortcut](https://spec.commonmark.org/0.31.2/#shortcut-reference-link). Their
shared definition may appear before or after use and is not visible content.
Labels are limited to 999 source characters, must contain non-whitespace, and
match after formatting whitespace is collapsed and Unicode case is folded;
the first duplicate definition wins. Inline links take precedence, then full
and collapsed references, then shortcut references. A missing definition makes
no link and leaves the attempted notation literal. Visual MD treats these as
grammar differences only: every resolved form becomes the same `LinkRun`, and
the domain outline repeats the matching rule solely so a linked heading has the
same words and anchor in navigation as it has on the page
(`lib/domain/reading/link_label.dart`,
`lib/domain/reading/link_reference_definitions.dart`,
`lib/domain/reading/document_outline.dart`,
`lib/infrastructure/markdown/markdown_document_parser.dart`).

[CommonMark autolinks](https://spec.commonmark.org/0.31.2/#autolinks) make an
absolute URI or email address inside angle brackets one link whose label is the
inner spelling; email destinations gain `mailto:`. The grammar deliberately
rejects one-character schemes, whitespace and malformed addresses. The
[formal GFM extension](https://github.github.com/gfm/#autolinks-extension-)
adds bare `http://` and `https://` URLs, `www.` addresses and emails, with
specific left boundaries and trailing-punctuation rules. Visual MD delegates
valid recognition to the current GFM parser, maps every resulting anchor to
the existing `LinkRun`, and protects invalid angle-shaped candidates from the
parser's competing inline-HTML extension. That last boundary is why malformed
source stays readable instead of becoming an empty element
(`lib/infrastructure/markdown/markdown_document_parser.dart`).

GitHub's section-link rules cited under Heading rhythm also settle fragment
navigation. A fragment uses the generated anchor, not a search for heading
words; repeated headings are therefore addressed by `-1`, `-2`, and later
suffixes. Visual MD retains the fragment through `LinkRun` and
`ReaderController`, then the reading pane resolves it against the same anchor
keys that the outline uses (`lib/api/reader_controller.dart`,
`lib/api/widgets/reading_pane.dart`).

## Images

[CommonMark 0.31.2](https://spec.commonmark.org/0.31.2/#images) defines images
with the same inline, full-reference, collapsed-reference and
shortcut-reference shapes as links. The description becomes plain alternative
text: formatting and nested links contribute their words, not visual styling,
while an empty description remains valid. Visual MD therefore resolves every
source form to one `ImageRun`, flattens its authored reading words for `alt`,
and preserves an empty alternative as a deliberate decorative choice
(`lib/infrastructure/markdown/markdown_document_parser.dart`,
`lib/domain/reading/content/inline.dart`).

Flutter's [`Image.network`](https://api.flutter.dev/flutter/widgets/Image/Image.network.html)
and [`Image.memory`](https://api.flutter.dev/flutter/widgets/Image/Image.memory.html)
document the same layout constraint: an image needs bounded geometry, and
omitting a known width and height allows layout to change when pixels arrive.
CommonMark supplies neither dimension; reserving a fixed rectangle would
invent geometry and enlarge small artwork. Visual MD accepts that one local
reflow but bounds it: the reading measure horizontally, 72 percent of the
viewport vertically,
and [`BoxFit.scaleDown`](https://api.flutter.dev/flutter/painting/BoxFit.html)
to retain the intrinsic size whenever it already fits. Only the decode width
is requested, because specifying both decode axes can replace rather than preserve
the source aspect ratio. The painted child retains that natural geometry; its
outer box rounds up to a whole body line so later prose returns to the baseline
grid (`lib/api/widgets/document_image.dart`).

The same Flutter APIs supply `semanticLabel`, `excludeFromSemantics`, and
`errorBuilder`. Those map directly to the authored contract: a non-empty
alternative names successful artwork, an empty one is excluded as decorative,
and a failed provider paints the alternative rather than a raw exception. On
web, `WebHtmlElementStrategy.fallback` permits an HTML image when cross-origin
policy prevents CanvasKit from reading remote bytes. It is a rendering fallback
only; local document files still travel through the capability-bound
`DocumentImageLoader` (`lib/application/ports/document_image_loader.dart`,
`lib/api/widgets/document_image.dart`).

## Technical-document systems

[Geist Mono](https://github.com/vercel/geist-font) was designed for code
editors, diagrams, terminals and other interfaces where code is represented.
That is the medium Visual MD asks it to serve. Its bundled variable font is
licensed under the SIL Open Font License 1.1, and its measured x-height is
0.530 em. Visual MD normalises that metric before applying the code scale, so
the decision to set dense source three logical pixels below prose remains
independent of the face chosen. At the comfortable reading scale that is a
15 px face on a 22 px line, against prose at 18 px. The 13 px floor protects
punctuation when the reader chooses the smallest text setting. This absolute
scale expresses the project-specific hierarchy: paragraphs address the reader,
while code is a reference or example consulted from that prose.

[Primer](https://primer.style/product/primitives/typography/) sets inline code
at 0.9285 em so it inherits the role around it without shouting over the prose.
At Visual MD's comfortable 18 px scale that evidence lands close to a 17 px
inline face. The reader records that decision as an absolute one-logical-pixel
step from the surrounding role rather than retaining Primer's percentage.
Visual MD therefore normalises the surrounding face to its measured letter
size, subtracts one logical pixel, and normalises Geist Mono from that target.
The text takes the theme accent; where that falls below WCAG's 4.5:1 threshold,
it is mixed toward the theme's ink only until the threshold is met. No box,
padding, decoration or changed line height is added. The run remains real text,
so symbols, paths and commands all select, copy and reflow as part of the
sentence.

## Checklists

**Paul Fenton's ten commandments of typography** were used as an audit rather
than a source. Two failures they caught are fixed — widows were unhandled
(see [Widow Binding](09-widow-binding.md)), and headings mixed two bold
weights where one would do. One is knowingly unmet: the reader ships three
families, not two. A page itself remains a pair: the selected proportional
reading face and Geist Mono for functional code. Inter is furniture by default
and the reader's deliberate alternative proportional voice in Sans reading
mode.

## Mathematical notation

[GitHub's mathematical-expression syntax](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/writing-mathematical-expressions)
establishes the compatibility surface: `$…$` and `$`backticked`$` inline,
`$$…$$` as a display block, and a fenced `math` block. These are documented
GitHub extensions rather than formal CommonMark or GFM grammar. Visual MD
therefore claims them in its adapter without changing ordinary code spans,
code fences or malformed dollar text
(`lib/infrastructure/markdown/markdown_document_parser.dart`).

The same GitHub guide treats literal dollars and inline equations on one line
as an ambiguous surface and recommends marking the literal sign explicitly.
Ordinary financial prose with several currency amounts is not an equation,
however. Visual MD follows [Pandoc's documented dollar-math delimiter](https://pandoc.org/MANUAL.html#extension-tex_math_dollars):
a closing dollar cannot be followed immediately by a digit. This preserves
`$1 each = $0.50` without weakening ordinary
notation such as `$E = mc^2$`
(`lib/infrastructure/markdown/markdown_document_parser.dart`).

The [`katex` Flutter package](https://pub.dev/packages/katex) was chosen because
it parses to a pure-Dart box tree and paints with Flutter on Android, iOS,
Linux, macOS, web and Windows. It does not introduce a WebView, JavaScript
runtime, browser-only DOM, network font request or platform-specific rendering
path. The dependency is young, so Visual MD pins its exact version, contains it
behind one component and exercises notation from a real research paper rather
than treating a successful package import as proof of coverage
(`pubspec.yaml`, `lib/api/widgets/math_expression.dart`,
`test/presentation/math_expression_test.dart`).

Equations use the package's dedicated KaTeX font system, not Visual MD's prose
face: Main, Math Italic, AMS, extensible Size faces, Caligraphic, Fraktur,
Sans Serif, Script and Typewriter. The files ship with the package under the
SIL Open Font License and are application assets, so notation has no runtime
font download. KaTeX Main's x-height measures 0.431 em; normalising from that
value makes its lowercase mathematical letters optically agree with the text
role around them while preserving the type design drawn for formulas
(`lib/api/render/reading_theme.dart`).

## Mermaid diagrams

[Mermaid's syntax and configuration documentation](https://mermaid.js.org/intro/)
defines the authored fence language. Its accessibility syntax supplies
`accTitle` and `accDescr`, while its security guidance makes clear that
rendering policy belongs to the host. Visual MD retains those semantics but
does not mount Mermaid's browser DOM or execute authored actions.

[Merman](https://github.com/Latias94/merman) was selected as the headless
renderer because it exposes semantic parsing and SVG layout on native targets
without a WebView, and publishes the corresponding browser WASM binding. Its
[SVG pipeline contract](https://github.com/Latias94/merman/blob/main/docs/rendering/SVG_OUTPUT_PIPELINE.md)
distinguishes Mermaid-parity output, readable fallback output and
resource-closed resvg-safe output. Visual MD selects the latter, then plainly
owns the additional CSS-to-presentation-attribute normalization required by
Flutter's SVG painter (`lib/infrastructure/mermaid/svg_style_inliner.dart`).

Native uses the exact `merman` 0.7.0 Flutter package. Web vendors the exact
`@mermanjs/web-render` 0.8.0-alpha.5 artifact, its WASM binary, provenance and
licences so reading diagrams never depends on npm or a network request at
runtime. npm is used only at development or build time to reproduce the
ignored vendor tree from the committed lockfile
(`pubspec.yaml`, `web/package-lock.json`,
`bin/tools/prepare-web-assets.sh`). The prerelease
binding is pinned and contained rather than mistaken for a stable public
surface.

## Markdown compatibility

The formal [GFM table extension](https://github.github.com/gfm/#tables-extension-)
defines one header, a delimiter row and zero or more body rows. Outer pipes may
be inconsistent, cell space is trimmed, escaped pipes remain cell content,
inline roles are parsed normally, and a body row is padded or truncated to the
header width. Visual MD accepts those source variations as one `TableBlock`
contract before presentation decides width, overflow or typography
(`lib/infrastructure/markdown/markdown_document_parser.dart`).

Flutter's native `RenderTable` gives the surface its
[table role](https://api.flutter.dev/flutter/rendering/RenderTable/describeSemanticsConfiguration.html)
and [assembles row and cell roles](https://api.flutter.dev/flutter/rendering/RenderTable/assembleSemanticsNode.html).
Visual MD adds the missing column-header role to the authored head row, while
the page-level
[`SelectionArea`](https://api.flutter.dev/flutter/material/SelectionArea-class.html)
keeps cell text in the same selectable surface as the surrounding document
(`lib/api/render/document_view.dart`, `lib/api/widgets/reading_pane.dart`).

[CommonMark 0.31.2](https://spec.commonmark.org/0.31.2/#html-blocks) treats an
HTML block as raw source and separately defines
[raw inline HTML](https://spec.commonmark.org/0.31.2/#raw-html). That grammar
recognises syntax; it does not make arbitrary HTML appropriate for a native
reading surface. Formal GFM adds the
[tagfilter extension](https://github.github.com/gfm/#disallowed-raw-html-extension-),
which singles out tags such as `script`, `style`, `iframe`, and `textarea`
because they change parsing or embed another surface. Visual MD uses that list
as its minimum danger boundary: safe containers contribute only readable text,
comments remain authoring notes, and dangerous tags are displayed as inert
source rather than executed or silently flattened
(`lib/infrastructure/markdown/safe_html_text.dart`).

The boundary is structural, not a sanitizer bolted onto a WebView. The
`package:html` fragment parser builds an inert Dart tree inside infrastructure;
no DOM node, attribute, CSS declaration, event handler or executable behavior
reaches the domain or Flutter API. Each admitted URL belongs to a typed image
value with the same loader boundary as ordinary Markdown artwork.

[GitHub's current picture-element guidance](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#the-picture-element)
confirms that the element is supported. Its
[theme-context announcement](https://github.blog/changelog/2022-05-19-specify-theme-context-for-images-in-markdown-beta/)
establishes the portable authoring shape: a `picture`, ordered `source`
elements conditioned by `prefers-color-scheme`, and one `img` fallback that
owns the alternative. The [HTML Standard's picture model](https://html.spec.whatwg.org/dev/images.html)
likewise makes the container a selection context, chooses the first matching
source, and keeps `img` as the backwards-compatible fallback. Visual MD
implements the light/dark subset that its reading themes can answer. It does
not pretend to evaluate viewport queries, MIME support, CSS sizes, or the full
`srcset` density algorithm (`lib/infrastructure/markdown/safe_html_picture.dart`,
`lib/domain/reading/content/inline.dart`).

[GitHub's custom-anchor guidance](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#custom-anchors)
documents `<a name="unique-anchor-name"></a>` as a local target and states that
custom anchors do not appear in the outline or table of contents. Visual MD
therefore admits only the non-empty `name` as inert navigation identity; it
drops all other attributes, assigns no visible or semantic text, keeps
standalone custom identity independent from generated heading suffixes, and
leaves the target out of the outline. The standalone form is the supported
contract because its position can be keyed without inserting a selectable
placeholder or moving an anchor out of mixed raw content
(`lib/infrastructure/markdown/safe_html_text.dart`,
`lib/infrastructure/markdown/markdown_document_parser.dart`,
`lib/api/render/document_view.dart`).

[GitHub's current writing guide](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax)
documents `sub`, `sup`, and `ins` as supported inline writing forms. Visual MD
maps only properly paired forms onto typed recursive marks; arbitrary tags and
attributes do not inherit that authority
(`lib/infrastructure/markdown/markdown_document_parser.dart`).

The same guide's [footnote contract](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#footnotes)
places definitions at the end of the rendered document regardless of source
position and permits multi-line notes. Visual MD keeps the parser dependency's
first-reference ordering and return links, then uses its own domain anchors and
annotation typography rather than exposing the dependency's HTML-shaped tree
(`lib/infrastructure/markdown/markdown_document_parser.dart`,
`lib/api/render/document_view.dart`).

Flutter exposes subscript and superscript as the OpenType
[`subs` and `sups` font features](https://api.flutter.dev/flutter/dart-ui/FontFeature-class.html).
The bundled reading faces provide both substitutions. Applying the feature to
the inherited `TextStyle` uses glyphs designed by the font while preserving
the paragraph's size and line box; manually shrinking and baseline-shifting a
widget would break that rhythm. The same composition boundary gives `ins` one
inherited-ink underline while links retain accent plus underline as their
interaction signal (`lib/api/render/inline_composer.dart`).
The release gate reads each bundled font's GSUB table and requires both feature
tags (`test/presentation/bundled_scientific_feature_test.dart`). Custom theme
faces are outside that bundled guarantee and must provide the same two features
if their subscript and superscript meaning is to remain visible.

## Accessibility standards

WCAG 2.2 requires at least 4.5:1 contrast for ordinary text and asks reading
surfaces to tolerate text resizing without losing content. The built-in
palettes are measured against both paper and panel surfaces, and accessibility
scaling is included in the measure, baseline grid and hanging-punctuation
geometry rather than left to the final `Text` widget.

- [Contrast (Minimum), WCAG 2.2](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)
- [Visual Presentation, WCAG 2.2](https://www.w3.org/WAI/WCAG22/Understanding/visual-presentation.html)
- [Resize Text, WCAG 2.1](https://www.w3.org/WAI/WCAG21/Understanding/resize-text.html)
- [Reflow, WCAG 2.2](https://www.w3.org/WAI/WCAG22/Understanding/reflow.html) —
  a data table may keep its two-dimensional layout in its own scrollable
  region, while its individual cells still reflow and the surrounding page
  must not acquire horizontal scrolling.
