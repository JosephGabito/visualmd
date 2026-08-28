# Backlog

Known work, classified by the vocabulary in
[the plugin architecture](01-plugin-architecture.md). *Ring(s)* names the
rings a change touches. A change within one ring is the most localized; one
that touches `domain` begins by modelling the reader-facing rule.

## Kinds

- **Kernel fix** — the current reader has a gap a reader notices.
- **Reactor / contributor / slot** — plugins, as defined in the plugin architecture.
- **Platform** — a new or improved target.
- **Packaging** — getting a build into other people's hands.

## Items

| Item | Kind | Ring(s) | Notes |
|------|------|---------|-------|
| Let code blocks run wider still | Kernel fix | api | Done in part: code and tables already get 1.35 × the prose column (`lib/api/render/reading_theme.dart`). The factor is a judgement, not a measurement, and on a large screen there is room to go further. |
| Copy tables as structured text | Kernel fix | api | Cells participate in the page selection surface and expose native table semantics, but Flutter joins separate selectables without restoring row or cell separators. A complete interaction must place tabs between cells and newlines between rows without breaking ordinary cross-block selection (`lib/api/render/document_view.dart`, `lib/api/widgets/reading_pane.dart`). |
| Read font metrics rather than transcribe them | Kernel fix | api | The x-heights, cap heights and descenders are hand-copied from each font's `OS/2` table (`lib/api/theme/font_metrics.dart`). A face added to `pubspec.yaml` without an entry is silently un-normalised. Reading the table at startup removes the failure mode, at the cost of parsing font binaries. |
| Primes rather than quotes | Kernel fix | presentation | `5'2"` is set with typographic quotes today (`lib/presentation/theme/typographic_punctuation.dart`); a typographer would want hatch marks. Needs a rule that looks at what precedes the mark. |
| Reader control of the measure | Kernel fix | presentation, api | Body size is a reader setting; the measure is still fixed (`lib/presentation/theme/reading_scale.dart`). It is already a parameter, so this is wiring rather than redesign. Leading is no longer a candidate: it is derived from the face's own metrics. |
| Recents in the shelf | Reactor + slot | infrastructure, api | Subscribe to `DocumentOpened`; render the list in the shelf-panel slot. |
| Windows custom chrome | Slot | infrastructure, api | Hide the Windows title bar as macOS does, then paint minimise / maximise / close — a later top-bar slot contributor. |
| Reload themes without a restart | Kernel fix | infrastructure, api | Theme files are read once at startup (`lib/main.dart`). Watching the folder, or a Reload item in the theme menu, would make authoring a theme a live loop. |
| macOS signing and notarization | Packaging | none | Needs an Apple Developer account. Adds a signing identity to the Xcode project and a notarization step after `flutter build macos`. |
| Chrome extension | Platform | infrastructure | A fourth adapter family. Build with `--csp --no-web-resources-cdn`, strip the `<base href>` from `web/index.html`, bundle fonts, and request the file URL permission so local markdown opens in the reader. |
| Windows build verification | Platform | none | The target is scaffolded and named (`windows/runner/main.cpp`) but has never been compiled; needs a Windows machine with the Visual Studio Desktop C++ workload. |
| Complete emoji coverage on Flutter Web | Platform | api | Unicode sequences remain intact and desktop builds use native emoji fallbacks, but CanvasKit owns a separate split Noto fallback. Some newer sequences can still render as missing-glyph boxes. Flutter's public preload API remains open, while adding the full colour font as an app asset would add roughly 20 MB and bypass its lazy-loading design. |

## Done

