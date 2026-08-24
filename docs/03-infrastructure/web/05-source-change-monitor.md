# Browser Source Change Monitor

## Purpose and boundary

Browsers do not offer a production-grade, cross-browser filesystem observer.
`BrowserSourceChangeMonitor` therefore checks metadata on rereadable handles
every five seconds while the page is visible and when it regains focus
(`lib/infrastructure/web/browser_source_change_monitor.dart`,
`lib/infrastructure/web/browser_source_change_monitor.dart`). It emits invalidations; scanners still own content reads.

Immutable browser `File` snapshots are not presented as live sources. Their
watch streams remain empty because polling the same object would only reread
the same captured bytes (`lib/infrastructure/web/browser_source_change_monitor.dart`).

## Present wiring

Modern directory handles are fingerprinted by relative Markdown path,
`lastModified`, and size. Modified or added paths produce targeted
invalidations; removal requests a full rescan so a missing handle is not
confused with a read failure (`lib/infrastructure/web/browser_source_change_monitor.dart`).

Legacy dropped directory entries can sometimes be walked again, but not
reliably addressed one file at a time, so any changed fingerprint requests a
full rescan (`lib/infrastructure/web/browser_source_change_monitor.dart`).
Standalone modern file handles use the same metadata check and emit one
`MarkdownInvalidated` value (`lib/infrastructure/web/browser_source_change_monitor.dart`).

## Inputs and outputs

In: the opaque ref and its registered browser handle. Out: application
invalidations or `SourceWatchFailed`. No source text is carried in a fingerprint
or event.

The fingerprint walk skips hidden directories and non-Markdown files before
requesting metadata (`lib/infrastructure/web/browser_source_change_monitor.dart`).
The browser platform shares the same folder scanner instance for full and
targeted reads (`lib/infrastructure/platform/platform_web.dart`).

## Events

Timer ticks are private infrastructure details. Only a changed fingerprint or
a changed error state crosses the port. Repeated identical failures are
suppressed until a successful check resets the failure state
(`lib/infrastructure/web/browser_source_change_monitor.dart`).

## Lifecycle

The first listener establishes the baseline fingerprint, registers focus and
visibility listeners, and starts the timer. Cancellation removes all three.
Checks do not overlap, and no periodic work runs while the document is hidden
(`lib/infrastructure/web/browser_source_change_monitor.dart`).

## Failure and recovery

A denied or revoked handle emits a visible failure while preserving the last
good Library. The next timer, focus, or visibility check retries. A successful
check establishes the new baseline; a subsequent change resumes normal
invalidation.

Legacy `PickedFiles` and standalone `BrowserMarkdownFile` sources remain honest
snapshots: external edits require opening or dropping them again.

## Transition

A standardized browser observer can replace metadata polling behind the same
port when it is broadly shipped. Until then, the five-second check is limited to
sources the browser can genuinely reread.
