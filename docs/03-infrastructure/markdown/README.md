# Markdown Adapter

This adapter gives meaning to the source text. It accepts a Markdown string and
returns the domain's document blocks, using `package:markdown` for CommonMark
parsing. The rest of Visual MD can then work with headings, paragraphs, lists,
tables, and code without depending on that package.

## On this shelf

| Document | What it introduces |
|----------|--------------------|
| [MarkdownDocumentParser](01-markdown-document-parser.md) | Mapping the parser package's syntax tree onto Visual MD's content model |

## Reading bytes and understanding them are separate jobs

The [Web Adapters](../web/README.md),
[Desktop Adapters](../desktop/README.md), and
[Memory Adapters](../memory/README.md) answer *where did this source come from,
and how can it be read?* The Markdown adapter starts after that work is done and
answers *what does the source say?*

It implements [Document Parser Port](../../02-application/04-document-parser-port.md)
rather than `FolderScanner`, so the same parser is used on every platform. Its
output is [Document Content](../../01-domain/05-document-content.md), made from
domain values while keeping the author's text intact.

| Direction | Value | Meaning |
|-----------|-------|---------|
| In | `String` | The source exactly as it was read from the file |
| Out | `DocumentContent` | The blocks and inline content understood by Visual MD |

Appearance comes later. The parser keeps authored characters unchanged; the
[Inline Composer](../../05-api/13-inline-composer.md) decides how those
characters are typeset on the page. That distinction lets search inspect what
the author wrote while the renderer applies typographic details for reading.

The adapter has no Flutter, filesystem, or browser dependency. Unsupported or
unfamiliar syntax degrades to the closest readable content instead of making
the document impossible to open, as described by
[Document Parser Port](../../02-application/04-document-parser-port.md).
