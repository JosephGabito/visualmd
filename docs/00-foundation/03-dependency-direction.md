# Dependency Direction

Visual MD keeps product decisions separate from the tools that carry them out.
Changing a filesystem adapter should not change what the library considers a
document. Dependencies therefore point inward, and an architecture test keeps
that relationship visible.

## The rings

```
        ┌──────────────────────────────────────────────────────┐
        │  infrastructure/   (adapters: web, io, memory, platform)
        │      ┌──────────────────────────────────────────┐    │
        │      │  api/   (Flutter UI, ReaderController)    │    │
        │      │   ┌───────────────┐  ┌────────────────┐   │    │
        │      │   │ presentation/ │  │  application/  │   │    │
        │      │   │  theme/       │  │ use_cases/     │   │    │
        │      │   │  (no packages)│  │ ports/         │   │    │
        │      │   └───────────────┘  │  ┌──────────┐  │   │    │
        │      │                      │  │ domain/  │  │   │    │
        │      │                      │  │(no pkgs) │  │   │    │
        │      │                      │  └──────────┘  │   │    │
        │      │                      └────────────────┘   │    │
        │      └──────────────────────────────────────────┘    │
        └──────────────────────────────────────────────────────┘
                              ▲
                 main.dart — the composition root, sees every ring

   api ──▶ application ──▶ domain ◀── infrastructure
    │              ▲                          │
    │              └──── implements ports ────┘
    └──▶ presentation   (portable definitions for contributions)
```

Control flows api → application → domain. Data the application needs from the
outside world arrives through ports it declares itself; infrastructure
supplies the implementations; `main.dart` connects the two.

## Allowed dependencies

| Ring | May import | Kept separate from |
|------|------------|--------------------|
| `domain/` | `domain/` only; Dart SDK libraries except the platform ones | packages, other rings, and platform SDK libraries |
| `application/` | `application/`, `domain/` | `api/`, `infrastructure/`, and platform packages |
| `presentation/` | `presentation/` only; Dart SDK libraries except the platform ones | packages (Flutter included), other rings, and platform SDK libraries |
| `api/` | `api/`, `presentation/`, `application/`, `domain/`, Flutter | `infrastructure/` and platform APIs |
| `infrastructure/` | `infrastructure/`, `application/`, `domain/`, Flutter, platform packages | `api/` |
| `main.dart` | every ring | — |

"Platform packages" are the ones that touch the outside world: `web`,
`desktop_drop`, `file_selector`, `window_manager`. "Platform SDK libraries"
are `dart:io`, `dart:js_interop` and `dart:html`. Both are confined to
`infrastructure/`.

Anything `api/` needs from the platform — a folder picker, a drop region, the
top-bar geometry — arrives as a plain function or value through `main.dart`.
`api/` never learns whether it is in a browser or a sandbox. See
[Composition Root](04-composition-root.md).

## The traffic a document takes

A document crosses three rings on its way to the page. At each step the
responsibility becomes narrower:

1. `infrastructure/markdown` tokenises the source and builds
   [`DocumentContent`](../01-domain/05-document-content.md), a domain value —
   allowed because infrastructure may import domain (below).
2. `application` asks for it through a port it declares itself
   (`lib/application/ports/document_parser.dart:7-9`), inside `DocumentReading`.
3. `api/render` sets it, deciding nothing about what the document *says*, only
   how it looks.

The adapter depends on the domain model; the domain does not depend on the
markdown package that produced it.

## Infrastructure may import domain

Adapters apply domain rules at the edge so they do not move bytes the domain
will discard: the browser and filesystem scanners only read files that
`MarkdownFile.isMarkdown` accepts and `HiddenFolders` does not hide. Reusing
those domain decisions at the edge avoids a second, subtly different filter.
Evidence: `lib/domain/library/markdown_file.dart:5-9`,
`lib/domain/library/hidden_folders.dart:24-33`.

## Presentation is framework-free on purpose

`presentation/` holds portable definitions a contribution is written against —
today that is [Presentation](../04-presentation/README.md), including what a
theme is. It imports no package, Flutter included, which lets a contribution be
described as data without depending on the widget tree.

A theme is **data**. If its definition could import Flutter, it could also hold
a widget or reach into the tree at render time. The separate ring makes the
boundary mechanically checkable
(`test/architecture/dependency_rules_test.dart:21-24`,
`:106-109`) instead of leaving it as an easy-to-miss convention.

The cost is one deliberate duplication: `ThemePalette` carries `dart:ui`
colours, and `LibraryPalette` re-declares them as a Flutter `ThemeExtension`
so the widget tree can read them (`lib/api/theme/library_theme.dart:34-45`).
That bridge is nine lines and lives in `api/`, where Flutter belongs.

## How the boundary is checked

`test/architecture/dependency_rules_test.dart` reads every file under `lib/`,
extracts its `import` and `export` directives, and reports outward imports. It
encodes the table above, with two places where the test is broader
than the prose: the framework-free rings may import any `dart:` library except
`dart:io`, `dart:js_interop` and `dart:html`
(`test/architecture/dependency_rules_test.dart:51-52`, `:113-117`), and
`application/` may
import non-platform packages
(`test/architecture/dependency_rules_test.dart:106-112`). The application does
not currently use that package allowance; presentation uses only `dart:ui` and
`dart:convert` from the SDK.

| Rule | Where |
|------|-------|
| Which rings each ring may import | `allowedRings` — `test/architecture/dependency_rules_test.dart:26-40` |
| `presentation/` may import only itself | `test/architecture/dependency_rules_test.dart:30` |
| `api/` may import `presentation/` | `test/architecture/dependency_rules_test.dart:31` |
| Platform packages confined to infrastructure | `platformPackages` — `test/architecture/dependency_rules_test.dart:43-49` |
| Platform SDK libraries confined to infrastructure | `platformSdkLibraries` — `test/architecture/dependency_rules_test.dart:51-52` |
| `domain/` and `presentation/` import no package at all | `frameworkFreeRings` — `test/architecture/dependency_rules_test.dart:21-24`, applied at `test/architecture/dependency_rules_test.dart:106-109` |
| `lib/` contains only the five rings and `main.dart` | `test/architecture/dependency_rules_test.dart:82-94` |
| One test per source file, so a report names the file | `test/architecture/dependency_rules_test.dart:96-124` |

Relative imports are normalised against the importing file
(`test/architecture/dependency_rules_test.dart:59-68`) so `../../domain/...`
is judged by where it lands, not how it is spelled.

## Boundary test

When you are unsure where code belongs, ask what kind of change would affect it.
A platform change points to infrastructure; a UI-toolkit change points to API.
A definition written against by an outside contributor belongs in presentation; a different driver, such as a CLI, points to application.
What remains is domain behaviour.

Related: [Hexagonal Layering](../08-decisions/0001-hexagonal-layering.md),
[Testing and Validation](../09-contributing/02-testing-and-validation.md).
