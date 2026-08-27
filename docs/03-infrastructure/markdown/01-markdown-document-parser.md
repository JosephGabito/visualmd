# MarkdownDocumentParser

## Purpose and boundary

`MarkdownDocumentParser` implements
[Document Parser Port](../../02-application/04-document-parser-port.md): Markdown
source in, [Document Content](../../01-domain/05-document-content.md) out
(`lib/infrastructure/markdown/markdown_document_parser.dart`).

It owns exactly one thing: the mapping from `package:markdown`'s
HTML-shaped tree onto the domain's model. It decides nothing about how
anything looks — formatting whitespace is resolved into reading text while
authorial punctuation remains source, and how that text is *set* is settled
later in [Presentation](../../04-presentation/README.md)
(`lib/infrastructure/markdown/markdown_document_parser.dart`).

## Present wiring

`parse` builds an `md.Document` with the GitHub-flavoured extension set and
`encodeHtml: false` — the reader draws text, not HTML, and escaping here would
put `&amp;` on the page
(`lib/infrastructure/markdown/markdown_document_parser.dart`). A Visual MD-owned
block syntax preserves raw HTML as a typed adapter node before the dependency
can merge it into prose; matching inline syntaxes preserve harmless tag and
comment tokens as well as complete tagfiltered elements. `SafeHtmlText` then
reduces those nodes to inert reading text without allowing a DOM object,
attribute, style, event handler or executable URL across the infrastructure boundary
(`lib/infrastructure/markdown/markdown_document_parser.dart`,
`lib/infrastructure/markdown/safe_html_text.dart`). The one safe media form is
parsed separately: `SafeHtmlPicture` reduces GitHub's ordered light/dark
`source` elements and required fallback `img` to an `ImageRun`, without
admitting a browser DOM or general media-query engine
(`lib/infrastructure/markdown/safe_html_picture.dart`). A Visual MD-owned
inline syntax claims runs of three or more tildes before the dependency's
delimiter resolver can consume a shorter pair from them; formal GFM makes that
complete run literal (`lib/infrastructure/markdown/markdown_document_parser.dart`). The nodes
then go to a `_Mapper`, held apart from the parser so a document's anchor
numbering lives exactly as long as one parse and two documents never share it
(`lib/infrastructure/markdown/markdown_document_parser.dart`).

**Front matter** is set aside before parsing, matching how the
[Document Outline](../../01-domain/03-document-outline.md) does it: a `---` on
the first line, up to the next `---` or `...`
(`lib/infrastructure/markdown/markdown_document_parser.dart`).

**Blocks** are recognised by tag
(`lib/infrastructure/markdown/markdown_document_parser.dart`) and mapped
one by one (`lib/infrastructure/markdown/markdown_document_parser.dart`):

| Tag | Becomes | Notes |
|-----|---------|-------|
| `p` | `ParagraphBlock` | Empty paragraphs are dropped (`lib/infrastructure/markdown/markdown_document_parser.dart`) |
| `h1`–`h6` | `HeadingBlock` | Anchor taken from the *resolved* text, so `## The *shelf*` anchors as `the-shelf` (`lib/infrastructure/markdown/markdown_document_parser.dart`) |
| `pre` | `CodeBlock`, `MathBlock`, or `MermaidBlock` | Language from `class="language-…"`; `math` and `mermaid` fences become typed content; every other fence keeps code and has its closing newline stripped (`lib/infrastructure/markdown/markdown_document_parser.dart`) |
| `math` | `MathBlock` | TeX between paired `$$` display delimiters (`lib/infrastructure/markdown/markdown_document_parser.dart`) |
| `blockquote` | `QuoteBlock` | Recurses, so a quotation holds real blocks (`lib/infrastructure/markdown/markdown_document_parser.dart`) |
| `ul`, `ol` | `ListBlock` | See below (`lib/infrastructure/markdown/markdown_document_parser.dart`) |
| `table` | `TableBlock` | `thead` rows become the head, the rest the body (`lib/infrastructure/markdown/markdown_document_parser.dart`) |
| `hr` | `RuleBlock` | (`lib/infrastructure/markdown/markdown_document_parser.dart`) |
| `section.footnotes` | `FootnoteSectionBlock` | Definitions retain their blocks and first-reference order; an ordinary section remains a transparent wrapper (`lib/infrastructure/markdown/markdown_document_parser.dart`) |
| `raw-html-block` | `ParagraphBlock`, `RawBlock`, or nothing | A supported theme-aware `picture` becomes one image; safe containers contribute readable words; comments disappear; incomplete or unsupported pictures and dangerous tags remain visible as inert authored source (`lib/infrastructure/markdown/safe_html_picture.dart`, `lib/infrastructure/markdown/safe_html_text.dart`) |
| anything else | `RawBlock` | Its words survive even though its markup does not (`lib/infrastructure/markdown/markdown_document_parser.dart`) |

