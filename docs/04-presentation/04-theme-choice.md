# ThemeChoice

## Purpose and boundary

`ThemeChoice` is what the reader picked, as opposed to what they are currently
looking at. It is a sealed type with two shapes
(`lib/presentation/theme/theme_choice.dart:5-22`): wear one theme always, or
name a light/dark pair and let the system decide.

It owns the *preference* and its serialised form. It does not own the themes
themselves — it holds ids, not `ReaderTheme`s, so a choice stays valid across
restarts even if the theme file behind it has changed. Turning a choice into a
theme is [ThemeRegistry](05-theme-registry.md)'s job.

## Present wiring

| Shape | Fields | `idFor(brightness)` |
|-------|--------|---------------------|
| `FixedTheme` | `id` | Always that id (`lib/presentation/theme/theme_choice.dart:28-29`). |
| `FollowSystem` | `light`, `dark` | The dark id when the system is dark, else the light one (`lib/presentation/theme/theme_choice.dart:46-47`). |

Both implement value equality
(`lib/presentation/theme/theme_choice.dart:34-38`,
`lib/presentation/theme/theme_choice.dart:52-57`), so the controller can skip
work when a reader re-picks what is already on.

### Why a pair, not a switch

Brightness is a property of a theme, not a mode of the app: Nord *is* dark,
Paper *is* light. A flat list plus a light/dark switch gives you the state
where the switch says dark and the selected theme is Latte, and something has
to lose. Modelling the system-following case as a *pair of ids* removes that
state entirely — there is nothing to reconcile, because there is only ever one
answer per brightness.

It also makes the default expressible: the registry's `systemPair` is Paper
and Lamplight (`lib/presentation/theme/theme_registry.dart:73-77`).

## Inputs and outputs

In: `fromJson` accepts any object and returns null rather than throwing
(`lib/presentation/theme/theme_choice.dart:13-21`) — a malformed preference is
not worth an exception, it is worth the default.

Out: `toJson` writes a tagged object — `{"mode":"fixed","theme":"nord"}` or
`{"mode":"system","light":"paper","dark":"nord"}`
(`lib/presentation/theme/theme_choice.dart:33-37`,
`lib/presentation/theme/theme_choice.dart:51-59`). That string is what
`ReaderFiles` stores under the `theme` preference key.

## Events

None today. A choice is a value. When the
[plugin architecture](../07-roadmap/01-plugin-architecture.md) lands, "the
reader changed theme" is a plausible event for reactors to hear; the choice
itself would still just be data on that event.

## Lifecycle

Created at startup from the saved preference, replaced whenever the reader
picks from the [Theme Picker](../05-api/07-theme-picker.md), and written back
immediately. Held by `ReaderController`
(`lib/api/reader_controller.dart:35-72`) for the life of the process.

## Failure and recovery

A preference that is absent, not JSON, tagged with an unknown `mode`, or
missing its ids yields null (`lib/presentation/theme/theme_choice.dart:14-20`)
and the reader falls back to `systemPair`. A choice naming a theme that no
longer exists parses fine and is caught one level out, by the registry's
[resolve](05-theme-registry.md).

## Transition

A third shape is imaginable — schedule-based, or per-library — and the sealed
type means adding one forces every `switch` over it to be updated rather than
silently falling through. The JSON tag makes room: unknown `mode` values
already degrade to the default instead of failing.
