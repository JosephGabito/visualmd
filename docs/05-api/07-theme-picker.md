# Theme Picker

## Purpose and boundary

`ThemePicker` is the top-bar control that shows what the reader is wearing and
lets them change it. It owns the menu and the swatches; it owns no state. What
themes exist is the [ThemeRegistry's](../04-presentation/05-theme-registry.md) business, what is
worn is the [Reader Controller's](01-reader-controller.md), and where user
theme files live is the platform's — the picker is handed all three.

It lives in the API ring (`lib/api/widgets/theme_picker.dart`) and knows
nothing about files, JSON or platforms. The types it displays — `ReaderTheme`,
`ThemeChoice`, `ThemeRegistry` — come from the `presentation` ring, which may
import no package at all, so the picker is the only half of the theme system
that touches Flutter.

## Present wiring

`ReaderScreen` builds one and hands it to `_TopBar` as a widget, so the bar
does not know what a theme is (`lib/api/screens/reader_screen.dart`,
`lib/api/screens/reader_screen.dart`). It is rendered between the app
name and the outline toggle (`lib/api/screens/reader_screen.dart`).

The menu is an [Anchored Menu](08-anchored-menu.md)
(`lib/api/widgets/theme_picker.dart`); choosing a row closes it and
passes the choice straight to `ReaderController.chooseTheme`
(`lib/api/widgets/theme_picker.dart`). Its rows are:

| Entry | Value | Source |
|-------|-------|--------|
| Follow system | `registry.systemPair` | `lib/api/widgets/theme_picker.dart` |
| Light group | `FixedTheme(id)` per theme | `lib/api/widgets/theme_picker.dart` |
| Dark group | `FixedTheme(id)` per theme | `lib/api/widgets/theme_picker.dart` |
| Paragraphs: "Separated by space" | `ParagraphMarking.spaced` | `lib/api/widgets/theme_picker.dart` |
| Paragraphs: "Indented, set solid" | `ParagraphMarking.indented` | `lib/api/widgets/theme_picker.dart` |
| A skipped theme's filename and validation reason | not selectable | `lib/api/widgets/theme_picker.dart`, `lib/api/widgets/theme_picker.dart` |
| Open themes folder | platform callback | `lib/api/widgets/theme_picker.dart` |

The menu is no longer only about themes, which is why its tooltip reads
"Reading: <theme name>" (`lib/api/widgets/theme_picker.dart`). Both
paragraph rows change how the page is *set* rather than what it is set in —
see [Reading Scale](../04-presentation/07-reading-scale.md) for why the two
markings are alternatives and never both.

Each row lights up under the pointer before it acts and draws a two-pixel focus
ring when reached from the keyboard (`lib/api/widgets/theme_picker.dart`). It
is exposed as a named button, with the current theme or paragraph choice also
marked selected, and Enter or Space makes the same choice as a pointer. Each
carries a `_Swatch`: the word "Aa" drawn in that theme's own accent on its own
paper, framed in its own border
(`lib/api/widgets/theme_picker.dart`). The button itself is the swatch
of the theme currently in use (`lib/api/widgets/theme_picker.dart`), so
the bar always shows what is being worn.

## Inputs and outputs

In: a `ThemeRegistry`, the current `ThemeChoice` and `ParagraphMarking`, an
`onChoose` and an `onMark` callback, and an optional `onOpenThemesFolder`
callback
(`lib/api/widgets/theme_picker.dart`).
Out: one `ThemeChoice` or one `ParagraphMarking` per selection, or one request
to reveal the custom-theme directory. The picker reads the system brightness
from `MediaQuery` to decide which theme a "follow system" choice is currently
resolving to (`lib/api/widgets/theme_picker.dart`).

## Events

None today; the picker calls a callback. When the plugin architecture lands,
the top bar becomes a slot other contributors can render into, and this widget
is the first thing occupying it — see the
[plugin architecture](../07-roadmap/01-plugin-architecture.md).

## Lifecycle

Stateless, rebuilt with the top bar on every controller notification. The
registry it reads is built once at startup and never changes while the app
runs, so adding a theme file means restarting.

## Failure and recovery

A chosen theme that no longer exists resolves to the default of the current
brightness (`lib/presentation/theme/theme_registry.dart`), so the picker always
has something to draw. Theme files that failed to parse show their filename
and exact validation reason in the menu, where a release user can act without
a development console (`lib/api/widgets/theme_picker.dart`,
`lib/api/widgets/theme_picker.dart`). On the web
the callback is null and the action is simply absent
(`lib/infrastructure/platform/platform_web.dart`).

## Transition

Reloading themes without a restart would turn the registry into something
observable rather than a constructor argument.
