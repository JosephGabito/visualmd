# API

This is where Visual MD becomes an application you can see and use. The API
ring contains the Flutter shell, its controller, and the renderer that turns a
parsed document into a quiet reading page.

Widgets call application use cases and present domain objects. Platform work
arrives through small values and callbacks supplied by the composition root,
which lets the same reader UI run on desktop and the web
(`lib/main.dart:67-74`).

| Document | What it covers |
|----------|----------------|
| [Reader Controller](01-reader-controller.md) | UI state, use-case calls, link resolution |
| [Shell](02-shell.md) | `VisualMdApp`, `ReaderScreen`, top bar, welcome and drop overlay |
| [Shelf Panel](03-shelf-panel.md) | The folder tree on the left |
| [Reading Pane](04-reading-pane.md) | The page: scrolling, anchors, active heading |
| [Outline Panel](05-outline-panel.md) | The outline on the right |
| [Theme Binding](06-theme.md) | Carrying a theme into the widget tree |
| [Theme Picker](07-theme-picker.md) | The top-bar control that changes what the reader wears |
| [Anchored Menu](08-anchored-menu.md) | The menu that opens from its trigger, and the motion it uses |
| [Pressable](09-pressable.md) | The press behaviour every control in the chrome shares |
| [Collapsible Panel](10-collapsible-panel.md) | How a side panel slides out of the way instead of vanishing |
| [Code Block](11-code-block.md) | Why fenced code scrolls sideways instead of being clipped |
| [Document View](12-document-view.md) | The renderer: per-block widths and the vertical rhythm |
| [Inline Composer](13-inline-composer.md) | Runs into spans, with the punctuation set on the way past |
| [Reading Theme](14-reading-theme.md) | Every style and gap the page is set with, derived once |
| [Paragraph](15-paragraph.md) | One paragraph, indented, with its opening mark hung and its widow bound |
| [Font Metrics](16-font-metrics.md) | What the faces measure, and the size and leading derived from it |
| [Search](17-search.md) | Current-document and whole-library find, result navigation, and highlighting |
| [Panel Widths](18-panel-widths.md) | Remembered shelf and outline geometry, fitted around the reading measure |
| [Panel Resize Handle](19-panel-resize-handle.md) | Pointer, keyboard, reset, and accessibility behavior for resizing |
| [Error Notice](20-error-notice.md) | Persistent, dismissible feedback when a drop fails over an open library |
| [Workspace Actions](21-workspace-actions.md) | Native File commands, shortcuts, controller transitions, and errors |
| [Brand Mark](22-brand-mark.md) | Bundled product artwork and its Flutter, macOS, Windows, and web surfaces |

## How it connects

The API ring brings together three inward-facing parts of the application:

- `application/`: use cases and `DocumentReading`
  (`lib/api/reader_controller.dart:4-6`,
  `lib/api/widgets/reading_pane.dart:3`).
- `domain/`: the library, folder, document, outline, and content objects that
  widgets present (`lib/api/widgets/shelf_panel.dart:3-6`,
  `lib/api/widgets/outline_panel.dart:3-4`).
- `presentation/`: the theme contract, which widgets render without redefining
  (`lib/api/theme/library_theme.dart:4-6`,
  `lib/api/reader_controller.dart:9-11`).

Flutter and `google_fonts` provide the rendering tools
(`lib/api/theme/library_theme.dart:1-2`). Markdown is not handed to a generic
widget: `lib/api/render/` renders the domain's content model directly
(`lib/api/render/document_view.dart:1-7`).

Platform-specific work stays at the edge. Folder picking, dropped files, and
window dragging are injected as functions or plain values
(`lib/api/app.dart:9-33`, `lib/api/reader_controller.dart:34-38`). The top bar
also receives its platform geometry instead of branching on an operating
system (`lib/api/screens/reader_screen.dart:21`,
`lib/api/screens/reader_screen.dart:303-312`). This keeps the widgets focused
on interaction and presentation.

## A useful reading path

For an architectural tour, start with the
[Reader Controller](01-reader-controller.md), continue to the
[Shell](02-shell.md), then visit the shelf, page, and outline in the order a
reader meets them.

[Theme Binding](06-theme.md) is useful reference material for bundled fonts,
optical size, and the Markdown style sheet. [Theme Picker](07-theme-picker.md)
shows how a reader changes it through [Anchored Menu](08-anchored-menu.md).

[Document View](12-document-view.md),
[Inline Composer](13-inline-composer.md), and
[Reading Theme](14-reading-theme.md) form the renderer. Read them in that order
to see what goes where, how text is shaped, and where the measurements come
from. [Code Block](11-code-block.md) explains why fenced code is allowed a
wider measure than prose. [Pressable](09-pressable.md) and
[Collapsible Panel](10-collapsible-panel.md) are the small interaction pieces
used throughout the shell. [Panel Widths](18-panel-widths.md) and
[Panel Resize Handle](19-panel-resize-handle.md) show how that shell adapts
while protecting the page's reading measure.

Component documents follow the
[Component Document Template](../00-foundation/05-component-document-template.md).
Related rings: [Presentation](../04-presentation/README.md) provides the visual
language, [Application](../02-application/README.md) provides use cases,
[Infrastructure](../03-infrastructure/README.md) supplies platform services,
and [Platforms](../06-platforms/README.md) explains where the app runs.
