# Browser Markdown Drop

## Purpose and boundary

The browser drop family recognizes one directly offered Markdown file and feeds
the `MarkdownScanner` port. Modern browsers can provide a permission-bearing
file handle; the legacy path provides a `File` with no exposed local path.

## Present wiring

Inside the DOM drop callback, `BrowserFolderDrop` first asks a single item for
`getAsFileSystemHandle`. A Markdown handle becomes `BrowserMarkdownHandle`; if
that API is unavailable or rejected, the captured legacy `File` becomes
`BrowserMarkdownFile`. Other accepted shapes continue through folder conversion
(`lib/infrastructure/web/browser_folder_drop.dart:57-145`).

`BrowserMarkdownRegistry` retains either representation for the session. The
scanner turns a modern handle into a `File`, reads `File.text()`, and asks
`BrowserSourceIdentity` to compare handles with `isSameEntry`
(`lib/infrastructure/web/browser_markdown_scanner.dart:7-30`,
`lib/infrastructure/web/browser_source_identity.dart:7-19`). A legacy `File`
has `sourceId: null`; filename, size, and modification time are not used as a
substitute because unrelated files can share all three.

## Inputs and outputs

| Input | Output |
|-------|--------|
| one dropped browser markdown | `MarkdownRef`, then `ScannedMarkdown` |
| directory or multiple files | existing folder-drop path |
| unknown markdown ref | `MarkdownUnavailable` |

## Events

None. DOM events are translated into port inputs; application events remain
downstream of a committed use case.

## Lifecycle

The web platform constructs one folder registry, Markdown registry, drop
adapter and scanner when the page starts
(`lib/infrastructure/platform/platform_web.dart:25-43`). The DOM listeners and
registries last until the page is unloaded.

## Failure and recovery

With modern handles, `isSameEntry` can identify a direct file already present
inside a handle-backed browser folder. The application then adapts the
standalone document into that folder. A legacy upload still cannot prove
physical identity, so it remains in Markdowns rather than risking a false match.

Read failures propagate before mutation. Unsupported single files are ignored
by markdown classification and follow the existing loose-file behavior.

## Transition

Modern handles provide stable identity within the page session and can be kept
in IndexedDB for workspace restoration. The legacy fallback remains deliberately
path-free; any broader identity scheme would need evidence stronger than file
metadata before it could safely merge documents.
