# Search

## Purpose and boundary

Search has two familiar scopes: Command/Ctrl-F finds within the open document;
Command/Ctrl-Shift-F finds across the library. `ReaderScreen` owns the query,
scope, active occurrence and request lifecycle
(`lib/api/screens/reader_screen.dart`). `DocumentFindBar` and
`LibrarySearchPanel` draw those states
(`lib/api/widgets/search_view.dart`, `lib/api/widgets/search_view.dart`). They never match text.

## Present wiring

Opening search focuses and selects the shared query field, preserving a query
when scope changes (`lib/api/screens/reader_screen.dart`). Input is
debounced for 120 ms; a request number prevents an older asynchronous result
from replacing a newer query (`lib/api/screens/reader_screen.dart`). The controller delegates to
`SearchDocuments` without storing search state
(`lib/api/reader_controller.dart`).

Current-document results appear in a quiet bar over the page with an active
count and previous, next and close controls
(`lib/api/widgets/search_view.dart`). Enter and Shift-Enter navigate;
Escape closes (`lib/api/widgets/search_view.dart`). The page highlights every match and gives the
active one a stronger ground while preserving typography
(`lib/api/render/inline_composer.dart`).

Library search temporarily replaces the shelf. Results follow arranged root
order and are grouped first by top-level folder, then by document, with title,
path and excerpt; the list is built lazily
(`lib/api/widgets/search_view.dart`). Selecting an occurrence opens
its document, returns to document scope, and keeps that exact occurrence
active (`lib/api/screens/reader_screen.dart`).

## Inputs and outputs

In: shortcut or field input, followed by grouped domain results. Out: calls to
`ReaderController.search`, `openDocument`, and match ranges passed through
`ReadingPane` to `DocumentView`.

`DocumentView` tracks the plain-text offset of each block and registers the
render context for its matches (`lib/api/render/document_view.dart`,
`lib/api/render/document_view.dart`,
`lib/api/render/document_view.dart`). `ReadingPane` uses those contexts to bring the active occurrence
into view (`lib/api/widgets/reading_pane.dart`, `lib/api/widgets/reading_pane.dart`).

## Events

None. Queries and active occurrences are transient interface state. Selecting
a library result follows the ordinary document-opening path.

## Lifecycle

The screen owns one text controller, focus node and debounce timer, disposing
all three with its state (`lib/api/screens/reader_screen.dart`). Closing
search invalidates pending requests and removes every highlight (`lib/api/screens/reader_screen.dart`).
When source synchronization increments `contentRevision`, an open non-empty
search reruns against the committed Library, using the same request-number guard
as typed queries (`lib/api/screens/reader_screen.dart`).

## Failure and recovery

An empty query clears results without calling the application. No occurrence
shows `0 of 0`; no library results shows “No matches.” Navigation wraps rather
than stopping at either end (`lib/api/screens/reader_screen.dart`).
Search cannot open before a library, and document scope cannot open without a
reading (`lib/api/screens/reader_screen.dart`).

Widget tests exercise both shortcuts, result counts and the handoff from a
library result to an open highlighted document
(`test/presentation/reader_chrome_test.dart`).

## Transition

Whole-word and case-sensitive options belong in `SearchQuery` before controls
are added. Search syntax, fuzzy ranking and a permanent index are deliberately
absent: literal find is predictable, portable, and sufficient until measured
usage argues otherwise.