**Thematic breaks.** CommonMark's asterisk, hyphen and underscore forms all
arrive as `hr` and become the same textless `RuleBlock`. The syntax may use
three or more matching marks, spaces or tabs between them and up to three
leading spaces. Two marks, mixed marks, foreign characters and four-space
indentation do not become rules. The parser also preserves CommonMark's block
precedence: a hyphen line immediately under paragraph text is a Setext heading;
a valid rule elsewhere interrupts prose and wins over a competing list marker
(`lib/infrastructure/markdown/markdown_document_parser.dart`).

**Lists.** The package strips paragraph tags from the items of a *tight* list,
so a surviving `p` inside an `li` is exactly the author asking for air between
items — that is the `loose` signal
(`lib/infrastructure/markdown/markdown_document_parser.dart`). `start`
comes from the attribute, defaulting to 1 (`lib/infrastructure/markdown/markdown_document_parser.dart`). A task's tick arrives as an
`input` element, either directly under the item or tucked inside its first
paragraph, so the item's whole subtree is searched
(`lib/infrastructure/markdown/markdown_document_parser.dart`); the `input` itself is then dropped from the runs, because the
item already carries its state (`lib/infrastructure/markdown/markdown_document_parser.dart`).

**Tables.** Formal GFM permits omitted or inconsistent outer pipes and trims
formatting space beside each separator. The dependency establishes that
structure before the adapter maps the header, zero or more body rows, and every
cell's inline content. An escaped pipe therefore remains authored text even
inside code or emphasis, while emphasis, links and code cross the boundary as
their normal domain runs rather than exposed notation. Short rows are padded
to the header width and excess cells are discarded by the grammar. Alignment
is read from the cell's `align` attribute, with a fallback that parses a
`style` in case another syntax ever emits one
(`lib/infrastructure/markdown/markdown_document_parser.dart`). Left and right
remain physical GFM instructions rather than logical start and end: an Arabic
cell does not reverse the alignment the delimiter row authored
(`lib/domain/reading/content/block.dart`,
`lib/api/render/document_view.dart`).

**Mermaid.** A fenced block whose language is exactly `mermaid` becomes a
`MermaidBlock`; its body is not interpreted by this adapter. Removing only the
fence's terminal newline matches code-block source fidelity and leaves diagram
grammar, diagnostics and layout to the Mermaid renderer
(`lib/infrastructure/markdown/markdown_document_parser.dart`).

**Runs** map tag by tag (`lib/infrastructure/markdown/markdown_document_parser.dart`), with two rules worth stating.

An ordinary newline inside inline content is a **soft break**, never an authored
line. `_InlineLineBreaks` reads the complete inline subtree before mapping any
one text node, because the newline may sit at the edge of emphasis or a link. Spaces
and tabs beside it disappear. Scripts that separate words receive one space;
Chinese and Japanese source lines join without a Western word space. The result
is identical whether the editor hard-wrapped the source or kept the paragraph
on one line, so the page's measured column — not the source file — owns reflow
(`lib/infrastructure/markdown/markdown_document_parser.dart`). The same resolved
text is what document search indexes
(`lib/infrastructure/search/literal_document_search.dart`).

