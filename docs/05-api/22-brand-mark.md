# Brand Mark

## Purpose and boundary

`BrandMark` renders the Visual MD artwork inside Flutter at a caller-selected
square size. It owns no product behavior and does not replace semantic icons
such as folders, search, deletion, or document kinds.

The reusable widget lives in the API ring. Platform launchers consume their
own generated icon formats directly rather than importing Flutter code.

## Present wiring

The widget reads one bundled RGBA asset, preserves its aspect ratio, and uses
high-quality filtering at the small sizes required by application chrome
(`lib/api/widgets/brand_mark.dart:3-21`). The asset is declared explicitly so
the original full-resolution design source is not added to the application
bundle (`pubspec.yaml:25-35`).

The welcome screen and drag overlay render the detailed mark at 64 logical
pixels (`lib/api/widgets/welcome_view.dart:50`,
`lib/api/widgets/drop_overlay.dart:23-29`). The top bar uses the same source at
18 pixels beside the product name (`lib/api/screens/reader_screen.dart:697-707`).

macOS consumes the complete 16–1024 pixel asset catalog
(`macos/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json:1-67`). Windows
loads the multi-resolution ICO through its native resource table
(`windows/runner/Runner.rc:48-55`). The web manifest declares standard and
maskable 192/512 pixel variants (`web/manifest.json:10-32`).

## Inputs and outputs

Input is one logical `size`. Output is a decorative square `Image` using
`assets/brand/visual-md-logo.png`. Standard platform icons have transparent
corners; maskable web icons use an opaque brand-blue field so browser masks do
not expose unpainted pixels.

## Events

None. The mark is static presentation.

## Lifecycle

Flutter resolves and caches the bundled image through its normal asset bundle.
Native launchers load their platform resources before Flutter starts.

## Failure and recovery

A missing Flutter asset fails during development and widget tests rather than
falling back to a different identity. Native builds likewise validate their
asset catalog or resource reference. The artwork is excluded from semantics
because adjacent text already names Visual MD; repeating that name would add
noise without another action or meaning.

## Transition

Future artwork changes begin with the original master, then regenerate every
declared size together. Semantic interface icons remain Material symbols unless
their meaning changes; brand replacement is not permission to decorate every
control with the application mark.
