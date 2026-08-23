# Visual MD Architecture

Welcome to the engineering guide for Visual MD. These documents explain the
reader as it exists today: what each part is responsible for, how a document
travels from disk to page, and why the visible details are built the way they
are.

You do not need to read the guide from beginning to end. Pick the path that
matches the change you want to understand, and let each shelf lead to the next.
The folder is also a real Visual MD library, so opening `docs/` in the app is a
pleasant way to explore it.

## A short guided tour

New to the project? Read [Purpose and Status](00-foundation/01-purpose-and-status.md)
first, followed by [Dependency Direction](00-foundation/03-dependency-direction.md).
Together they explain the product boundary and the small set of code boundaries
that keep platform details from becoming product rules.

From there:

- To follow a Markdown file from source to screen, visit [Domain](01-domain/README.md),
  [Application](02-application/README.md), [Infrastructure](03-infrastructure/README.md),
  and [API](05-api/README.md).
- To understand the reading experience, start with [Presentation](04-presentation/README.md)
  and continue into the renderer documents under API.
- To run or extend a target, use [Platforms](06-platforms/README.md).
- To understand future direction and past choices, browse [Roadmap](07-roadmap/README.md)
  and [Decisions](08-decisions/README.md).
- To make a change, begin with [Contributing](09-contributing/README.md).

## Every shelf

| Shelf | What you will find there |
|-------|--------------------------|
| [Foundation](00-foundation/README.md) | Product purpose, shared vocabulary, dependency direction, and the composition root |
| [Domain](01-domain/README.md) | Documents, libraries, shelving, outlines, and workspace rules |
| [Application](02-application/README.md) | The actions Visual MD performs and the ports those actions use |
| [Infrastructure](03-infrastructure/README.md) | Markdown, storage, search, web, and desktop adapters |
| [Presentation](04-presentation/README.md) | Framework-free theme and typography contracts |
| [API](05-api/README.md) | The Flutter shell, panes, controller, and document renderer |
| [Platforms](06-platforms/README.md) | Current support and build notes for web, macOS, and Windows |
| [Roadmap](07-roadmap/README.md) | Completed milestones, known gaps, and plugin direction |
| [Decisions](08-decisions/README.md) | The context and trade-offs behind important architectural choices |
| [Contributing](09-contributing/README.md) | Setup, validation, platforms, documentation, and themes |

Component documents share the structure described in the
[Component Document Template](00-foundation/05-component-document-template.md).
That consistency is meant to help you find an answer quickly, not to make every
document sound the same.

## Documentation you can trust

The guide is checked alongside the application. The architecture suite reads
imports under `lib/` and compares them with the documented dependency map. The
documentation suite opens this folder through Visual MD's own scanner and
checks titles, README coverage, relative links, anchors, and source citations.

```sh
flutter test test/architecture
flutter test test/docs
```

These checks do not replace review; they make ordinary drift visible while it
is still easy to correct. [Writing Docs](09-contributing/04-writing-docs.md)
explains how citations work and how to verify that a source range still supports
the sentence that points to it.