Two or more trailing spaces or a backslash instead creates a **hard break**:
one `LineBreakRun` whose text is a newline. The syntax works only within inline
content, never at the end of a paragraph, heading or code span. Leading spaces
and tabs on the next source line disappear even when the break crosses an
emphasis, link, quotation or list boundary. `_InlineLineBreaks` normalises that
indentation across the complete subtree rather than trusting the package's HTML
tree, whose leading spaces would collapse in a browser but remain visible in
Flutter (`lib/infrastructure/markdown/markdown_document_parser.dart`).

A backslash before ASCII punctuation is an **escape**, so the slash disappears
and the punctuation becomes ordinary `TextRun` content. A slash before a
letter, number, space or non-ASCII mark remains authored text; an escaped slash
leaves the following delimiter free to begin real markup. Escapes are inactive
inside code spans, code blocks and autolinks, but active in link destinations,
titles and fenced info strings. These are the grammar boundaries supplied by
`package:markdown`; the adapter preserves the resulting text and never creates
an escape-specific domain run. Adjacent text nodes created only by an escape
are coalesced before they cross the adapter, so ordinary quote, dash and
ellipsis setting can see one continuous prose phrase without crossing a real
role such as code, emphasis, a link or an authored line
(`lib/infrastructure/markdown/markdown_document_parser.dart`).

A valid **character reference** is another source spelling for ordinary
Unicode. Named forms use the complete semicolon-terminated WHATWG HTML table;
decimal and hexadecimal forms use CommonMark's bounded digit counts. The
parser package resolves them after block and inline structure is established,
which is why `&#42;foo&#42;` becomes visible stars without becoming emphasis or
a list marker. Code spans and blocks keep entity-looking source, while link
destinations, titles and fenced info strings resolve it. Malformed, unknown and
unterminated forms remain authored text. Adjacent decoded nodes are coalesced
like escaped punctuation, so encoded quotes and dots enter one continuous
typographic phrase (`lib/infrastructure/markdown/markdown_document_parser.dart`).
The framework-free outline mirrors the same ordering through
`CharacterReferences`, whose complete named table is reproducibly generated
from WHATWG rather than maintained by hand
(`lib/domain/reading/character_references.dart`,
`tool/generate_character_references.dart`).

**Plain Unicode.** Directly authored Unicode is not normalised or rewritten.
Precomposed and decomposed spellings, combining stacks, emoji sequences,
bidirectional scripts and unspaced CJK text remain the exact strings supplied
by the author. Grapheme-aware styling and paragraph direction belong to the
Flutter edge; this adapter only preserves the text it hands there
(`lib/infrastructure/markdown/markdown_document_parser.dart`).

**Emphasis.** CommonMark decides whether a single `*` or `_` delimiter run is
left- or right-flanking before this adapter sees it. Both valid spellings arrive
as `em` and become the same `InlineMark.emphasis`; invalid, mismatched and
unmatched delimiters remain ordinary text. The distinction inside words is
preserved: an asterisk may delimit `foo*bar*`, while an underscore in
`foo_bar_` remains literal so identifiers are not silently restyled
(`lib/infrastructure/markdown/markdown_document_parser.dart`).

Double delimiter runs follow the same flanking grammar for **strong
emphasis**. Valid `**` and `__` pairs arrive as `strong` and become
`InlineMark.strong`; interior spaces, mismatched pairs and unmatched pairs stay
visible. Double asterisks may work inside a word, while double underscores do
not, preserving identifier-like text such as `foo__bar__`
(`lib/infrastructure/markdown/markdown_document_parser.dart`).

Delimiter runs remain a tree when the grammar nests them. Triple delimiters
prefer emphasis around strength; either mark may contain the other; and deeper
valid nesting remains recursive `MarkedRun` children. CommonMark's precedence
and rule of three decide which characters were syntax before this adapter sees
the tree. It therefore removes no delimiter itself: genuine syntax is absent,
while literal notation such as the middle `**` in `*foo**bar*` remains in a
`TextRun` (`lib/infrastructure/markdown/markdown_document_parser.dart`).

