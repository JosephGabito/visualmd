# Error Notice

## Purpose and boundary

`ErrorNotice` keeps a failed source-open visible when the reader already has a
library. It presents a message and dismissal intent; it does not decide which
failures become messages or retain error history
(`lib/api/widgets/error_notice.dart`).

## Present wiring

The component is a bounded panel using only theme tokens. A uniform quiet
border defines its edge, while a clipped two-pixel accent rule marks the
failure without a shadow or a second surface. The message uses the interface
face and the close control remains compact
(`lib/api/widgets/error_notice.dart`).

The shell mounts the notice above an occupied reading shell whenever
`controller.error` is present. The welcome screen retains its inline treatment
when no library exists. Dismissal calls `ReaderController.clearError`
(`lib/api/screens/reader_screen.dart`).

## Inputs and outputs

| Input | Output |
|-------|--------|
| non-empty failure message | visible text in a 520 px maximum-width notice |
| dismiss control | `onDismiss()` |
| active theme | panel, border, accent, ink and muted tokens |

## Events

None. Dismissal is interface intent; the controller owns the transient error
state and a later successful source open clears it independently.

## Lifecycle

The shell constructs the notice only while both a library and an error exist.
It persists until dismissal or another source-open attempt changes controller
state. It does not run a timer, so a reader cannot miss a short-lived failure.

## Failure and recovery

The notice is a semantic live region, so newly mounted feedback is announced.
Its close control has a tooltip and remains reachable without a pointer
(`lib/api/widgets/error_notice.dart`, `lib/api/widgets/error_notice.dart`). A widget test proves the
open document and shelf survive a failed drop and that dismissal clears only
the error (`test/presentation/reader_chrome_test.dart`).

## Transition

More detailed diagnostics may later add an optional action, but the component
should remain one message and one recovery gesture. Queues, histories and
automatic expiry would need their own state and interaction design rather than
being hidden inside this notice.
