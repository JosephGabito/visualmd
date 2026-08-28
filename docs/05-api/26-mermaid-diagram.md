# Mermaid Diagram

## Purpose and boundary

Mermaid Diagram turns an authored `mermaid` fence into an inspectable vector
diagram without turning Visual MD into a browser. Its quiet state shows the
whole figure within a bounded part of the reading page. Its exploratory state
lets a reader drag to pan, zoom, reset to fit, copy the source, or open the
same figure full screen (`lib/api/widgets/mermaid_diagram.dart`).

Full screen ordinarily enters through a 180 ms fade. Reduce Motion removes
that automatic transition while leaving direct drag, wheel, pinch, zoom, and
fit actions unchanged (`lib/api/widgets/mermaid_diagram.dart`,
`test/presentation/mermaid_diagram_test.dart`).

The domain owns exact Mermaid source. The application ring defines a renderer
port and plain colour values. Infrastructure owns graph parsing, layout, SVG
generation and target adapters. The API ring owns Flutter painting and
interaction. Authored SVG, HTML, links and actions never enter the widget tree.

## Present wiring

`MarkdownDocumentParser` maps the fence to `MermaidBlock`. `DocumentView`
recognises that typed block, gives it the wide measure and constructs
`ReadableMermaidDiagram` with the active page palette
(`lib/infrastructure/markdown/markdown_document_parser.dart`,
`lib/api/render/document_view.dart`).

`MermaidRenderer` is the framework-free seam. On native targets,
`NativeMermaidRenderer` calls Merman through FFI in a worker isolate. On web,
`WebMermaidRenderer` calls the pinned, bundled Merman Web WASM package. Its
ignored vendor directory is reproduced from `web/package-lock.json` by
`bin/tools/prepare-web-assets.sh`, not stored as 13 MB of generated history. Both
return the same `MermaidRendering`: inert SVG plus optional authored accessible
title and description (`lib/application/ports/mermaid_renderer.dart`,
`lib/infrastructure/mermaid/mermaid_renderer_native.dart`,
`lib/infrastructure/mermaid/mermaid_renderer_web.dart`).

Merman's safe pipeline replaces browser-only labels with SVG text and closes
external resources. Its output still uses a stylesheet for presentation.
`inlineSvgStyles` resolves that cascade into attributes once, removes the
stylesheet, and hands `flutter_svg` one self-contained application artifact
(`lib/infrastructure/mermaid/svg_style_inliner.dart`). Visual MD does not call
the rewritten result Merman's sealed resvg-safe artifact; the normalization is
an explicit host-owned step.

The in-document viewport fits the complete viewBox and stays between eight and
eighteen body beats. `InteractiveViewer` owns drag, wheel or pinch zoom, and a
transformation controller shared by toolbar and keyboard actions. Reset
recomputes fit from the current viewport. Full screen creates a fresh explorer
over the page, preserving the quiet state beneath it. Escape and Command-Period
close that explorer and return keyboard focus to the full-screen action that
opened it
(`lib/api/widgets/mermaid_diagram.dart`).

The explorer header uses [Library Chrome](28-library-chrome.md)'s elevated
surface and component-label role. Its local actions therefore match code-block
furniture without borrowing the document's heading hierarchy
(`lib/api/widgets/mermaid_diagram.dart`).

## Inputs and outputs

| In | Type | Meaning |
|----|------|---------|
| `source` | `String` | Exact Mermaid fence body |
| `palette` | `MermaidPalette` | Page, surface, ink, line and accent colours |
| `beat` | `double` | Reading grid used to bound the inline viewport |
| renderer | `MermaidRenderer` | Target adapter that returns inert vector data |

The output is a semantic image surface with local interaction. It does not
change the document, workspace, library or source file.

## Events

None. Copying writes to the operating-system clipboard. Opening full screen,
dragging, zooming and fitting are transient widget state, not application
events.

## Lifecycle

The composition root creates one renderer for the application. Each adapter
caches completed work by exact source and palette in one least-recently-used,
byte-bounded store, so page rebuilds, panel resizes and exploration never rerun
graph layout without letting generated diagrams accumulate for the lifetime of
the process. Concurrent requests for the same rendering share one active job;
failures and results too large for the budget are not retained
(`lib/infrastructure/mermaid/mermaid_render_cache.dart`). A diagram explorer
owns one transformation controller and brief copy feedback; full screen owns
another. Both are disposed with their surfaces (`lib/main.dart`,
`lib/api/widgets/mermaid_diagram.dart`).

The web bridge initializes its bundled WASM engine only when a document first
asks for a Mermaid rendering. Opening an ordinary Markdown library therefore
does not pay the diagram engine's startup cost (`web/mermaid_bridge.js`).

## Failure and recovery

Invalid Mermaid, renderer failure or SVG without valid positive viewBox
geometry becomes a quiet source surface. The exact fence body remains readable
and copyable; enhancement failure cannot hide authored material. Loading has a
bounded progress state rather than changing page geometry after completion
(`lib/api/widgets/mermaid_diagram.dart`).

The safe renderer profile denies external resources and Flutter paints the SVG
as data rather than mounting it in a DOM. Authored `click` actions therefore
cannot navigate or execute. Accessibility directives become the semantic image
name and description; when no title is authored, the surface uses the honest
generic name “Mermaid diagram.”

Parsing is covered by `test/infrastructure/markdown_document_parser_test.dart`.
CSS normalization is covered by
`test/infrastructure/mermaid_svg_style_inliner_test.dart`. Fit, drag, zoom,
reset, full screen, copy, caching, accessibility and exact-source failure are
covered by `test/presentation/mermaid_diagram_test.dart`. Cache byte limits,
least-recent eviction, active-work deduplication, oversized results and retry
after failure are covered by
`test/infrastructure/mermaid_render_cache_test.dart`.

## Transition

The renderer versions are pinned because native Merman and its Web WASM
binding do not yet share one stable packaging line. When Merman publishes its
Native Assets Flutter release, the temporary macOS CocoaPods choice can be
removed. Until then, `bin/tools/repair-merman-macos.sh` replaces the package's
CI-local dylib install names with an application-relative identity after
embedding, and `bin/tools/validate-macos-bundle.sh` guards portability and code
signing. Diagram export is not part of this component today; adding it would
require a separate file-writing action and explicit raster or SVG contract.
