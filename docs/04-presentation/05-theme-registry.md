# ThemeRegistry

## Purpose and boundary

`ThemeRegistry` is every theme the reader can wear, and the one place that
decides what happens when a theme file is wrong
(`lib/presentation/theme/theme_registry.dart:21-80`). It merges the built-ins
with whatever the platform found, resolves a
[ThemeChoice](04-theme-choice.md) into an actual
[ReaderTheme](01-reader-theme.md), and keeps a list of what it had to skip.

It does not read files. Raw `(origin, json)` records arrive from
[ReaderFiles](../03-infrastructure/desktop/05-reader-files.md) by way of the
composition root; the registry only parses. That is what keeps this ring
framework-free while still owning the loading *policy*.

## Present wiring

Themes live in an id-keyed map filled built-ins first, user themes second
(`lib/presentation/theme/theme_registry.dart:32-38`). The second write wins,
so **a user theme whose `id` matches a built-in replaces it** — that is the
supported way to tweak a shipped theme rather than fork it.

| Member | Answers |
|--------|---------|
| `all` | Every theme, built-ins first (`lib/presentation/theme/theme_registry.dart:63`). |
| `light` / `dark` | The same list split by brightness, for the picker's two groups (`lib/presentation/theme/theme_registry.dart:65-67`). |
| `byId` | One theme, or null (`lib/presentation/theme/theme_registry.dart:69`). |
| `systemPair` | The default `FollowSystem`: Paper and Lamplight (`lib/presentation/theme/theme_registry.dart:73-77`). |
| `errors` | Files that could not be used (`lib/presentation/theme/theme_registry.dart:23`). |

`resolve(choice, brightness)` asks the choice for an id, looks it up, and
falls back to the default theme *of that brightness* when it is missing
(`lib/presentation/theme/theme_registry.dart:75-79`). A deleted theme file
therefore leaves the reader on Paper or Lamplight, never on a blank window.

## Inputs and outputs

In: `fromDocuments` takes an iterable of `({String origin, String json})`
records (`lib/presentation/theme/theme_registry.dart:44`). The default
constructor takes already-built themes, which is how tests build a registry
without touching JSON (`test/presentation/theme_test.dart:78-84`).

Out: a registry, plus `errors` as `ThemeLoadError` — an origin and a reason
(`lib/presentation/theme/theme_registry.dart:10-17`). The composition root
prints them and the [Theme Picker](../05-api/07-theme-picker.md) shows the
count, so a broken file is visible without being fatal.

## Events

None today. The registry is built once and asked questions. Under the
[plugin architecture](../07-roadmap/01-plugin-architecture.md) it is the
prototype of an extension-point registry: contributions collected, conflicts
resolved by a stated rule, failures reported rather than thrown.

## Lifecycle

Built once in `lib/main.dart` before the controller exists, from documents the
platform supplies; immutable thereafter. Adding or editing a theme file takes
effect on the next launch — there is no watcher.

## Failure and recovery

`fromDocuments` catches two kinds of failure per document and keeps going
(`lib/presentation/theme/theme_registry.dart:47-59`):

| Failure | Recorded reason |
|---------|-----------------|
| Not valid JSON | `not valid JSON: <message>` |
| Valid JSON, not an object | `top level must be an object` |
| Fails the contract | The `ThemeFormatException` reason, verbatim |

An unreadable file skips that theme while the remaining themes stay available.
Because the built-ins are compile-time constants, the registry always has a
fallback.

## Transition

The natural next step is reloading without a restart, which means an adapter
that watches the folder and a registry that can be rebuilt — the parsing
policy here would not change. If extension points arrive for renderers, they
should copy this shape: merge, replace-by-id, collect errors, never throw.
