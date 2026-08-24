# Creating a Theme

A theme is a JSON file, not executable code. If Visual MD cannot read one
theme file, it skips that file, reports the reason, and keeps the rest of the
library available. The contract lives in the framework-free `presentation`
ring, so a theme remains plain data from disk to renderer. It is described in
[ReaderTheme](../04-presentation/01-reader-theme.md) and
[ThemePalette](../04-presentation/02-theme-palette.md); the Flutter side is
[Theme Binding](../05-api/06-theme.md).

## Where the file goes

| Platform | Folder |
|----------|--------|
| macOS | `Visual MD/themes` inside the sandbox container: `~/Library/Containers/com.visualmd.visualmd/Data/Library/Application Support/com.visualmd.visualmd/Visual MD/themes` |
| Web | Nowhere — the browser has no folder to read, so only built-ins are offered |

The picker prints the exact path at the bottom of its menu, so the reliable
way to find it is to open the theme menu and look
(`lib/api/widgets/theme_picker.dart`). The folder is created on first
launch, with a `README.md` describing this same format written into it
(`lib/infrastructure/io/reader_files.dart`, `lib/infrastructure/io/reader_files.dart`).

Every `.json` file in that folder is read, in name order; anything else is
ignored (`lib/infrastructure/io/reader_files.dart`). Themes are loaded
once at startup, so add a file and restart.

## The document

```json
{
  "schema": 1,
  "id": "sepia",
  "name": "Sepia",
  "brightness": "light",
  "palette": {
    "paper": "#f4ecd8",
    "panel": "#ece3cc",
    "border": "#d8ccb0",
    "ink": "#3b2f2f",
    "muted": "#7a6a5a",
    "accent": "#8b4513",
    "codeBackground": "#ebe2c9"
  },
  "typefaces": {
    "serif": "Lora"
  }
}
```

| Field | Required | Meaning |
|-------|----------|---------|
| `id` | yes | Lowercase letters, digits and hyphens, starting with a letter or digit (`lib/presentation/theme/reader_theme.dart`). |
| `name` | yes | What the menu shows. |
| `brightness` | yes | `light` or `dark` (`lib/presentation/theme/reader_theme.dart`). |
| `palette.paper` | yes | The page. |
| `palette.panel` | yes | Shelf, outline and table heads. |
| `palette.border` | yes | Dividers, rules, code and table borders. |
| `palette.ink` | yes | Body text. |
| `palette.muted` | yes | Breadcrumbs, counts, inactive outline entries. |
| `palette.accent` | yes | Links, active outline entry, bullets, selected row. |
| `palette.codeBackground` | yes | Fenced-code header; the body derives a lighter or darker tone. |
| `palette.accentSoft` | no | Selected and hovered rows. Derived from the accent over the paper when absent. |
| `palette.selection` | no | Text selection. Derived from the accent at 30 % alpha when absent. |
| `typefaces.serif` / `.sans` / `.mono` | no | Bundled or Google Fonts family names. Each falls back independently (`lib/presentation/theme/theme_typefaces.dart`). |

`schema` is not read today; write `1` so a future loader can tell what it is
looking at (`lib/presentation/theme/reader_theme.dart`).

Colours accept `#rgb`, `#rrggbb` and `#rrggbbaa`, with or without the `#`
(`lib/presentation/theme/theme_palette.dart`). Three-digit hexes expand the way
CSS does, and a missing alpha means opaque.

## Two things worth knowing

**An `id` that matches a built-in replaces it**
(`lib/presentation/theme/theme_registry.dart`). To warm up Paper by a few
degrees, write a file with `"id": "paper"` — the shipped one steps aside and
the menu keeps one entry.

**A theme changes colour and typeface.** Sizes, spacing and weights remain part
of the shared reading design. Code
colouring, diagrams and images are a separate scope and are not part of the
theme contract — see the [Backlog](../07-roadmap/02-backlog.md).

## If a file cannot be loaded

A file that is not valid JSON, or is missing a required field, or has a colour
that will not parse, is skipped with a reason
(`lib/presentation/theme/theme_registry.dart`). The reason is printed at startup
(`lib/main.dart`) and the menu shows how many files were skipped
(`lib/api/widgets/theme_picker.dart`). Every other theme still loads.

The messages name the field: `"name" must be a non-empty string`,
`"brightness" must be "light" or "dark", not "dim"`,
`palette."ink" is not a hex colour: "blue"`. They are tested in
`test/presentation/theme_test.dart`, which is also a compact reference
for the accepted format.
