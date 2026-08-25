# Document Image

## Purpose and boundary

`DocumentImage` turns one parsed Markdown image into pixels without giving a
Flutter widget authority over the filesystem or browser handles
(`lib/api/widgets/document_image.dart`). The image may be local to the opened
document, remote over HTTP, decorative, unavailable, tiny, or much larger than
the reading page. Every case keeps the page reachable.

Parsing remains the Markdown adapter's work. Local path resolution and byte
access belong to the application port and infrastructure adapters. This widget
owns only progressive loading, bounded presentation, advisory titles,
alternative text, and image semantics.

## Present wiring

`InlineComposer` places the component in a `WidgetSpan` and supplies the
current `DocumentId`, authored source, plain alternative, optional title,
`DocumentImageLoader`, and `ReadingTheme`
(`lib/api/render/inline_composer.dart`).

HTTP and HTTPS destinations use `Image.network`. Document-relative sources ask
the loader for bytes and use `Image.memory`. Both paths share the same rules:

- preserve the intrinsic aspect ratio with `BoxFit.scaleDown`;
- align artwork with the reading edge rather than centring a small image;
- never exceed the paragraph width or 72 percent of the viewport height;
- request a decode no wider than the painted physical width where the provider supports it;
- spend any fractional body line below the artwork so prose resumes on beat;
- expose non-empty alternative text as the image's semantic label;
- omit decorative empty alternatives from the semantic tree;
- wrap an optional title in a `Tooltip` without replacing its alternative;
- show the authored alternative when loading or decoding fails.

The remote provider requests Flutter's HTML-element fallback on web. A server
that blocks cross-origin byte access may still display its image, while a
genuine failure follows the same alternative-text path
(`lib/api/widgets/document_image.dart`).

## Inputs and outputs

| In | Meaning |
|----|---------|
| `document` | Identity whose directory and opened root govern a relative source |
| `source` | Destination exactly as parsed from Markdown |
| `alt` | Plain authored alternative, empty only for decorative artwork |
| `title` | Optional advisory text |
| `loader` | Capability for document-local bytes; remote images do not use it |
| `theme` | Body and muted styles for progressive and failed states |

Out: one bounded image, or a quiet text alternative. No source path, exception,
broken-image glyph, or fabricated filename is exposed to the reader.

## Events

None. Loading completion rebuilds this component locally. It does not publish a
document or library event.

## Lifecycle

The state caches the local load future for the current document, source, and
loader. A change to any of those three begins a new lookup; unrelated rebuilds
do not reread the file (`lib/api/widgets/document_image.dart`). Flutter owns
decoded image caching after bytes reach `Image.memory` or `Image.network`.

## Failure and recovery

A missing file, denied browser handle, unsafe local path, failed network
request, or corrupt payload all become the alternative text in muted reading
ink. One bad image therefore cannot fail `ReadDocument` or replace the page
with an error surface. Empty decorative artwork uses “Image unavailable” only
when it fails, because there is no authored text to preserve.

Sizing and recovery are exercised with one-pixel, oversized square, corrupt,
remote, titled, and decorative specimens
(`test/presentation/document_image_test.dart`). Path authority is tested at
the application and desktop infrastructure edges
(`test/application/document_image_path_test.dart`,
`test/infrastructure/local_document_image_loader_test.dart`).

## Transition

Animated image policy and explicit captions remain unmodelled; neither is
implied by CommonMark image syntax. A future block-image or figure contributor
can build on the same loader without widening this inline component's contract.
