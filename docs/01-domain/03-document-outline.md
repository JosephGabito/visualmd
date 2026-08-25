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
  text), HTML tags and genuine paired inline delimiters, then collapses
  formatting whitespace (`lib/domain/reading/document_outline.dart`). A
  delimiter-run resolver applies CommonMark's flanking, nesting, overlap and
  rule-of-three decisions, plus GFM's one- and two-tilde strikethrough, without
  importing a Markdown package into the domain ring. Nested marks are therefore
  removed recursively, while a literal pair such as the middle `**` in
  `*foo**bar*` and every tilde in `~~~literal~~~` remains part of the title. Code
  spans and autolinks are protected as literal regions before backslash
  escapes are resolved. Consequently `\*literal\*` keeps both stars,
  `\\*emphasis*` keeps one backslash but loses the genuine emphasis marks,
  and a slash inside code or an autolink stays authored text. Character
  references resolve only after real Markdown structure is removed, so
  `&#42;literal&#42;` keeps its visible stars without becoming emphasis.
  Escaped ampersands, code spans and autolinks are protected from that pass.
  Named references use the complete semicolon-terminated WHATWG table generated
  into the domain, while bounded decimal and hexadecimal forms become their
  Unicode scalar. Collision-free private placeholders keep this resolver
  framework-free while making the outline name the same heading the page
  presents (`lib/domain/reading/character_references.dart`,
  `lib/domain/reading/named_character_references.g.dart`,
  `lib/domain/reading/document_outline.dart`).
- **Autolink precedence.** Valid angle-bracket URI and email forms lose only
  their brackets, because the reader sees their complete inner spelling. GFM
  extended autolinks need no cleanup: their bare source is already their
  visible label. Malformed angle-shaped candidates are protected before the
  lightweight HTML cleanup, so `<m:literal>` and invalid email forms remain
  authored heading text rather than disappearing as empty tags. The same
  CommonMark patterns are held at the infrastructure adapter and domain
  outline boundaries so page text, title, anchor and outline cannot diverge
  (`lib/domain/reading/document_outline.dart`,
  `lib/infrastructure/markdown/markdown_document_parser.dart`).
- **Reference links.** Definitions are read before headings so a definition may
  appear above or below its use. Full, collapsed and shortcut notation loses
  its brackets only when its normalized label is actually defined; unresolved
  notation remains authored text. Whitespace collapsing and Unicode case
  folding come from `LinkLabel`, whose generated table is synchronized with
  the page parser. This keeps heading text, anchors, outline labels and the
  rendered page identical without importing a Markdown package into the domain
  (`lib/domain/reading/link_reference_definitions.dart`,
  `lib/domain/reading/link_label.dart`,
  `lib/domain/reading/link_label_case_folding.g.dart`,
  `lib/domain/reading/document_outline.dart`).
- **Anchors.** GitHub style: lowercase, keep letters, digits, spaces and
  hyphens, spaces to hyphens. Duplicates get `-1`, `-2`, …; an empty slug
  becomes `section`. The rule is not this parser's own — it lives in
  `HeadingAnchors` (`lib/domain/reading/heading_anchor.dart`), and the
  outline takes one counter per parse from it
  (`lib/domain/reading/document_outline.dart`,
  `lib/domain/reading/document_outline.dart`). The
  [content model](05-document-content.md) takes its anchors from the same
  rule, which is what makes a link found in the outline resolve on the page.
- **Sections.** Each heading starts a section that includes its own heading
  line; text before the first heading is a heading-less section unless blank.
  Sections are no longer what the page renders — see
  [ADR 0004](../08-decisions/0004-sections-as-navigation-unit.md) — but the
  parser still produces them and they are still tested. Each section is an
  exact source slice; the obsolete section renderer no longer requires
  reference definitions to be copied into other slices
  (`lib/domain/reading/document_outline.dart`).
- **Title.** `title:` in front matter (quotes stripped), else the first h1,
  else `null`. `DocumentOutline.titleOf` follows the same grammar but stops
  after finding that title; it does not build sections or a table of contents
  for an unopened document (`lib/domain/reading/document_outline.dart`).

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
| an h1 containing every escaped ASCII punctuation mark | every mark without its source backslash; the hyphen-only slug is `-` | one | the resolved punctuation |
| an h1 mixing named, decimal, hexadecimal, structural, escaped and code-literal references | valid prose references become Unicode; encoded structural marks stay text; protected forms stay source | one | the resolved reading text |
| headings with triple marks, marks inside marks, overlapping runs and escaped delimiters | nested grammar disappears; unmatched and rule-of-three delimiters remain reading text; anchors follow the resolved words | one per heading | the first resolved h1 |
| headings with one-, two-, three- and four-tilde runs, whitespace edges and nested roles | eligible strikethrough notation disappears; ineligible long runs and unmatched tildes remain reading text | one per heading | the resolved h1 |
| headings using full, collapsed, shortcut and missing reference forms, with definitions after them | resolved labels lose notation; missing labels keep it; anchors use exactly the page's words | one per heading | the first resolved h1 |
| headings containing angle URI and email autolinks, bare GFM autolinks, and malformed angle-shaped near misses | valid angle forms lose brackets; bare forms remain their visible source; near misses remain literal | one per heading | the first visible autolink label |
| `intro`, `# One`, `## Two` | One, Two | three: the first has no heading | `One` |
| `---` / `title: "From Front Matter"` / `---` / `# Body Heading` | Body Heading at line 5 | one, without `tags:` | `From Front Matter` |
| empty string | none | none | `null` |

Each row is a fixture in `test/domain/document_outline_test.dart`.

## Events

None today; parsing an outline is a pure operation. If an opened-document event
is introduced, it belongs to [ReadDocument](../02-application/02-read-document.md),
which owns the completed reading operation.

## Lifecycle

`DocumentOutline.titleOf` indexes the shelf title while a scanner holds one
source transiently. The complete outline is invoked lazily on the
source-backed document returned by `ReadDocument` and lives only as long as
that bounded reading-cache entry (`lib/domain/library/document.dart`,
`lib/application/use_cases/read_document.dart`). Their agreement is asserted
in `test/domain/document_outline_test.dart`.

## Failure and recovery

- The parser does not throw. Malformed input degrades: an unterminated fence
  swallows the rest of the document (no headings after it); an unclosed
  front-matter block is treated as body text.
- Headings inside blockquotes (`> # x`) or indented four or more spaces are
  not headings, matching CommonMark.
- Escape resolution is grammar, not styling. Once a slash exposes literal
  punctuation, the outline stores only that punctuation; no escape-specific
  domain type or visual treatment survives.
- Character-reference resolution is text decoding, not a second parse. A
  decoded delimiter never gains structural meaning, malformed forms remain
  authored text, and code or autolink literals are restored only after the
  decoding pass (`lib/domain/reading/character_references.dart`,
  `lib/domain/reading/document_outline.dart`).
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
