# Foundation

Start here when you want to understand Visual MD rather than simply run it.
This shelf introduces the product, gives its concepts a shared vocabulary, and
shows how the code fits together. You do not need to memorise it: the aim is to
give you a map you can return to while exploring the rest of the project.

If this is your first visit, read the first three documents in order. They move
from *why the product exists*, to *the words used in the code*, to *where each
kind of work belongs*.

| Document | What you will learn |
|----------|---------------------|
| [Purpose and Status](01-purpose-and-status.md) | What Visual MD is trying to become, what already works, and what is still unfinished. |
| [Ubiquitous Language](02-ubiquitous-language.md) | The names shared by the interface, code, tests, and documentation. |
| [Dependency Direction](03-dependency-direction.md) | How the rings keep reading policy separate from Flutter and platform details. |
| [Composition Root](04-composition-root.md) | How `lib/main.dart` connects the rings into a running application. |
| [Component Document Template](05-component-document-template.md) | The common shape used by detailed component documents. |

## A useful reading path

After the first three documents, continue to [Domain](../01-domain/README.md)
to meet the model at the centre of the application. When a change needs access
to files, browser APIs, or another platform capability, [Composition Root](04-composition-root.md)
and [Adding a Platform](../09-contributing/03-adding-a-platform.md) show how that
outside-world detail connects without leaking inward.

The architecture is intentionally explicit, but it is here to make changes
easier to reason about, not to create ceremony. The dependency test gives quick
feedback when code lands in the wrong ring, while [Dependency Direction](03-dependency-direction.md)
explains the design behind that feedback.

## When these documents change

Foundation documents describe choices shared across the project, so they tend
to change less often than feature documentation. Update the language when a new
product concept appears, update the composition walkthrough when its wiring
changes, and record a meaningful architectural shift in
[Decisions](../08-decisions/README.md). [Writing Docs](../09-contributing/04-writing-docs.md)
explains how links and source references stay aligned with the code.

From here, the most useful next shelves are:

- [Domain](../01-domain/README.md) for the model and its behaviour.
- [Decisions](../08-decisions/README.md) for the reasoning behind important choices.
- [Roadmap](../07-roadmap/README.md) for ideas that are not part of the product yet.
- [Contributing](../09-contributing/README.md) for a practical path from change to validation.
