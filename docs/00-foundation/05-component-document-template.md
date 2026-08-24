---
title: Component Document Template
---

# Component Document Template

Component documents use the same seven sections in the same order, giving a
reader a familiar route from purpose to likely evolution. When a section does
not apply, a short honest answer such as “None today” is more useful than a
speculative placeholder.

## Purpose and boundary

What the component owns, stated in the [ubiquitous language](02-ubiquitous-language.md).
What it explicitly does *not* own. Which ring it lives in
(see [Dependency Direction](03-dependency-direction.md)).

## Present wiring

How it is connected right now, with evidence. Reference the smallest source
file that owns the behavior, such as `lib/application/use_cases/add_folder.dart`.
Source references are checked mechanically by `test/docs/docs_library_test.dart`:
the file must exist, and exact line citations are rejected because unrelated
edits make them stale.

## Inputs and outputs

What comes in and what goes out, with types. Ports are named; adapters are
named; domain objects are named.

## Events

Events the component emits today. If there are none, say so. Mention a possible
event from the [Plugin Architecture](../07-roadmap/01-plugin-architecture.md)
only when it clarifies a documented extension point; roadmap ideas are not
current behaviour.

## Lifecycle

When it is created, who owns it, how long it lives, when it ends.

## Failure and recovery

What can go wrong, what the caller sees (exception type, null, empty
result), and what the reader sees on screen.

## Transition

The most likely next change, if one is known, and the boundary other components
already rely on. It is also fine to say that no transition is planned.

## Conventions

- One component per document; the document's H1 is the component name.
- Relative links between documents, with the `.md` suffix, GitHub-style anchors.
- Tables for contracts, code fences for shapes, prose for reasoning.
- Explain uncertainty directly: say what is unknown, why it is unknown, and
  what evidence would settle it.
