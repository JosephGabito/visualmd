# 0001 — Hexagonal Layering

Status: Accepted · 2026-08-22

## Context

Visual MD began with one structural requirement: platform and framework details
must stay at the edge, while product rules remain independent and testable. The
dependency shape was established before features were added:

> API calls application use cases. Use cases depend on domain rules and ports
> they declare. Infrastructure supplies the port implementations, while
> presentation defines framework-free contracts shared with the UI.

The product is small today and expected to grow by platforms (web, macOS,
Windows, later mobile and a browser extension) and by features (plugins).
Clear boundaries let either kind of growth happen without coupling the kernel
to a particular platform or extension.

## Decision

Five rings, every dependency pointing inward:

- `domain/` — pure Dart, no packages, no I/O. Entities, value objects, the
  rules of the library.
- `application/` — use cases that orchestrate the domain, and the ports they
  need declared as interfaces in `application/ports/`.
- `presentation/` — framework-free contracts for themes and typography.
- `api/` — the Flutter UI. Calls use cases. Never imports infrastructure.
- `infrastructure/` — adapters implementing the ports, and platform helpers
  that feed them. Never imports `api/`.

`lib/main.dart` is the composition root and the only file that imports all
five. The rules are enforced by a test that fails on the first outward import.

## Consequences

- A new platform is a new adapter family plus one `PlatformAdapters`
  implementation; the inner rings do not change. The macOS target demonstrated
  that boundary: it required no edits to `domain/` or `application/`, while
  `api/` received optional hooks with identity defaults (`dropRegion`, `topBar`,
  `windowDragRegion` in `lib/api/app.dart`) for injected wrappers and
  geometry.
- Domain rules are unit-testable with no Flutter, no browser and no disk.
- The UI cannot reach the platform directly. Anything it needs crosses the
  composition root as a function or value, which is slightly more plumbing
  than a global would be. That plumbing is the point.
- Dart has no module visibility, so the layering is convention plus an
  architecture test rather than compiler-enforced module boundaries.
- Over-engineering risk is real for an app this size. The mitigation is that
  abstractions are added around concrete capabilities and kept narrow; a port
  describes what a use case needs rather than mirroring an entire platform.

## Evidence

- Ring rules as data: `test/architecture/dependency_rules_test.dart`.
- The rule that `domain/` imports no package at all: `test/architecture/dependency_rules_test.dart`.
- Ports declared by the application, not by the adapters: `lib/application/ports/folder_scanner.dart`, `lib/application/ports/library_repository.dart`.
- A use case that depends only on ports and domain:
  `lib/application/use_cases/add_folder.dart`.
- The UI receiving platform capabilities as plain functions and values: `lib/api/app.dart`.
- The composition root: `lib/main.dart`.
- The written rules: [Dependency Direction](../00-foundation/03-dependency-direction.md).
