# MarkdownDocumentParser

## Purpose and boundary

`MarkdownDocumentParser` implements
[Document Parser Port](../../02-application/04-document-parser-port.md): Markdown
source in, [Document Content](../../01-domain/05-document-content.md) out
(`lib/infrastructure/markdown/markdown_document_parser.dart`).

It owns exactly one thing: the mapping from `package:markdown`'s
HTML-shaped tree onto the domain's model. It decides nothing about how
anything looks — the author's text is carried across as written, and how it is
*set* is settled later in [Presentation](../../04-presentation/README.md)
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

**Runs** map tag by tag (`lib/infrastructure/markdown/markdown_document_parser.dart`), with two rules worth stating. A single
newline inside a paragraph becomes a **space**, never a break: treating it
otherwise would impose the source file's own wrapping on the page (`lib/infrastructure/markdown/markdown_document_parser.dart`).
And an element with no shape of its own — `sup`, inline HTML, a footnote
reference — has its children kept even though its markup is dropped
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

## Transition

The clearest extension points are footnotes, which currently arrive as an unwrapped
`section`, and inline HTML, which keeps its words but loses its markup. Both
would be new domain shapes first and mapping here second — the order matters,
because the model is what the renderer is written against.
