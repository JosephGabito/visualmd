# Widow Binding

## Purpose and boundary

The rule that keeps the last word of a paragraph from standing alone on a line
of its own. It owns the *text transformation*; it owns no layout and does no
measuring.

A single word on the last line is a widow: the eye reaches the end of the
penultimate line, drops, and finds one word where it expected a line
(`lib/presentation/theme/widow_binding.dart`). Text that re-flows — a
window resized, a text size changed, a panel opened — cannot be fixed by
adjusting a line break, because there is no fixed line to adjust. The remedy
that survives re-flowing is the old one: bind the last two words with a space
that cannot break, so the pair falls together or not at all.

Plain data and plain string work, with no framework attached. Applying it to
composed spans is [Paragraph](../05-api/15-paragraph.md)'s job, one ring out.

## Present wiring

`WidowBinding` is a namespace, never instantiated
(`lib/presentation/theme/widow_binding.dart`). It holds two constants and
three functions:

| Name | Value | Meaning |
|------|-------|---------|
| `nonBreakingSpace` | `U+00A0` | A space no line may break at (`lib/presentation/theme/widow_binding.dart`) |
| `leastWords` | 4 | Below this the paragraph is left alone (`lib/presentation/theme/widow_binding.dart`) |
| `bind` | `String → String` | The text with its final space bound, when binding is worth it (`lib/presentation/theme/widow_binding.dart`) |
| `bindingOffset` | `String → int?` | The one authored boundary to bind, without creating a changed copy (`lib/presentation/theme/widow_binding.dart`) |
| `bindLastSpace` | `String → String` | Binds an already-approved final leaf after its caller counts a styled paragraph (`lib/presentation/theme/widow_binding.dart`) |

`bind` declines in three cases before it changes anything
(`lib/presentation/theme/widow_binding.dart`):

1. Text ending in whitespace is returned untouched — it is not the end of a
   paragraph, so its last word is not the last word.
2. Fewer than `leastWords` words are returned untouched: with three words or
   fewer the last line is usually the only line, and binding would only make
   it narrower.
3. Text with no space at all is returned untouched.

Otherwise the final space becomes a non-breaking one
(`lib/presentation/theme/widow_binding.dart`). Paragraph applies that
decision across the whole span tree, preserving emphasis while leaving link
and code endings untouched.

## Inputs and outputs

| In | Type | Meaning |
|----|------|---------|
| `text` | `String` | Plain text being considered or the final eligible leaf |

| Out | Type | Meaning |
|-----|------|---------|
| | `String` | The same text, or the same text with its last space bound |

## Events

None today. A rule about spaces has nothing to announce, and nothing
downstream needs to know it ran.

## Lifecycle

Stateless and synchronous; the constants are compile-time. `bindingOffset`
stops counting as soon as the fourth word proves the paragraph eligible, then
searches backward for the final breakable space without allocating a changed
copy. `bind` applies that one boundary for an eager paragraph. A range renderer
can instead change it only inside the final bounded window.

## Failure and recovery

It cannot throw: every path returns the input or a string built from it. The
worst case is a paragraph whose last two words are long, which fills the last
line rather than emptying it — the trade the remedy has always made.

One consequence is worth stating because it is visible outside the page: the
rendered text now contains `U+00A0`, so **text copied out of the reader
carries the non-breaking space with it**, exactly as copied web text does.
Anything matching on the rendered text — a test, a search — has to expect it.

Covered by `test/presentation/paragraph_setting_test.dart`: the last
two words bind, short and trailing-space text stay alone, word counting crosses
runs, final emphasis survives and code endings remain byte-for-byte unchanged.

## Transition

The rule is deliberately blunt. Two refinements a typesetter would recognise,
neither implemented:

- **Orphans**, the other half of the pair — a lone first line of a paragraph
  stranded at the foot of a column — do not arise, because the reader scrolls
  continuously and has no columns to strand anything at.
- **Measuring instead of guessing.** A real typesetter binds only when the
  last line *would* hold one word, which needs the laid-out line. `bind`
  applies the remedy unconditionally once the paragraph is long enough, which
  costs a slightly shorter last line in the cases where it was not needed.
