# 0008 — Workspace as the Durable Unit

Status: Accepted · 2026-08-24

## Context

A session can contain several folder roots and standalone Markdown files. The
reader also expects their order, active document, and theme to survive. Merely
remembering the last folder cannot represent that product, and serializing a
Library would copy document contents and parsed state that already belong to
the filesystem and domain projection.

The same document must be openable on macOS, Windows, and web. Those platforms
do not share an authority model: desktop has paths, macOS sandbox access needs
bookmarks, and browsers use permission-bearing handles that cannot safely be
placed in JSON.

## Decision

The Workspace aggregate is the durable unit. Its public JSON stores stable
identity, one optional absolute document root, ordered relative source
addresses, theme choice, and active document address. It stores no Markdown
content and no platform authority.

Platform authority is local and keyed by Workspace ID plus source ID. Opening
is transactional: decode and restore into temporary state, retain expected
unavailable sources, normalize standalone absorption, then replace the Library
and WorkspaceSession together. Save As creates a new Workspace ID and forks
local bindings.

Desktop writes replace a temporary file atomically and retain a last-good
backup. Browsers use writable handles where available; upload/download fallback
requires explicit Save and never generates automatic downloads.

This decision supersedes the “remember last folder as a reactor” persistence
direction in [0007 — Plugins as Typed Hooks](0007-plugins-as-typed-hooks.md).
Persistence is part of the kernel because it defines the durable aggregate and
its recovery contract, not a reaction to a Library event.

## Consequences

- A Workspace can describe several roots without copying their contents.
- Relative source paths can move together beneath a corrected absolute root.
- Shared JSON remains inspectable and contains no bookmarks or browser handles.
- Missing access is recoverable and retains source order.
- Format evolution is a public contract requiring versions and migrations.
- A copied workspace may require the receiving machine to reconnect sources.
- Windows behavior can be implemented in source and portable tests, but native
  replacement remains unverified until built on Windows.

## Evidence

- Domain membership and invariants: `lib/domain/workspace/workspace.dart:5-41`.
- Safe portable paths: `lib/domain/workspace/workspace_source.dart:41-58`.
- Strict versioned codec: `lib/infrastructure/workspace/workspace_json_codec.dart:13-84`.
- Transactional restoration and absorption: `lib/application/use_cases/open_workspace.dart:72-173`.
- Serialized deferred writes: `lib/application/workspace_autosave.dart:31-67`.
- Public schema: `schemas/visualmd-workspace-v1.schema.json`.