GFM **strikethrough** accepts either one or two tildes. Eligible left- and
right-flanking runs, including runs inside a word, arrive as `del` and become
the same `InlineMark.strikethrough`; a shorter eligible pair may leave an
unmatched tilde as reading text. An interior whitespace edge prevents the mark,
a blank line ends its search for a closer, and a run of three or more tildes is
literal in full. Strong, code and link runs inside the deletion remain nested
rather than flattened (`lib/infrastructure/markdown/markdown_document_parser.dart`).

An **inline link** arrives as `a` and becomes one recursive `LinkRun`: resolved
label children, destination, and an optional advisory title. CommonMark admits
double-quoted, single-quoted and parenthesised titles, with at most one source
line ending between components; a blank line leaves the attempted link literal.
Escapes and character references have already served the grammar. The package's
HTML-shaped node protects a quote in an attribute as `&quot;`, so the adapter
decodes the title once more before it crosses into the domain. The visible label
remains the run's only reading text, and CommonMark's prohibition on nested
links leaves the inner valid link as the interaction when link notation
overlaps (`lib/infrastructure/markdown/markdown_document_parser.dart`).

Full (`[words][label]`), collapsed (`[words][]`) and shortcut (`[words]`)
**reference links** arrive as that same `a` element and therefore cross the
adapter as the same `LinkRun`. Their source spelling has already served the
grammar and creates no second domain or presentation component. Definitions
may precede or follow a use and never become blocks of their own. Labels match
after formatting whitespace is collapsed and Unicode case is folded; the first
duplicate definition owns the label. A missing definition resolves nothing, so
its brackets remain authored reading text. Full and collapsed forms take
precedence over shortcut interpretation, while an inline destination takes
precedence over all reference forms
(`lib/infrastructure/markdown/markdown_document_parser.dart`).

CommonMark **autolinks** place an absolute URI or email address inside angle
brackets. GFM's extension additionally recognises bare `http://` and
`https://` URLs, `www.` addresses and email addresses. Every valid form arrives
as the same `a` element and therefore the same `LinkRun`; a bare `www.` label
receives an `http://` destination, while either email spelling receives
`mailto:`. Sentence punctuation excluded by the GFM grammar remains an adjacent
`TextRun`, and search indexes only the visible spelling. A small adapter syntax
claims malformed angle-shaped near misses before the package's inline-HTML
extension can swallow them: candidates such as a one-character URI scheme or
an invalid email remain authored text on the page exactly as they do in the
framework-free outline (`lib/infrastructure/markdown/markdown_document_parser.dart`).

Link text may contain zero inline children. A destination outside angle
brackets is non-empty, space-free text whose parentheses balance; inside angle
brackets it may be empty or contain spaces. The adapter neither truncates a
long destination nor lets it enter reading text. Punctuation inside a valid
title is ordinary resolved metadata, including escaped delimiters and character
references. An empty label therefore becomes an empty `children` list rather
than malformed text, while a malformed destination remains visible source
(`lib/infrastructure/markdown/markdown_document_parser.dart`).

A `sup.footnote-ref` becomes a typed `FootnoteReferenceRun` only when its
number, definition fragment and unique return id are complete. Other elements
with no shape of their own keep their children even though the surrounding
markup is dropped (`lib/infrastructure/markdown/markdown_document_parser.dart`).

The package carries non-ASCII footnote labels as percent-encoded HTML ids. The
adapter decodes references, returns, and definitions into the same local
identity, then restores definition order from the ordinals assigned at first
reference. Generated `a.footnote-backref` elements become typed return runs so
their arrow can be announced by meaning rather than punctuation alone
(`lib/infrastructure/markdown/markdown_document_parser.dart`).

**Raw HTML is syntax, never a browser surface.** CommonMark raw blocks and
inline tokens are claimed before `package:markdown` can make them
indistinguishable from prose. Harmless container tags and every attribute are
discarded while their readable descendants remain in source order. Comments
carry authoring information rather than reading content and therefore produce
nothing. The GFM tagfilter set — including `script`, `style`, `iframe` and
`textarea` — remains visible as exact inert source instead of being flattened
into a misleading payload. Safe malformed markup follows the HTML5 fragment
parser's recovery rules and contributes the readable words it can recover; an
unexpected parser failure falls back to visible source rather than escaping the
adapter. No HTML parser object crosses into the domain or Flutter API
(`lib/infrastructure/markdown/safe_html_text.dart`,
`test/infrastructure/safe_html_text_test.dart`).

