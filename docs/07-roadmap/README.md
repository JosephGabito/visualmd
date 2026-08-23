# Roadmap

This shelf records where Visual MD may go next. It is a working direction, not
a release promise: the backlog can change as real readers expose better
priorities.

The product has a small centre — open a folder, shelve its Markdown, and read
with an outline. We want that experience to become dependable before building
a general extension system around it. When extensions do arrive, they should
attach through small, typed hooks shaped by features we have actually built.

## Documents

| Document | What it covers |
|----------|----------------|
| [Plugin Architecture](01-plugin-architecture.md) | The proposed plugin shapes and where their hooks could attach to today's code. |
| [Backlog](02-backlog.md) | Known work, including completed items and the rings each change touches. |

## A useful reading path

1. Start with [Plugin Architecture](01-plugin-architecture.md) for the proposed
   vocabulary: reactors, contributors, and slots.
2. Continue to the [Backlog](02-backlog.md) for concrete product gaps and work
   that has already landed.
3. Read [ADR 0007](../08-decisions/0007-plugins-as-typed-hooks.md) for the
   reasoning behind this direction.

## How work moves forward

1. A candidate is described in the [Backlog](02-backlog.md), including the
   reader need and the rings it is likely to touch.
2. A change to `domain/` starts with the reader-facing rule and a test in
   [Invariants](../01-domain/04-invariants.md), so the UI has a clear behavior
   to present.
3. An extension begins with the smallest hook its first real use needs. A
   reusable framework can wait until several uses reveal its shape.
4. The [Testing and Validation](../09-contributing/02-testing-and-validation.md)
   guide and the relevant component docs close the loop.

## Current status

The plugin system described here is not implemented. Some items in the backlog
have already landed and are recorded there separately. The reader it would
extend is described in [Domain](../01-domain/README.md),
[Application](../02-application/README.md),
[Infrastructure](../03-infrastructure/README.md), and
[API](../05-api/README.md).

The first real extensions will teach us more than a speculative framework can;
that restraint is captured by the
[rule of three](01-plugin-architecture.md#rule-of-three).