| Item | Landed as |
|------|-----------|
| Full-document select all on a lazy page | `ModelBackedSelectionArea` snapshots `DocumentContent.text` only when Select All is invoked, forwards the action for native visible feedback, and copies every mounted or unmounted block with domain separators intact. Streaming appends do not move the captured end (`lib/api/widgets/model_backed_selection_area.dart`, `lib/api/widgets/reading_pane.dart`). |
| Tables on the beat | Rows retain the height their content needs; the completed table plus its forward-owned external gap reconcile as one departure. Following prose returns in phase without padding every row. See [Vertical Rhythm](../04-presentation/11-vertical-rhythm.md). |
| Mermaid diagrams | A typed `mermaid` fence renders through pinned headless native and web engines into inert themed SVG. The page owns bounded fit, drag pan, wheel or pinch zoom, reset, full screen, source copying, accessibility, caching and exact-source recovery. See [Mermaid Diagram](../05-api/26-mermaid-diagram.md). |
| Mathematical expressions | GitHub-style inline and display delimiters become typed domain content; KaTeX's dedicated math fonts paint them on every target; the page owns optical size, local overflow, source copying, semantics, failure recovery and grid reconciliation. See [Mathematical Expression](../05-api/25-mathematical-expression.md). |
| Document images | Inline and reference images share one domain shape; local sources resolve against the Markdown directory through an application port; desktop, browser and sample adapters keep source authority at the edge; remote and oversized artwork stays bounded; every loading failure preserves the authored alternative. See [Document Image](../05-api/23-document-image.md). |
| Footnotes | GitHub references and definitions are typed document content with bidirectional anchors, first-reference numbering, multi-paragraph structure, smaller annotation typography, accessibility, and final grid reconciliation. See [Footnotes](../05-api/27-footnotes.md). |
| Reveal the themes folder | The theme menu presents one **Open themes folder** action instead of exposing the sandbox path. Desktop delegates the directory to the operating system; web omits the unavailable action (`lib/api/widgets/theme_picker.dart`, `lib/infrastructure/platform/platform_io.dart`). |
| Structured themes | A `ReaderTheme` contract, six built-ins, a registry that loads user JSON files, a picker, and a persisted choice. The seams live in the `presentation` ring (`lib/presentation/theme/reader_theme.dart`), which may import no package, so the `api` ring binds them to Flutter and a theme stays data. See [Presentation](../04-presentation/README.md) and [Creating a Theme](../09-contributing/05-creating-a-theme.md). |
| Bundle fonts as assets | Alegreya, Literata, Inter and Geist Mono ship inside the app as variable fonts with their OFL notices (`pubspec.yaml`), registered for the licence page (`lib/api/theme/font_licences.dart`). Unsupported theme families fall back locally; the app never fetches a font at runtime (`lib/api/theme/library_theme.dart`). Text draws with no network and no flash of a fallback face — and the metrics became measurable, which is what everything after it was built on. |
| A reading face chosen for the medium | The page is set in Alegreya, drawn for literature and long-form text (`lib/presentation/theme/theme_typefaces.dart`); Literata stays bundled and selectable. The supporting research is recorded in [Sources](../04-presentation/10-sources.md), alongside the larger effects of measure, leading, and rhythm. |
| Sizes and leading derived from the face | A size is a size of *letters*: the font size that delivers it is worked out per face from its x-height, and the line height from its cap height, descender and x-height ([Font Metrics](../05-api/16-font-metrics.md), `lib/api/theme/font_metrics.dart`). Measuring caught body text rendering about 7 % smaller than the sans beside it. |
| Vertical rhythm on a real grid | Every gap is a whole number of body lines, heading boxes round up to one, and compact code surfaces reconcile their completed height — with a strut holding prose line boxes so an inline code span cannot push a line off the beat ([Vertical Rhythm](../04-presentation/11-vertical-rhythm.md)). The invariant is a test, and it caught three separate sources of drift, including the beat being measured in a unit the page never used. |
| Tone under size and weight | `h1` darkest through to `h5` and `h6` receding, written as a distance towards ink or away from it so it does not invert on a dark page (`lib/api/render/reading_theme.dart`). The body is never dimmed. |
| Hanging punctuation and first-line indents | Both are done, and neither needed the text-engine feature they seemed to. The indent goes into the flow as a `WidgetSpan`, so it moves the first line and nothing else; the opening mark is taken out of the flow and painted at `indent - hang` in a `Stack`, so the words start on the column edge (`lib/api/render/document_view.dart`). Which marks hang and how far is a table in the presentation ring ([Hanging Punctuation](../04-presentation/08-hanging-punctuation.md)); when a paragraph indents is a rule in the renderer ([Document View](../05-api/12-document-view.md)). **What remains:** only a paragraph's *opening* mark hangs. A line further down that happens to begin with a quotation mark stays in the column, because hanging those needs per-line control Flutter does not expose. |
| Widows | The last two words of a paragraph are bound with a non-breaking space so neither is left standing alone ([Widow Binding](../04-presentation/09-widow-binding.md)). The remedy is applied whenever a paragraph is long enough rather than only when the last line would hold one word, which needs the laid-out line. |
| Measured typography | A [Reading Scale](../04-presentation/07-reading-scale.md) in the presentation ring: the column set to 66 characters of the face actually in use rather than a fixed 760 px, no heading smaller than body, and a reader-chosen body size. The optical-size axis is driven from the rendered size (`lib/api/theme/library_theme.dart`). |
| Scaler-aware geometry | Accessibility text scaling now participates in the measured column, baseline grid, heading line boxes, indentation and hanging punctuation (`lib/api/render/reading_theme.dart`, `lib/api/render/reading_theme.dart`). The page no longer draws enlarged text inside geometry calculated for its unscaled size. |
| Compact reading shell | Below 1180 px the document keeps the full content width and the shelf or outline opens as a single overlay, never both (`lib/api/screens/reader_screen.dart`, `lib/api/screens/reader_screen.dart`). |
| Built-in contrast guard | Shipped ink, muted and accent text pairs are tested at WCAG's 4.5:1 threshold on their real paper and panel surfaces (`lib/presentation/theme/theme_palette.dart`, `test/presentation/theme_test.dart`). |
| In-app search | Current-document find highlights and navigates rendered text; whole-library find groups literal results in the shelf and opens the chosen occurrence. The application owns the scope through a port, while the Dart adapter remains replaceable by an index later. See [Search](../05-api/17-search.md). |
| Syntax highlighting | A framework-free `CodeHighlighter` contributor returns semantic source ranges; the Shiki adapter supports a curated language corpus and aliases; the reader owns contrast, search composition, selection and exact-source fallback ([Code Highlighting](../04-presentation/12-code-highlighting.md), `lib/api/highlighting/shiki_code_highlighter.dart`). |
| Resizable side panels | Shelf and outline widths are independent, persisted preferences. Wide layouts provide pointer, keyboard and accessible seams; compact overlays reuse the preferences; both yield before the measured reading column. See [Panel Widths](../05-api/18-panel-widths.md). |
| Durable workspaces | Versioned `.visualmd-workspace.json` stores source order, theme, and active document; transactional restore retains unavailable sources; desktop writes are atomic; web uses retained handles or explicit upload/download fallback. See [Workspace Lifecycle](../02-application/09-workspace-lifecycle.md) and [0008](../08-decisions/0008-workspace-as-durable-unit.md). |

## Ordering

Roughly by how soon a reader hits the gap:

1. Recents — the first reactor and slot; it proves the shell can host plugin UI.
2. Everything else, as that first extension reveals a reusable shape.

## Out of scope for now

Editing. Visual MD is a reader. An editor is a second bounded context with
its own aggregate, and nothing in this backlog should quietly become one.