One inert attribute has a typed meaning: GitHub documents an opening `a` with
a non-empty `name` as a custom local target. The adapter decodes that name,
drops every other attribute, and promotes a standalone pair from CommonMark's
inline-only paragraph into an `AnchorBlock`. Whitespace between consecutive
aliases is metadata too, so it cannot create a blank line. Inline anchors and
anchors inside mixed raw HTML remain visually absent but do not become targets:
the adapter cannot preserve their exact geometry without corrupting selectable
text or relocating the target. An anchor-only safe HTML container remains
eligible because it has no reading geometry to lose. The first repeated custom
name wins, independently of the counter used for duplicate headings
(`lib/infrastructure/markdown/safe_html_text.dart`,
`lib/infrastructure/markdown/markdown_document_parser.dart`).

One inert media container also has a typed meaning. A standalone `picture`
must end with exactly one `img` carrying a non-empty fallback source and an
authored `alt` attribute. Earlier `source` children contribute candidates only
when their media query is exactly `prefers-color-scheme: light` or `dark` and
their `srcset` contains one undecorated URL. Candidate order is retained;
unsupported media queries, MIME conditions, and browser density descriptors
fall through to the fallback rather than being guessed. An incomplete authored
container, missing fallback semantics, mixed content, or unsafe descendants
keep the complete picture-shaped source visible and inert
(`lib/infrastructure/markdown/safe_html_picture.dart`,
`lib/infrastructure/markdown/markdown_document_parser.dart`).

