# Document Outline

## Purpose and boundary

`DocumentOutline.parse` reads a markdown string and returns the structure a
reader navigates by: front matter set aside, a `TableOfContents` of
`Heading`s, and the document cut into `Section`s at each heading
(`lib/domain/reading/document_outline.dart`,
`lib/domain/reading/document_outline.dart`). It does **not** render
markdown; rendering is the reading pane's job in
[API](../05-api/04-reading-pane.md). The outline exists so the table of
contents and the scroll targets come from one parse and always agree
([ADR 0004](../08-decisions/0004-sections-as-navigation-unit.md)).

## Present wiring

The private `_Parser` works line by line
(`lib/domain/reading/document_outline.dart`):

- **Line endings.** `\r\n` and lone `\r` are normalised to `\n` before
  splitting (`lib/domain/reading/document_outline.dart`).
- **Front matter.** If the first line is `---`, everything up to the next
  `---` or `...` line is front matter; the body starts after it. No closing
  fence means no front matter (`lib/domain/reading/document_outline.dart`).
- **Fenced code is skipped.** A fence opens with three or more backticks or
  tildes after up to three spaces; it closes only on a fence of the same
  character at least as long, so a four-backtick fence may contain a
  three-backtick fence (`lib/domain/reading/document_outline.dart`, `lib/domain/reading/document_outline.dart`).
- **ATX headings.** One to six `#` followed by whitespace; trailing closing
  hashes are stripped, and a heading of only hashes has empty text
  (`lib/domain/reading/document_outline.dart`, `lib/domain/reading/document_outline.dart`, `lib/domain/reading/document_outline.dart`).
- **Setext headings.** One or more uninterrupted paragraph lines followed by
  `=` (h1) or `-` (h2). The parser gathers the complete paragraph, beginning
  the section at its first source line, and stops when a fence, ATX heading,
  quotation, rule, list, table or reference definition interrupts it
  (`lib/domain/reading/document_outline.dart`). This is what keeps `---`
  rules, `|---|` table separators and list items out of the outline while a
  genuinely multi-source-line title remains one heading.
- **Inline cleanup.** Heading text drops images (keeping alt), links (keeping
  text), HTML tags, backticks, `**`, `__`, `*`, `~~`, and collapses
  whitespace (`lib/domain/reading/document_outline.dart`).
- **Anchors.** GitHub style: lowercase, keep letters, digits, spaces and
  hyphens, spaces to hyphens. Duplicates get `-1`, `-2`, …; an empty slug
  becomes `section`. The rule is not this parser's own — it lives in
  `HeadingAnchors` (`lib/domain/reading/heading_anchor.dart`), and the
  outline takes one counter per parse from it
  (`lib/domain/reading/document_outline.dart`,
  `lib/domain/reading/document_outline.dart`). The
  [content model](05-document-content.md) takes its anchors from the same
  rule, which is what makes a link found in the outline resolve on the page.
- **Reference definitions** (`[id]: url`) are collected outside fences
  (`lib/domain/reading/document_outline.dart`, `lib/domain/reading/document_outline.dart`).
- **Sections.** Each heading starts a section that includes its own heading
  line; text before the first heading is a heading-less section unless blank.
  Sections are no longer what the page renders — see
  [ADR 0004](../08-decisions/0004-sections-as-navigation-unit.md) — but the
  parser still produces them and they are still tested.
  When there is more than one section and any reference definitions exist,
  the definitions are appended to every section so links resolve wherever
  they appear (`lib/domain/reading/document_outline.dart`).
- **Title.** `title:` in front matter (quotes stripped), else the first h1,
  else `null` (`lib/domain/reading/document_outline.dart`).

`Heading` carries `level`, `text`, `anchor` and the zero-based source `line`
(`lib/domain/reading/heading.dart`). `TableOfContents` adds `baseLevel`
(shallowest level present) and `byAnchor`
(`lib/domain/reading/table_of_contents.dart`).

## Inputs and outputs

| Input | Headings | Sections | Title |
|-------|----------|----------|-------|
| `# Purpose and Status`, `## Purpose ##`, an h3 whose text mixes inline code, a link and bold | Purpose and Status (h1), Purpose (h2), `code and a link and bold` (h3); anchors `purpose-and-status`, `purpose`, `code-and-a-link-and-bold` | three | `Purpose and Status` |
| `Title` / `=====`, `Sub` / `---`, then `---`, a table, `- item` / `---` | Title (h1), Sub (h2) | two | `Title` |
| two paragraph lines / `====`, later two lines / `---` | one joined h1, one joined h2; source positions point to each first line | two | the joined h1 |
| `# Setup`, `## Setup`, `## Setup`, `## ???` | anchors `setup`, `setup-1`, `setup-2`, `section` | four | `Setup` |
| `intro`, `# One`, `## Two` | One, Two | three: the first has no heading | `One` |
| `---` / `title: "From Front Matter"` / `---` / `# Body Heading` | Body Heading at line 5 | one, without `tags:` | `From Front Matter` |
| empty string | none | none | `null` |

Each row is a fixture in `test/domain/document_outline_test.dart`.

## Events

None today; parsing an outline is a pure operation. If an opened-document event
is introduced, it belongs to [ReadDocument](../02-application/02-read-document.md),
which owns the completed reading operation.

## Lifecycle

Invoked lazily by `Document.outline` and cached on the document
(`lib/domain/library/document.dart`). A document is parsed at most once
per library build.

## Failure and recovery

- The parser does not throw. Malformed input degrades: an unterminated fence
  swallows the rest of the document (no headings after it); an unclosed
  front-matter block is treated as body text.
- Headings inside blockquotes (`> # x`) or indented four or more spaces are
  not headings, matching CommonMark.
- Splitting at headings can separate a construct from its context; reference
  definitions are the one case handled explicitly
  (`test/domain/document_outline_test.dart`).

## Transition

- Heading `line` numbers are recorded but unused by the UI today. They preserve
  source location for a future feature that has a concrete need for it.
- Front matter remains raw (`frontMatter` is a `String?`); only `title:` is
  interpreted. Any additional key should first have a defined product meaning.
- Headings inside HTML blocks are not excluded. Supporting HTML containers
  would require the outline and content parser to agree on their boundaries.
