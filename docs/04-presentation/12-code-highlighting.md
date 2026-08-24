# Code Highlighting

## Purpose and boundary

`CodeHighlighter` is the framework-free contract between a fenced language and
optional syntax meaning (`lib/presentation/code/code_highlighter.dart`). It
lets the renderer ask for highlighting without importing Shiki, Flutter or a
package-owned token type into the presentation ring.

The contract owns source ranges, semantic roles, suggested foregrounds and a
human label. It does not own widgets, fonts, theme tokens, search backgrounds,
selection, copying or source text. Those remain with the reader.

## Present wiring

`ShikiCodeHighlighter` is the shipped adapter
(`lib/api/highlighting/shiki_code_highlighter.dart`). It contains every Shiki
type at the API edge and translates TextMate scopes into Visual MD roles such
as `comment`, `keyword`, `string`, `type`, `function` and `punctuation`.

The curated corpus covers web, application, systems, data and operations
languages: HTML, CSS, SCSS, JavaScript, TypeScript, JSX, TSX, PHP, Python,
Dart, Swift, Kotlin, Java, C#, Ruby, C, C++, Rust, Go, SQL, JSON, YAML, TOML,
XML, GraphQL, Bash, PowerShell, Dockerfile, diff and Markdown. Familiar aliases
such as `py`, `sh`, `c++`, `cs`, `yml` and `dockerfile` resolve to the same
grammar without changing the source.

Shiki prepares GitHub's light or dark grammar colours. Those colours are
suggestions rather than page authority. `ReadingTheme.codeToken` keeps colour
as the only syntax cue and moves an unsafe suggestion toward the active ink
only as far as ordinary-text contrast requires
(`lib/api/render/reading_theme.dart`). The active theme still owns the ground,
code face and rhythm.

`CodeHighlighting` carries offsets into the exact source. `InlineComposer`
adds every token boundary and every search-match boundary, then creates the
smallest spans that preserve both syntax foreground and search background
(`lib/api/render/inline_composer.dart`). Gaps remain ordinary code.

`PlainCodeHighlighter` is the kernel fallback. It labels the fence and returns
no ranges (`lib/presentation/code/code_highlighter.dart`). Plain text, an
unknown language and a failed adapter therefore share one normal result: the
source is readable without syntax colour.

## Inputs and outputs

`highlight` receives:

| In | Type | Meaning |
|----|------|---------|
| `source` | `String` | Exact code to classify, never rewrite |
| `language` | `String?` | Fence info string; only its first word selects a grammar |
| `scheme` | `CodeHighlightScheme` | Light or dark colour family, independent of Flutter |

It returns `Future<CodeHighlighting?>`. A non-null result contains ordered
`CodeHighlightToken` ranges with a semantic role and optional CSS hexadecimal
foreground. Null means “render plain source,” not an error.

`labelFor(language)` returns the quiet header name. Known aliases become a
human label; unknown identifiers remain visible so the reader does not hide
author metadata.

## Events

None. Highlighting classifies an immutable string and returns a value. It does
not announce document activity or mutate workspace state.

## Lifecycle

The composition root creates one `ShikiCodeHighlighter` and injects it through
the app, screen, pane and document renderer (`lib/main.dart`,
`lib/api/app.dart`). The adapter yields once so plain source can paint before a
cold grammar is decoded. Shiki caches loaded languages and themes; its web
worker is installed at `web/shiki_tokenize_worker.js`.

Each code block guards its own asynchronous request, so adapter reuse does not
allow a late token result to cross into another source
(`lib/api/widgets/code_block.dart`).

## Failure and recovery

The adapter catches grammar and worker failures and returns null. Tokens are
discarded when their offsets leave the source or their substring differs from
the source. The renderer independently rejects invalid ranges. This duplicate
validation is intentional: an enhancement package never becomes trusted with
the document's words.

The curated corpus and aliases are exercised by
`test/presentation/shiki_code_highlighter_test.dart`; plain and thrown
contributors, exact copying and search composition are exercised by
`test/presentation/code_block_test.dart`.

## Transition

More language grammars may join the curated catalog when real documents need
them. Theme authors do not receive token-colour fields: that would couple every
reading palette to every grammar role. A future highlighter may supply a
different semantic colour family behind this same source-range contract.
