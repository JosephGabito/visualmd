# Library Chrome

## Purpose and boundary

Library Chrome is the visual system for everything around the authored
document: the top bar, shelf, outline, menus, navigation rows, and the headers
inside code and diagram surfaces. It gives those pieces one hierarchy without
turning theme files into a catalogue of widget colours
(`lib/api/theme/library_chrome.dart`).

The source theme remains the authored contract. Chrome derives interface roles
from its paper, panel, border, ink, and accent materials; it does not add fields
to the custom-theme format or change document typography.

## Present wiring

`libraryTheme` creates `LibraryPalette`, `LibraryTypefaces`, and
`LibraryChrome` together and installs all three as `ThemeExtension` values
(`lib/api/theme/library_theme.dart`). Widgets therefore ask for semantic roles
such as `separator`, `hover`, `selected`, or `elevated`, never a local alpha or
an invented hex value.

`LibraryChromeScale` is the small geometry vocabulary: a 4, 8, 12, 16, and 24
pixel spacing sequence; 30-pixel controls; 32-pixel navigation rows; and a
radius hierarchy that descends from the macOS window silhouette through
floating surfaces, document components, controls, rows, and small details
(`lib/api/theme/library_chrome.dart`). Adjacent choices differ enough to state
a relationship rather than recording visual guesswork.

The host owns the outer window clipping; Flutter does not draw a second fake
window corner inside it. The largest application radius therefore starts with
surfaces inset from that silhouette. Rows and controls are tighter curves, so
the interface cannot become a collection of unrelated rounded rectangles
(`lib/api/theme/library_chrome.dart`).

The palette establishes three quiet planes. The page remains `paper`; the side
rails pull the authored `panel` one measured step toward ink; and the unified
top bar sits closer to those rails than to the page. A softer separator marks
permanent seams. Neutral ink mixtures carry hover and press; accent is reserved
for location, focus, and selected ground. Floating menus and find surfaces move
one opaque step toward the page and receive the only persistent shadow in the
shell (`lib/api/theme/library_chrome.dart`,
`lib/api/widgets/anchored_menu.dart`, `lib/api/widgets/search_view.dart`).

Selection tint is not a fixed percentage. `LibraryChrome` starts from the
theme's preferred accent mixture and backs it toward the panel until ink keeps
the minimum text contrast. That matters for palettes whose ordinary panel text
already sits near the threshold (`lib/api/theme/library_chrome.dart`,
`test/presentation/theme_test.dart`).

Chrome type is structural. `chromeSectionLabel`, `chromeRow`,
`chromeMetadata`, and `chromeComponentLabel` name what a line does. They still
pass through `LibraryTypefaces`, so the same measured x-height correction used
by the rest of the application remains in force
(`lib/api/theme/library_theme.dart`).

`ChromeListRow` applies the shared row geometry and state language to both the
shelf and outline. A selected row gets one ground, one weight change from its
caller, and one short accent location mark; hover, press, keyboard focus, and
corner radius no longer vary by panel
(`lib/api/widgets/chrome_list_row.dart`).

## Inputs and outputs

Input is one `LibraryPalette` plus the theme brightness. Output is an immutable
`LibraryChrome` extension containing opaque surface and state colours. The
context helpers output semantic `TextStyle` values from the active typefaces.

The system reports no user intent. `ChromeListRow` accepts row callbacks and
forwards them unchanged; it owns only presentation and interaction feedback.

## Events

None. Theme switching rebuilds the extension and Flutter interpolates every
role through `LibraryChrome.lerp`. The underlying selection, document, and
panel states remain owned by their existing components.

## Lifecycle

One chrome value is created with each `ThemeData`. Ordinary widgets read it
from context and hold no palette cache. A row keeps only its transient keyboard
focus flag; hover and press remain Material ink states
(`lib/api/widgets/chrome_list_row.dart`).

## Failure and recovery

Every application theme installs the extension. `context.chrome` also derives
a conservative fallback from ordinary `ThemeData`, which keeps the interaction
primitive usable in isolated hosts and tests (`lib/api/theme/library_theme.dart`).

The theme test verifies that every structural surface is opaque and that ink
keeps accessible contrast on selected and selected-hover grounds for every
built-in theme (`test/presentation/theme_test.dart`).

## Transition

New persistent chrome should first reuse a spacing, type, state, or elevation
role here. Add another token only when a genuinely different relationship
appears in more than one component. Document reading styles continue to belong
to [Reading Theme](14-reading-theme.md), whose rhythm must not be collapsed into
this compact interface scale.
