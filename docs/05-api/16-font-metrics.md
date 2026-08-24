# Font Metrics

## Purpose and boundary

`FontMetrics` is what the bundled faces actually measure, and the three things
derived from it: the font size that delivers a given size *of letters*, the
letter size produced by a resolved font size, and the line height that leaves
the same gap in any face
(`lib/api/theme/font_metrics.dart`).

It exists because legibility research is consistent on one point: it is the
x-height, not the nominal point size, that decides how large text reads. Two
faces set at "18 pixels" can differ by a tenth in the size of their letters,
which over a long document is the difference between comfortable and tiring
(`lib/api/theme/font_metrics.dart`). See
[Sources](../04-presentation/10-sources.md).

It owns measurements and arithmetic. It owns no styles — that is
[Theme Binding](06-theme.md) — and no spacing, which is
[Vertical Rhythm](../04-presentation/11-vertical-rhythm.md).

## Present wiring

Three tables, all read from each font's `OS/2` table rather than estimated:

| Face | x-height | Cap height | Descender |
|------|----------|------------|-----------|
| Alegreya | 0.452 | 0.637 | 0.345 |
| Literata | 0.507 | 0.700 | 0.308 |
| Inter | 0.546 | 0.728 | 0.244 |
| Geist Mono | 0.530 | 0.710 | 0.295 |

Citations: `lib/api/theme/font_metrics.dart`, `lib/api/theme/font_metrics.dart`, `lib/api/theme/font_metrics.dart`.

**A size is a size of letters.** `sizeFor(family, size)` returns the font size
that delivers `size` worth of letters in that face
(`lib/api/theme/font_metrics.dart`), quoted against a reference x-height
of 0.55 — where most faces drawn for screens sit
(`lib/api/theme/font_metrics.dart`). So an "18" is 21.9 px in Alegreya
and 19.5 px in Literata, and both put the same size of letter on the page. It
is applied where a family is resolved into a style
(`lib/api/theme/library_theme.dart`).

`letterSizeFor(family, fontSize)` is the inverse. Inline code uses it to recover
the surrounding role's quoted letter size before taking its absolute one-pixel
step and resolving Geist Mono from the result
(`lib/api/render/reading_theme.dart`, `lib/api/theme/font_metrics.dart`).

This measurement exposed a 7 % difference between the body text and the sans
interface face at the same nominal size: Literata's x-height is 0.507, while
Inter's is 0.546.

**Leading is derived, not chosen.** `leadingFor(family, fallback)` returns

```
capHeight + descender + lineGap × xHeight
```

(`lib/api/theme/font_metrics.dart`), where `lineGap` is 1.26 — the white
space wanted between one line's descenders and the next line's capitals, as a
multiple of the x-height (`lib/api/theme/font_metrics.dart`).

The factor 1.26 is the one number here derived from a typographic choice rather
than a font table. It reproduces the established 1.65 leading for Literata and
then applies the same interline-space relationship to the other measured
faces. Faces differ in how much of the em they use, so one unadjusted
multiplier would leave them at visibly different densities
(`lib/api/theme/font_metrics.dart`).

The result is initially counterintuitive: **Alegreya needs less leading than
Literata**, because Literata's ascenders are unusually tall. At the same
multiplier, Alegreya would receive nearly twice the visual gap.

## Inputs and outputs

| In | Type | Meaning |
|----|------|---------|
| `family` | `String` | A font family name, bundled or not |
| `size` | `double` | A size of letters, quoted against 0.55 |
| `fallback` | `double` | The leading to use for a face not measured here |

Out: a font size (`sizeFor`), its inverse letter size (`letterSizeFor`) and a
line-height multiplier (`leadingFor`). All are pure functions over constants;
there is no state.

## Events

None today. These are measurements. A face a theme names that we do not ship
would need its metrics measured before it could join the tables, which is a
reason the [plugin architecture](../07-roadmap/01-plugin-architecture.md) treats
bundled faces and named ones differently.

## Lifecycle

Compile-time constants and static methods. Nothing is constructed and nothing
is cached.

## Failure and recovery

**A face we do not ship is left alone rather than guessed at.** `sizeFor`
returns the size unchanged when the family is not in the table
(`lib/api/theme/font_metrics.dart`), and `leadingFor` returns the
fallback when any of the three measurements is missing
(`lib/api/theme/font_metrics.dart`). A theme naming an unmeasured family
therefore gets ordinary behaviour rather than a wrong correction.

Held by `test/presentation/reading_scale_test.dart`: a face with
smaller letters is given the size that makes up for it, every bundled face ends
up with the same letter size, and an unshipped face is left alone.

## Transition

The tables are hand-transcribed from the font files, so a face added to
`pubspec.yaml` without an entry here is silently un-normalised. Reading `OS/2`
at startup would remove that failure mode, at the cost of parsing font binaries
the app does not otherwise touch.

Alegreya has no optical-size axis, so it takes no `opsz` entry
(`lib/api/theme/font_licences.dart`) and its headings get no display cut —
the one thing Literata does that the reading face does not.
