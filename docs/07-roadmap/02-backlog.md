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
| Relative images | Kernel fix | application, infrastructure, api | `![](./diagram.png)` shows its alt text today (`lib/api/render/inline_composer.dart:95-103`): scanners read only markdown, so there are no bytes to draw. The scanner port grows an image lookup, each scanner supplies it, and the composer resolves relative paths against the document's folder. |
| Syntax highlighting | Contributor | api | A fence-language contributor that returns highlighted spans for known languages and falls back to the plain scrolling block (`lib/api/render/document_view.dart:238-258`). Syntax colours belong to that contributor rather than the current theme contract, whose palette has no code-token colours (`lib/presentation/theme/theme_palette.dart:11-37`). |
| Let code blocks run wider still | Kernel fix | api | Done in part: code and tables already get 1.35 × the prose column (`lib/api/render/reading_theme.dart:214-224`). The factor is a judgement, not a measurement, and on a large screen there is room to go further. |
| Bring tables onto the beat | Kernel fix | api | Table columns now size from their widest bounded cell and overflow locally; their **height** remains content-driven and is not rounded (`lib/api/render/document_view.dart:390-516`). The running text does not resume in phase after one. Snapping row heights, or the block as a whole, is the remaining gap in [Vertical Rhythm](../04-presentation/11-vertical-rhythm.md). |
| Read font metrics rather than transcribe them | Kernel fix | api | The x-heights, cap heights and descenders are hand-copied from each font's `OS/2` table (`lib/api/theme/font_metrics.dart:11-36`). A face added to `pubspec.yaml` without an entry is silently un-normalised. Reading the table at startup removes the failure mode, at the cost of parsing font binaries. |
| Primes rather than quotes | Kernel fix | presentation | `5'2"` is set with typographic quotes today (`lib/presentation/theme/typographic_punctuation.dart`); a typographer would want hatch marks. Needs a rule that looks at what precedes the mark. |
| Reader control of the measure | Kernel fix | presentation, api | Body size is a reader setting; the measure is still fixed (`lib/presentation/theme/reading_scale.dart:15-18`). It is already a parameter, so this is wiring rather than redesign. Leading is no longer a candidate: it is derived from the face's own metrics. |
| Mermaid | Contributor | api | A fence-language contributor keyed on `mermaid`, rendering a diagram widget. Same scope as syntax highlighting and images, and same distance from themes. |
| Recents in the shelf | Reactor + slot | infrastructure, api | Subscribe to `DocumentOpened`; render the list in the shelf-panel slot. |
| Windows custom chrome | Slot | infrastructure, api | Hide the Windows title bar as macOS does, then paint minimise / maximise / close — a later top-bar slot contributor. |
| Reload themes without a restart | Kernel fix | infrastructure, api | Theme files are read once at startup (`lib/main.dart:33`). Watching the folder, or a Reload item in the theme menu, would make authoring a theme a live loop. |
| macOS signing and notarization | Packaging | none | Needs an Apple Developer account. Adds a signing identity to the Xcode project and a notarization step after `flutter build macos`. |
| Chrome extension | Platform | infrastructure | A fourth adapter family. Build with `--csp --no-web-resources-cdn`, strip the `<base href>` from `web/index.html`, bundle fonts, and request the file URL permission so local markdown opens in the reader. |
| Windows build verification | Platform | none | The target is scaffolded and named (`windows/runner/main.cpp:30`) but has never been compiled; needs a Windows machine with the Visual Studio Desktop C++ workload. |

## Done

