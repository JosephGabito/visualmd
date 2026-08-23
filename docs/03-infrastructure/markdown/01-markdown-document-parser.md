# MarkdownDocumentParser

## Purpose and boundary

`MarkdownDocumentParser` implements
[Document Parser Port](../../02-application/04-document-parser-port.md): Markdown
source in, [Document Content](../../01-domain/05-document-content.md) out
(`lib/infrastructure/markdown/markdown_document_parser.dart:17-30`).

It owns exactly one thing: the mapping from `package:markdown`'s
HTML-shaped tree onto the domain's model. It decides nothing about how
anything looks — the author's text is carried across as written, and how it is
*set* is settled later in [Presentation](../../04-presentation/README.md)
(`lib/infrastructure/markdown/markdown_document_parser.dart:9-16`).

## Present wiring

`parse` builds an `md.Document` with the GitHub-flavoured extension set and
`encodeHtml: false` — the reader draws text, not HTML, and escaping here would
put `&amp;` on the page
(`lib/infrastructure/markdown/markdown_document_parser.dart:22-27`). The nodes
then go to a `_Mapper`, held apart from the parser so a document's anchor
numbering lives exactly as long as one parse and two documents never share it
(`lib/infrastructure/markdown/markdown_document_parser.dart:49-52`).

**Front matter** is set aside before parsing, matching how the
[Document Outline](../../01-domain/03-document-outline.md) does it: a `---` on
the first line, up to the next `---` or `...`
(`lib/infrastructure/markdown/markdown_document_parser.dart:32-46`).

**Blocks** are recognised by tag
(`lib/infrastructure/markdown/markdown_document_parser.dart:54-69`) and mapped
one by one (`:100-141`):

| Tag | Becomes | Notes |
|-----|---------|-------|
| `p` | `ParagraphBlock` | Empty paragraphs are dropped (`:102-104`) |
| `h1`–`h6` | `HeadingBlock` | Anchor taken from the *resolved* text, so `## The *shelf*` anchors as `the-shelf` (`:106-117`) |
| `pre` | `CodeBlock` | Language from `class="language-…"`; the fence's closing newline stripped (`:143-160`) |
| `blockquote` | `QuoteBlock` | Recurses, so a quotation holds real blocks (`:122-123`) |
| `ul`, `ol` | `ListBlock` | See below (`:162-183`) |
| `table` | `TableBlock` | `thead` rows become the head, the rest the body (`:204-225`) |
| `hr` | `RuleBlock` | (`:131-132`) |
| `section` | *unwrapped* | How footnote definitions arrive; only a wrapper (`:134-135`) |
| anything else | `RawBlock` | Its words survive even though its markup does not (`:137-139`) |

**Lists.** The package strips paragraph tags from the items of a *tight* list,
so a surviving `p` inside an `li` is exactly the author asking for air between
items — that is the `loose` signal
(`lib/infrastructure/markdown/markdown_document_parser.dart:170-172`). `start`
comes from the attribute, defaulting to 1 (`:180`). A task's tick arrives as an
`input` element, either directly under the item or tucked inside its first
paragraph, so the item's whole subtree is searched
(`:185-202`); the `input` itself is then dropped from the runs, because the
item already carries its state (`:284-286`).

**Tables.** Alignment is read from the cell's `align` attribute, with a
fallback that parses a `style` in case another syntax ever emits one
(`lib/infrastructure/markdown/markdown_document_parser.dart:227-240`).

**Runs** map tag by tag (`:242-303`), with two rules worth stating. A single
newline inside a paragraph becomes a **space**, never a break: treating it
otherwise would impose the source file's own wrapping on the page (`:246-249`).
And an element with no shape of its own — `sup`, inline HTML, a footnote
reference — has its children kept even though its markup is dropped
(`:288-297`).

## Inputs and outputs

| | Type | Notes |
|---|------|-------|
| In | `String markdown` | Any source; line endings normalised while front matter is stripped (`:36`) |
| Out | `DocumentContent` | Blocks in source order |

May import: `package:markdown`, the port, and the domain
(`lib/infrastructure/markdown/markdown_document_parser.dart:1-7`). No Flutter,
no `dart:io` — this adapter reads no bytes, only meaning.

## Events

None. Parsing is a deterministic conversion; the calling use case owns the
reader action around it.

## Lifecycle

`MarkdownDocumentParser` is `const` and stateless
(`lib/infrastructure/markdown/markdown_document_parser.dart:17-18`); it is
constructed once in `lib/main.dart` and reused.

All per-document state lives on the `_Mapper` created inside `parse`
(`lib/infrastructure/markdown/markdown_document_parser.dart:21-29`, `:51-52`).

## Failure and recovery

It does not throw. Markup with no mapping becomes `RawBlock`
(`lib/infrastructure/markdown/markdown_document_parser.dart:137-139`); an
unmapped inline keeps its words (`:288-297`); an empty document yields no
blocks.

One shared ambiguity is worth knowing: a document whose **first line is `---`
as a horizontal rule** is read as opening front matter and swallowed to the
next `---`. The outline parser has the same behaviour, so the reader is at
least self-consistent about it.

Behaviour is covered by 33 tests in
`test/infrastructure/markdown_document_parser_test.dart`, grouped by the shape
under test: paragraphs (`:18-51`), inline code (`:53-59`), headings and their
anchors (`:61-78`), code blocks (`:80-101`), quotations (`:103-110`), lists
(`:112-156`), tables (`:158-179`), the smaller shapes (`:181-201`) and the
document as a whole (`:203-234`).

## Transition

The clearest extension points are footnotes, which currently arrive as an unwrapped
`section`, and inline HTML, which keeps its words but loses its markup. Both
would be new domain shapes first and mapping here second — the order matters,
because the model is what the renderer is written against.
