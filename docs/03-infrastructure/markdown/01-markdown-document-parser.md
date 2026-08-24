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
(`lib/infrastructure/markdown/markdown_document_parser.dart`). The nodes
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
| `pre` | `CodeBlock` | Language from `class="language-…"`; the fence's closing newline stripped (`lib/infrastructure/markdown/markdown_document_parser.dart`) |
| `blockquote` | `QuoteBlock` | Recurses, so a quotation holds real blocks (`lib/infrastructure/markdown/markdown_document_parser.dart`) |
| `ul`, `ol` | `ListBlock` | See below (`lib/infrastructure/markdown/markdown_document_parser.dart`) |
| `table` | `TableBlock` | `thead` rows become the head, the rest the body (`lib/infrastructure/markdown/markdown_document_parser.dart`) |
| `hr` | `RuleBlock` | (`lib/infrastructure/markdown/markdown_document_parser.dart`) |
| `section` | *unwrapped* | How footnote definitions arrive; only a wrapper (`lib/infrastructure/markdown/markdown_document_parser.dart`) |
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

**Tables.** Alignment is read from the cell's `align` attribute, with a
fallback that parses a `style` in case another syntax ever emits one
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

An element with no shape of its own — `sup`, inline HTML, a footnote reference
— has its children kept even though its markup is dropped
(`lib/infrastructure/markdown/markdown_document_parser.dart`).

A `code` run receives the content already normalised by the
[CommonMark code-span rules](https://spec.commonmark.org/0.31.2/#code-spans):
its closing delimiter must match the opening backtick run, line endings become
spaces, and one ordinary space is removed from both edges when both are
present. Literal backslashes, entity-looking text and inner backticks remain
source rather than becoming other inline syntax. The mapper carries that result
into `CodeRun` without another transformation
(`lib/infrastructure/markdown/markdown_document_parser.dart`).

## Inputs and outputs

| | Type | Notes |
|---|------|-------|
| In | `String markdown` | Any source; line endings normalised while front matter is stripped (`lib/infrastructure/markdown/markdown_document_parser.dart`) |
| Out | `DocumentContent` | Blocks in source order |

May import: `package:markdown`, the port, and the domain
(`lib/infrastructure/markdown/markdown_document_parser.dart`). No Flutter,
no `dart:io` — this adapter reads no bytes, only meaning.

## Events

None. Parsing is a deterministic conversion; the calling use case owns the
reader action around it.

## Lifecycle

`MarkdownDocumentParser` is `const` and stateless
(`lib/infrastructure/markdown/markdown_document_parser.dart`); it is
constructed once in `lib/main.dart` and reused.

All per-document state lives on the `_Mapper` created inside `parse`
(`lib/infrastructure/markdown/markdown_document_parser.dart`, `lib/infrastructure/markdown/markdown_document_parser.dart`).

## Failure and recovery

It does not throw. Markup with no mapping becomes `RawBlock`
(`lib/infrastructure/markdown/markdown_document_parser.dart`); an
unmapped inline keeps its words (`lib/infrastructure/markdown/markdown_document_parser.dart`); an empty document yields no
blocks.

One shared ambiguity is worth knowing: a document whose **first line is `---`
as a horizontal rule** is read as opening front matter and swallowed to the
next `---`. The outline parser has the same behaviour, so the reader is at
least self-consistent about it.

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

## Transition

The clearest extension points are footnotes, which currently arrive as an unwrapped
`section`, and inline HTML, which keeps its words but loses its markup. Both
would be new domain shapes first and mapping here second — the order matters,
because the model is what the renderer is written against.
