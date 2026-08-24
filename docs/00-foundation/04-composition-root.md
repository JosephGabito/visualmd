# Composition Root

## Purpose and boundary

`lib/main.dart` is the only file that sees every ring. It chooses adapters,
constructs application use cases, hands them to the controller, and starts
Flutter. It contains wiring, never filesystem or domain policy.

## Present wiring

After Flutter initialization, the root creates platform adapters and one shared
in-memory reader state. Library and Workspace repositories plus the atomic
restoration adapter all project through that state
(`lib/main.dart:42-60`). It then creates one mutation queue, workspace
autosave, the workspace committer, and every Library use case
(`lib/main.dart:62-121`).

Theme documents and small preferences are read through platform capabilities
before the initial unbound Workspace is created
(`lib/main.dart:112-143`). New, Open, Save, Save As, and reconnect use cases
share the same session repository, source access, codec, and mutation queue
(`lib/main.dart:135-173`).

The source coordinator connects the platform monitor to `RefreshSource`, then
the controller receives that coordinator with its other use cases. It never
sees an infrastructure implementation (`lib/main.dart:185-218`). Platform drop,
drag, native command, and autosave-failure streams are subscribed at the edge
(`lib/main.dart:201-220`).

## Inputs and outputs

| Direction | Value |
|-----------|-------|
| In | compile target selecting web or desktop adapters |
| In | persisted preferences and theme documents |
| In | folder, Markdown, drag, and native command streams |
| Out | one configured `VisualMdApp` |

Launch query options are a web-only input used for samples and visual review;
they do not become durable Workspace state (`lib/main.dart:222-245`).

## Events

There is no domain event bus. Platform streams, committed source refreshes, and
autosave failures are edge signals forwarded directly to the controller.

## Lifecycle

The root runs once. All repositories, queues, use cases, adapters, and stream
subscriptions live for the process. Platform initialization completes before
the first Workspace and before `runApp`.

## Failure and recovery

Unsupported targets fail during platform creation. Theme document failures are
reported and skipped independently. Workspace command failures are handled by
the controller, while background autosave failures enter the same visible error
surface through their stream.

## Transition

New capabilities connect here through typed ports, adapters, or command
streams. Keeping that small piece of composition in `main.dart` lets API
widgets and application use cases continue to describe what they need without
depending on a concrete platform implementation.
