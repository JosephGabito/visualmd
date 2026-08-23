# Visual MD schemas

This folder contains the public formats Visual MD can read and write.
`visualmd-workspace-v1.schema.json` describes files ending in
`.visualmd-workspace.json`, so another tool can inspect or validate a workspace
without depending on the Dart implementation.

## What a workspace records

A workspace carries the reading state someone expects to reopen: its sources
and their order, the chosen theme, and the active document. Source paths are
relative to `documentRootAbsolutePath` when a shared root is available. The
format and version fields make future migrations explicit.

## What stays on the device

Access credentials are not part of the portable document. macOS
security-scoped bookmarks, browser file handles, permission tokens, and other
machine authority remain in local application storage, keyed by `workspaceId`
and source `id`. Sharing a workspace therefore shares its intent and paths,
not permission to another person's files.

## Evolving the format

The Dart codec and JSON Schema both reject unknown shapes so format changes are
noticed instead of silently ignored. A new field should update the schema and
codec together, define how older files migrate, and include round-trip tests.
That keeps saved workspaces predictable across Visual MD versions.
