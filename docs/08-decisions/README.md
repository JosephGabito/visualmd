# Decisions

This shelf explains the important choices behind Visual MD. Each architecture
decision record, or ADR, gives a future contributor the context that source
code alone cannot: what problem we faced, what we chose, and which trade-offs
we accepted.

An accepted record is a historical snapshot, not a claim that the choice can
never change. When experience points somewhere better, a new record supersedes
the old one and both remain available. That makes the project's reasoning easy
to follow without rewriting its history.

| Decision | Status | Date |
|----------|--------|------|
| [0001 — Hexagonal Layering](0001-hexagonal-layering.md) | Accepted | 2026-08-22 |
| [0002 — Flutter Web First, Then Desktop](0002-flutter-web-first-then-desktop.md) | Accepted | 2026-08-22 |
| [0003 — Domain Owns Parsing and Shelving](0003-domain-owns-parsing-and-shelving.md) | Accepted | 2026-08-22 |
| [0004 — Sections as the Navigation Unit](0004-sections-as-navigation-unit.md) | Accepted | 2026-08-22 |
| [0005 — FolderRef as an Opaque Handle](0005-folder-ref-as-opaque-handle.md) | Accepted | 2026-08-22 |
| [0006 — Platform Adapters by Conditional Import](0006-platform-adapters-by-conditional-import.md) | Accepted | 2026-08-22 |
| [0007 — Plugins as Typed Hooks](0007-plugins-as-typed-hooks.md) | Accepted (direction, not yet implemented) | 2026-08-22 |
| [0008 — Workspace as the Durable Unit](0008-workspace-as-durable-unit.md) | Accepted | 2026-08-24 |

## What you will find in a record

- **Context** — the situation and the forces at play.
- **Decision** — what was chosen and the boundary it creates.
- **Consequences** — what becomes easier, what becomes harder, and what to
  watch as the project changes.
- **Evidence** — stable source-file references showing where the decision is
  visible in current code or tests.

## Adding a decision

Use the next number, keep the same four sections, and add the record to this
index. If it changes an earlier decision, link the two records so a reader can
see the transition. [Writing Docs](../09-contributing/04-writing-docs.md)
explains the source-reference and link conventions used throughout this library.
