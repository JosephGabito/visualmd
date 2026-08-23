# Hanging Punctuation

## Purpose and boundary

A table of which punctuation marks hang outside the reading column, and how
far. It owns the *rule*; it owns no measurement, no widget and no layout.

A quotation mark is mostly white space. Left inside the column it carves a
notch out of the left edge, and the first line of the paragraph appears to
start further right than every line beneath it — the eye reads the edge from
the text, not from the ink of a mark
(`lib/presentation/theme/hanging_punctuation.dart:1-11`).

Like everything in this ring it is plain data: no Flutter, no measurement, no
opinion about where a paragraph sits. Measuring the mark's advance and placing
it belongs to [Paragraph](../05-api/15-paragraph.md), one ring out.

## Present wiring

`HangingPunctuation` is a namespace, never instantiated
(`lib/presentation/theme/hanging_punctuation.dart:12`). It holds one table
mapping a character to the fraction of its own advance that hangs
(`lib/presentation/theme/hanging_punctuation.dart:13-27`):

| Mark | Hangs | Why |
|------|-------|-----|
| `“` `‘` `«` `„` `‚` | 1.0 | Opening quotes in the shapes a typographer sets them: almost entirely white space, so the whole advance goes into the margin (`lib/presentation/theme/hanging_punctuation.dart:14-19`) |
| `"` `'` | 1.0 | The straight forms, in case a document reaches the page unset (`lib/presentation/theme/hanging_punctuation.dart:20-22`) |
| `—` `–` | 0.5 | A dash opening a line of dialogue carries real ink; hanging it whole would pull the line visibly out of place (`lib/presentation/theme/hanging_punctuation.dart:23-26`) |
| everything else | 0 | `fractionFor` falls back to zero (`lib/presentation/theme/hanging_punctuation.dart:31`) |

The fractions are of the mark's *own* advance rather than a fixed distance,
so a wide face and a narrow one both come out aligned. What is being aligned
is the look of the edge, not the arithmetic
(`lib/presentation/theme/hanging_punctuation.dart:9-11`).

## Inputs and outputs

| In | Type | Meaning |
|----|------|---------|
| `character` | `String` | One character, normally the first of a paragraph |

| Out | Type | Meaning |
|-----|------|---------|
| `fractionFor` | `double` | How much of that character's advance hangs; 0 when it does not (`lib/presentation/theme/hanging_punctuation.dart:29-31`) |
| `hangs` | `bool` | Whether it hangs at all (`lib/presentation/theme/hanging_punctuation.dart:33`) |

## Events

None today, and none expected: a lookup table has nothing to announce. If a
theme is ever allowed to extend the table, it would arrive as data on the
theme contract rather than as an event.

## Lifecycle

Compile-time constants. The table is `static const` and lives as long as the
program (`lib/presentation/theme/hanging_punctuation.dart:13`).

## Failure and recovery

There is nothing to fail. An unknown character — a letter, a bracket, an
emoji — returns 0 and simply does not hang
(`lib/presentation/theme/hanging_punctuation.dart:31`). A caller that passes a
multi-character string gets 0 too, because no key is longer than one
character, so the worst outcome is a mark that stays in the column.

`test/presentation/paragraph_setting_test.dart:217-223` holds the table to its
values: quotes whole, a dash halfway, an ordinary letter and an opening
bracket not at all.

## Transition

Two things this table cannot yet express, both worth stating plainly:

- **Only a paragraph's opening mark hangs.** A line further down that happens
  to begin with a quotation mark stays in the column, because hanging it needs
  per-line control that Flutter's text engine does not expose. See
  [Paragraph](../05-api/15-paragraph.md).
- **Nothing hangs at the right edge.** In justified setting, commas, full
  stops and hyphens hang off the right margin as well. The reader sets flush
  left and ragged right (see [Reading Scale](07-reading-scale.md)), so the
  right edge is soft by design and there is nothing to align against.