| Item | Landed as |
|------|-----------|
| Reveal the themes folder | The theme menu presents one **Open themes folder** action instead of exposing the sandbox path. Desktop delegates the directory to the operating system; web omits the unavailable action (`lib/api/widgets/theme_picker.dart:116-131`, `lib/infrastructure/platform/platform_io.dart:138-144`). |
| Structured themes | A `ReaderTheme` contract, six built-ins, a registry that loads user JSON files, a picker, and a persisted choice. The seams live in the `presentation` ring (`lib/presentation/theme/reader_theme.dart:10-29`), which may import no package, so the `api` ring binds them to Flutter and a theme stays data. See [Presentation](../04-presentation/README.md) and [Creating a Theme](../09-contributing/05-creating-a-theme.md). |
| Bundle fonts as assets | Alegreya, Literata, Inter and JetBrains Mono ship inside the app as variable fonts with their OFL notices (`pubspec.yaml:28-57`), registered for the licence page (`lib/api/theme/font_licences.dart:13-24`). `GoogleFonts` is now only a fallback for a family a theme names that we do not ship (`lib/api/theme/library_theme.dart:127-152`). Text draws with no network and no flash of a fallback face — and the metrics became measurable, which is what everything after it was built on. |
| A reading face chosen for the medium | The page is set in Alegreya, drawn for literature and long-form text (`lib/presentation/theme/theme_typefaces.dart:12-19`); Literata stays bundled and selectable. The supporting research is recorded in [Sources](../04-presentation/10-sources.md), alongside the larger effects of measure, leading, and rhythm. |
| Sizes and leading derived from the face | A size is a size of *letters*: the font size that delivers it is worked out per face from its x-height, and the line height from its cap height, descender and x-height ([Font Metrics](../05-api/16-font-metrics.md), `lib/api/theme/font_metrics.dart:46-70`). Measuring caught body text rendering about 7 % smaller than the sans beside it. |
| Vertical rhythm on a real grid | Every gap is a whole number of body lines, heading boxes round up to one, and code sits a beat a line — with a strut holding line boxes so an inline code span cannot push a line off the beat ([Vertical Rhythm](../04-presentation/11-vertical-rhythm.md)). The invariant is a test, and it caught three separate sources of drift, including the beat being measured in a unit the page never used. |
| Tone under size and weight | `h1` darkest through to `h5` and `h6` receding, written as a distance towards ink or away from it so it does not invert on a dark page (`lib/api/render/reading_theme.dart:80-98`). The body is never dimmed. |
| Hanging punctuation and first-line indents | Both are done, and neither needed the text-engine feature they seemed to. The indent goes into the flow as a `WidgetSpan`, so it moves the first line and nothing else; the opening mark is taken out of the flow and painted at `indent - hang` in a `Stack`, so the words start on the column edge (`lib/api/render/document_view.dart:448-507`). Which marks hang and how far is a table in the presentation ring ([Hanging Punctuation](../04-presentation/08-hanging-punctuation.md)); when a paragraph indents is a rule in the renderer ([Document View](../05-api/12-document-view.md)). **What remains:** only a paragraph's *opening* mark hangs. A line further down that happens to begin with a quotation mark stays in the column, because hanging those needs per-line control Flutter does not expose. |
| Widows | The last two words of a paragraph are bound with a non-breaking space so neither is left standing alone ([Widow Binding](../04-presentation/09-widow-binding.md)). The remedy is applied whenever a paragraph is long enough rather than only when the last line would hold one word, which needs the laid-out line. |
| Measured typography | A [Reading Scale](../04-presentation/07-reading-scale.md) in the presentation ring: the column set to 66 characters of the face actually in use rather than a fixed 760 px, no heading smaller than body, and a reader-chosen body size. The optical-size axis is driven from the rendered size (`lib/api/theme/library_theme.dart:133-144`). |
| Scaler-aware geometry | Accessibility text scaling now participates in the measured column, baseline grid, heading line boxes, indentation and hanging punctuation (`lib/api/render/reading_theme.dart:58-81`, `lib/api/render/reading_theme.dart:214-275`). The page no longer draws enlarged text inside geometry calculated for its unscaled size. |
| Compact reading shell | Below 1180 px the document keeps the full content width and the shelf or outline opens as a single overlay, never both (`lib/api/screens/reader_screen.dart:73-90`, `lib/api/screens/reader_screen.dart:234-255`). |
| Built-in contrast guard | Shipped ink, muted and accent text pairs are tested at WCAG's 4.5:1 threshold on their real paper and panel surfaces (`lib/presentation/theme/theme_palette.dart:8-9`, `test/presentation/theme_test.dart:76-103`). |
| In-app search | Current-document find highlights and navigates rendered text; whole-library find groups literal results in the shelf and opens the chosen occurrence. The application owns the scope through a port, while the Dart adapter remains replaceable by an index later. See [Search](../05-api/17-search.md). |
| Resizable side panels | Shelf and outline widths are independent, persisted preferences. Wide layouts provide pointer, keyboard and accessible seams; compact overlays reuse the preferences; both yield before the measured reading column. See [Panel Widths](../05-api/18-panel-widths.md). |
| Durable workspaces | Versioned `.visualmd-workspace.json` stores source order, theme, and active document; transactional restore retains unavailable sources; desktop writes are atomic; web uses retained handles or explicit upload/download fallback. See [Workspace Lifecycle](../02-application/09-workspace-lifecycle.md) and [0008](../08-decisions/0008-workspace-as-durable-unit.md). |

## Ordering

Roughly by how soon a reader hits the gap:

1. Relative images — the first thing a real docs folder exposes.
2. Syntax highlighting — the first contributor; it proves extension points.
3. Recents — the first reactor and slot; it proves the shell can host plugin UI.
4. Everything else, as those first extensions reveal a reusable shape.

## Out of scope for now

Editing. Visual MD is a reader. An editor is a second bounded context with
its own aggregate, and nothing in this backlog should quietly become one.