A `code` run receives the content already normalised by the
[CommonMark code-span rules](https://spec.commonmark.org/0.31.2/#code-spans):
its closing delimiter must match the opening backtick run, line endings become
spaces, and one ordinary space is removed from both edges when both are
present. Literal backslashes, entity-looking text and inner backticks remain
source rather than becoming other inline syntax. The mapper carries that result
into `CodeRun` without another transformation
(`lib/infrastructure/markdown/markdown_document_parser.dart`).

GitHub-style **mathematics** is claimed before ordinary Markdown consumes its
delimiters. `$…$` and `$`backticked`$` become `MathRun`; `$$…$$`, a multiline
pair of `$$` lines and a fenced `math` block become `MathBlock`. The adapter
removes only the notation that established the role and preserves the inner
TeX exactly. Inline notation never crosses a source line, code spans retain
literal dollar signs, and an escaped or unclosed delimiter remains ordinary
authored text. A dollar followed immediately by a digit starts a currency
amount rather than closing an earlier equation, so prose such as `$1 each =
$0.50` cannot become invented mathematics. An unclosed display opener likewise
remains a paragraph instead of swallowing the remainder of the document
(`lib/infrastructure/markdown/markdown_document_parser.dart`).

## Inputs and outputs

| | Type | Notes |
|---|------|-------|
| In | `String markdown` or exact appended source | Completed source is parsed once; a session reparses only its unfinished suffix (`lib/infrastructure/markdown/markdown_document_parser.dart`) |
| Out | `DocumentContent` | Blocks in source order; sessions add stable identity, revision, and commitment |

May import: `package:markdown`, the inert `package:html` fragment parser, the
port, and the domain (`lib/infrastructure/markdown/markdown_document_parser.dart`,
`lib/infrastructure/markdown/safe_html_text.dart`). No Flutter, no `dart:io` —
this adapter reads no bytes and mounts no browser surface; it only carries
meaning inward.

## Events

None. Parsing is a deterministic conversion. Successive session snapshots carry
`DocumentMutation`, but the calling coordinator owns stream events and the
reader action around them.

## Lifecycle

`MarkdownDocumentParser` is `const` and stateless for complete documents
(`lib/infrastructure/markdown/markdown_document_parser.dart`); it is
constructed once in `lib/main.dart` and reused. `startSession()` creates state
for exactly one append-only generation: chunked source, committed reference
context, heading-anchor history, and a provisional suffix.

All per-document state lives on the `_Mapper` created inside `parse`
(`lib/infrastructure/markdown/markdown_document_parser.dart`, `lib/infrastructure/markdown/markdown_document_parser.dart`).
In a session, ordinary paragraphs settle after a blank line. Open containers
remain provisional until a following top-level block proves their boundary.
Finishing runs the complete parser once and commits the canonical result.

## Failure and recovery

It does not throw. Markup with no mapping becomes `RawBlock`
(`lib/infrastructure/markdown/markdown_document_parser.dart`); an
unmapped inline keeps its words (`lib/infrastructure/markdown/markdown_document_parser.dart`); an empty document yields no
blocks. Raw HTML fragment failure follows the same contract and returns inert
source (`lib/infrastructure/markdown/safe_html_text.dart`).

The adapter does not validate TeX. A syntactically complete math delimiter can
still contain notation unsupported by the page's renderer; preserving it as a
typed domain value lets presentation recover locally without changing parser
behavior or losing the author's source.

One shared ambiguity is worth knowing: a document whose **first line is `---`
as a horizontal rule** is read as opening front matter and swallowed to the
next `---`. The outline parser has the same behaviour, so the reader is at
least self-consistent about it.

Late chunks after `finish()` throw `StateError`. A newly committed link or
footnote definition may change an earlier inline, so that uncommon operation
performs a full semantic rebase. Ordinary appends visit only the new chunk plus
the provisional tail. The measured work is exposed as
`lastParsedSourceLength`; the performance test fixes a five-thousand-paragraph
prefix and proves the next append parses only its new tail
(`test/infrastructure/incremental_markdown_parser_test.dart`).

Behaviour is covered in
`test/infrastructure/markdown_document_parser_test.dart`, grouped by the shape
under test: paragraphs (`test/infrastructure/markdown_document_parser_test.dart`), inline code (`test/infrastructure/markdown_document_parser_test.dart`), headings and their
anchors (`test/infrastructure/markdown_document_parser_test.dart`), code blocks (`test/infrastructure/markdown_document_parser_test.dart`), quotations (`test/infrastructure/markdown_document_parser_test.dart`), lists
(`test/infrastructure/markdown_document_parser_test.dart`), tables (`test/infrastructure/markdown_document_parser_test.dart`), the smaller shapes (`test/infrastructure/markdown_document_parser_test.dart`) and the
document as a whole (`test/infrastructure/markdown_document_parser_test.dart`).
The soft-break group adds indentation, inline-boundary, container, CJK,
Japanese, Korean, Arabic, Hebrew and code-span boundaries. The hard-break group
covers both spellings, excess whitespace, consecutive lines, inline roles,
containers, headings, code spans and block endings;
`test/infrastructure/literal_document_search_test.dart` and
`test/presentation/paragraph_setting_test.dart` prove the resolved text remains
the same through search and layout. The backslash-escape group exercises every
ASCII punctuation mark, non-escapable characters, block and inline delimiters,
code, links, autolinks, destinations, titles and fence info strings. The
application test then requires the page and outline to derive identical text
and anchors from escaped headings. The character-reference group adds the
official named and numeric specimens, invalid forms, structural punctuation,
code, link metadata and fence info; domain, application, search and
presentation tests then require the decoded character to remain the same
through every consumer.
The inline-link group covers optional and all three title forms, one-line and
blank-line boundaries, escapes and references in metadata, recursive label
roles, and the inner-link precedence rule. Search proves that only the visible
label is indexed; the controller keeps fragment, document and external targets
distinct; application and composer tests keep the same label in the outline,
page, pointer target and accessibility tree.
The hostile extension adds a long destination with nested parentheses and URL
data, an empty label, and punctuation-rich resolved title metadata. Layout
coverage makes a long unbroken label reflow inside a narrow measure, taps every
rendered line, and verifies that the complete phrase remains one accessibility
node while the empty label creates no invisible action.

## Transition

The stream coordinator is next: ordered sequence validation, adaptive batching,
cancellation, and stale-generation fencing belong outside this adapter. Outline
and search must then consume the same block mutations. A reference-dependency
index can eventually replace the correct but intentionally global semantic
rebase with updates to only affected blocks.
