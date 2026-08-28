# ReadingMode

## Purpose and boundary

`ReadingMode` is the reader's choice of proportional voice: `serif` or `sans`
(`lib/presentation/theme/reading_mode.dart`). It selects a role from the active
theme. It does not name a font, change a palette, set a size, or alter the mono
voice used for code.

That boundary keeps reading preference independent from appearance. A reader
can keep Sans while moving from Paper to Nord, and a custom theme still supplies
the particular sans family that its author chose.

## Present wiring

The established default is `ReadingMode.serif`, which keeps Alegreya as the
reading face. `ReadingMode.sans` selects Inter from
`ThemeTypefaces.library` (`lib/presentation/theme/reading_mode.dart`,
`lib/presentation/theme/theme_typefaces.dart`).

The [Theme Picker](../05-api/07-theme-picker.md) presents both choices under a
Reading mode section before Themes. Each row draws `Aa` in the role it selects,
and the toolbar swatch uses the active role
(`lib/api/widgets/theme_picker.dart`).

`ReaderController.chooseReadingMode` updates the choice, notifies the shell and
writes its stored name under `readingMode` (`lib/api/reader_controller.dart`).
The shell passes it to [Reading Pane](../05-api/04-reading-pane.md), which passes
it to [Reading Theme](../05-api/14-reading-theme.md)
(`lib/api/screens/reader_screen.dart`, `lib/api/widgets/reading_pane.dart`).

`ReadingTheme` then derives body, headings, quotations, tables and footnotes
from that role. Code remains Geist Mono, and interface furniture continues to
use the theme's sans independently (`lib/api/render/reading_theme.dart`).

## Inputs and outputs

| In | Out |
|----|-----|
| `ThemeTypefaces` | `familyOf` returns its `serif` or `sans` family |
| Stored `"sans"` | `ReadingMode.sans` |
| Missing, unknown, or `"serif"` | `ReadingMode.serif` |

The stored form is deliberately a small stable string, not an enum index. A new
case can therefore be added without changing the meaning of an existing
preference (`lib/presentation/theme/reading_mode.dart`).

## Events

None. The value is immutable. The API controller emits its ordinary change
notification after a reader chooses a mode (`lib/api/reader_controller.dart`).

## Lifecycle

The composition root reads the preference once at launch and gives it to the
controller (`lib/main.dart`). It lives for the process and is written whenever
the reader changes it. It is a personal reading preference, not part of a
workspace file; opening another library or changing theme does not reset it.

## Failure and recovery

An unreadable stored value resolves to Serif so an older or damaged preference
cannot prevent the app opening (`lib/presentation/theme/reading_mode.dart`). A
theme family that cannot be loaded follows the existing per-role font fallback
in `LibraryTypefaces` (`lib/api/theme/library_theme.dart`).

Inter 4.001 has proportional and tabular lining figures but no old-style figure
set. Sans prose therefore requests `pnum`, while Sans tables request `tnum`;
Serif retains Alegreya's `onum` prose and `lnum` plus `tnum` tables. Unsupported
features are never presented as part of the Sans contract
(`lib/api/render/reading_theme.dart`, `test/typography_measure_test.dart`).

## Transition

The two modes are deliberate systems rather than the beginning of an arbitrary
font picker. A future proportional voice would need measured x-height, cap
height, descender, figure features, Flutter shaping evidence and a reason that
Serif and Sans do not already satisfy.
