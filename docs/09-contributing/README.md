# Contributing

Welcome. This shelf is the practical starting point for understanding Visual
MD's toolchain, making a focused change, and checking the result with
confidence. The application is intentionally small at its centre: open
Markdown, arrange it on a shelf, and make the page worth reading.

You do not need to read the whole handbook before touching the project. Start
with [Development Setup](01-dev-setup.md), make the smallest change that solves
the reader's problem, and use
[Testing and Validation](02-testing-and-validation.md) to choose the right
feedback loop. [Foundation](../00-foundation/README.md) is there when you need
the deeper architectural reasoning.

## Guides

| Document | What it helps you do |
|----------|----------------------|
| [Development Setup](01-dev-setup.md) | Install Flutter and run Visual MD on the web or macOS. |
| [Testing and Validation](02-testing-and-validation.md) | Choose a focused test and run the complete project checks. |
| [Adding a Platform](03-adding-a-platform.md) | Follow the path used for the macOS adapter on another target. |
| [Writing Docs](04-writing-docs.md) | Keep component guides, links, and source references useful. |
| [Creating a Theme](05-creating-a-theme.md) | Create a theme file and understand its schema and fallback behavior. |
| [Releasing for macOS](06-releasing-for-macos.md) | Build, sign, notarize, and audit the Apple distribution artifact. |

## A good first loop

1. Run the app on the platform you are changing.
2. Make one coherent change and add a behavior-focused test when behavior
   moves.
3. Run `bin/tools/beautify.sh` while working.
4. Run the closest test suite, then `bin/tools/validate.sh` before review.
5. Look at the result in the running app whenever the change is visible.

The scripts are the same entry points used by CI, so local success is useful
evidence rather than a separate ritual. If a check fails, its output should
lead to the relevant layer or document.

## Finding the right home

| Change | Ring |
|--------|------|
| A rule about documents, shelf order, or outline structure | `domain/`, with a test |
| A new thing the reader can ask the app to do | `application/use_cases/`, with a port when it needs the outside world |
| A new way to work with the file system or platform | `infrastructure/`, implementing a port |
| A new look or interaction | `api/` |
| Connecting implementations to the app | `lib/main.dart` |

Some features naturally cross more than one ring. In that case, keep each
piece focused: describe the behavior in the domain or application layer,
express outside needs as ports, implement them in infrastructure, and present
the result in the API. [Dependency Direction](../00-foundation/03-dependency-direction.md)
shows the complete map.

## A few conventions that save time

- Private fields with public named parameters in constructors are deliberate
  (`lib/application/use_cases/add_folder.dart`); the related lint is
  silenced locally.
- Adapters read only what the domain keeps, so platform code can reuse domain
  rules instead of creating a second interpretation.
- The composition root is the one place that sees every ring
  (`lib/main.dart`); new capabilities are connected there so their
  dependencies remain easy to find.

If you are unsure where a change belongs, trace one similar path from the
controller to a use case and out through an adapter. The component documents
linked from each shelf explain both the purpose and the evidence in current
code. Questions and corrections are valuable, especially where this guide is
unclear or no longer matches the application.
