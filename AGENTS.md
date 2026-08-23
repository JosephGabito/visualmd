# Working on Visual MD

Visual MD is a markdown reader. You drop a folder on it and every markdown file
inside — nested folders included — is on the shelf, instantly. You pick a
document, read it on a quiet page, and move through it with an outline of its
headings. It should feel like a cozy library, not a terminal.

That is the whole product. This guide explains how to change it while preserving
the qualities that make it worth reading in.

## Three shared commitments

1. **Keep the rings intact.** Dependencies point inward, and an architecture
   test makes the boundary visible.
2. **Research typography before adjusting it.** Where a craft discipline
   exists, learn its rules, measure the actual page, and use visual judgment as
   the final check rather than the only evidence.
3. **Keep the docs true.** `docs/` is checked mechanically. When cited code
   changes, update the explanation and its citation together.

Everything below is detail on those three.

## Getting it running

Flutter lives at `/opt/homebrew/bin`; export it before anything else, or the
commands are not found:

```sh
export PATH="/opt/homebrew/bin:$PATH"

flutter run -d macos          # develop natively (needs full Xcode)
flutter run -d chrome         # develop on the web
flutter test                  # everything, including the two validators
flutter analyze               # should finish with no issues
flutter build macos           # → build/macos/Build/Products/Release/Visual MD.app
flutter build web --release   # → build/web
```

To look at a real page without a browser session, build for web, serve
`build/web`, and drive headless Chrome with `--screenshot`. Launch options make
this practical: `?open=sample`, `?theme=<id>`, `?paragraphs=indented`,
`?serif=<family>`. **Look at what you changed.** Rendering it has caught bugs
that no test suggested — clipped code blocks, hard line breaks, a code block
shrink-wrapped to its shortest line.

macOS is sandboxed. The reader's own files live at
`~/Library/Containers/com.visualmd.visualmd/Data/Library/Application Support/com.visualmd.visualmd/Visual MD/`
— `preferences.json` and a `themes/` folder with a README explaining the format.

## The rings

```
lib/
├── domain/         what a document and a library ARE          no packages at all
├── application/    use cases and the ports they need
├── presentation/   contracts a contribution is written against no packages at all
├── api/            Flutter: widgets, the renderer, the shell
├── infrastructure/ adapters implementing ports
└── main.dart       composition root — the only file that sees every ring
```

| Ring | May import |
|---|---|
| `domain` | `domain` only |
| `application` | `application`, `domain` |
| `presentation` | `presentation` only |
| `api` | `api`, `presentation`, `application`, `domain` |
| `infrastructure` | `infrastructure`, `application`, `domain` |
| `main.dart` | everything |

`domain` and `presentation` are **framework-free**: neither may import *any*
package. That is what makes a theme data rather than code, and a domain rule
testable without Flutter. Platform packages (`web`, `desktop_drop`,
`file_selector`, `window_manager`) and `dart:io` / `dart:js_interop` /
`dart:html` are infrastructure-only.

`test/architecture/dependency_rules_test.dart` parses every import under `lib/`
and produces one test per file. If you need a new capability, add a **port**
where it is needed and an **adapter** in infrastructure; do not reach across.

Read [docs/00-foundation/03-dependency-direction.md](docs/00-foundation/03-dependency-direction.md)
before your first structural change.

## Typography

**This is the most important section in this file.**

Visual MD is a reader. Someone opens it to learn something — to study, to
digest, to come away understanding more than they did. Typography is not the
decoration on that; it is the mechanism of it. A reader who loses their place on
the return sweep, or whose eye is dragged to a heading that shouted when it
should have murmured, understands less. Everything else in this app — the shelf,
the outline, the themes, the whole architecture — exists to get out of the way
of a column of text.

So the standard here is higher than "it looks good."

### Taste starts the question

Do not adjust a number only until the page looks right. Taste can identify a
problem, but it cannot establish the rule or give the next contributor a
reason they can verify.

The distinction matters. Compare:

> *760px looks about right for a column.*

and

> *At 18px Literata the mean advance is 8.78px, so 760px sets 87 characters —
> well past the 60–75 band where the eye reliably finds the start of the next
> line.*

The measured statement can be checked, challenged, and improved by the next
contributor. That kind of measurement also revealed two defects that visual
inspection alone had missed:

- Body text was rendering **7% smaller** than the interface face beside it,
  because x-height differs between faces at the same nominal size.
- The **baseline grid was counted in a unit the page never used** — the beat
  came from the nominal size while text rendered at the normalised one.

Both had survived several visual reviews because the page still appeared
plausible.

### The method

1. **Find the discipline.** Vertical rhythm, hanging punctuation, the measure,
   optical sizing — these are named things with literature. Search for it. The
   answer is rarely "it depends."
2. **Read what it actually says**, including where it contradicts your plan.
   In one earlier investigation, the legibility research argued *against* the
   proposed font swap. Recording that result was more useful than quietly
   proceeding.
3. **Measure the artefact.** Not a blog post's numbers — this font, this
   renderer, this page. The toolkit is below.
4. **Encode the rule as a named function** with the reasoning in the doc
   comment. `spaceAbove(level)`, `leadingFor(family)`, `HangingPunctuation
   .fractionFor(mark)` — a rule with a name is a rule that can be found,
   questioned and changed on purpose.
5. **Write a test that states the invariant in prose.** *"The running text
   returns on the beat after every departure"* is a test. *"gapBefore returns
   34"* is a restatement of the implementation and guards nothing.
6. **Render it and look.** Measurement proves the rule holds; only looking
   catches the thing you did not think to measure.

### What the research already established

Use these findings as the current baseline. Extend or revise them when stronger
evidence gives us a reason to.

| Finding | What it means here |
|---|---|
| Serif vs sans shows **no consistent difference** (Lund, review of 72 studies) | The family of the face is not the lever. Do not argue about it. |
| **X-height, not nominal size, governs how large text reads** | A size in this reader is a size of *letters*; `FontMetrics.sizeFor` converts. |
| Letter differentiation matters; Garamond's `e` was identified correctly a tenth as often as Verdana's | Bookish old-style faces can be *worse* for documents full of identifiers. This is why the obvious "make it feel like a book" face swap is a trap. |
| **Italic slows continuous reading; bold does not** | Both are for emphasis and headings, never for passages. It is why a blockquote is not set in italic. |
| **Capitals slow reading** | Short chrome labels only. Never inside a document. |
| Harder-to-read fonts **do not** aid retention — the disfluency effect died under a meta-analysis of 17 studies | The current evidence does not support "desirable difficulty" typography. |
| Typeface choice matters **far less than designers assume**, *provided the face is conventional and drawn for its medium* | This is the one to remember. Effort spent choosing a face is usually effort not spent on measure, leading and rhythm, which do matter. |

And from Lupton, on structure rather than legibility: an **economy of signals**
(no more than three cues per level, and emphasis needs only one); indents and
paragraph spacing are **alternatives, not companions**; never indent the opening
paragraph; quotation marks carve a notch out of the left edge unless hung.

### The systems, and where their numbers come from

Each value below has a recorded derivation and a corresponding test.

| System | Derivation |
|---|---|
| **Size** | A size of letters. `fontSize = size × 0.55 / xHeight(face)`, x-height read from the font's `OS/2` table. Alegreya's is 0.452, so an "18" renders at 21.9px; Literata's is 0.507, so 19.5px. |
| **Measure** | 66 characters, from the mean advance of the face actually in use (`ReadingMeasure`), not a fixed pixel width. A wider face gets a wider column, not a longer line. |
| **Leading** | `cap + descender + 1.26 × x-height`, per face. Only the 1.26 was chosen by reading — and it is the value that reproduces the 1.65 the reader had already settled on for Literata, which is why it is trusted elsewhere. Alegreya wants *less* leading than Literata, because Literata's ascenders are unusually tall. |
| **Vertical rhythm** | Bringhurst: the space taken by any departure from the running text comes to a whole number of body lines. Gaps are whole beats; heading boxes round up; a code block is *n+1* beats; a strut stops an inline code span pushing a line off the beat. |
| **Hierarchy** | Size, **one** weight, and tone. Tone is a distance from the running text toward ink or away from it — never a lightness, or it inverts on a dark page. The body is never dimmed: contrast is what legibility rests on. |
| **Detail** | Hanging punctuation by each mark's own advance (quotes whole, dashes half); widow binding; old-style figures in prose and lining tabular in tables; a slashed zero in code; a little extra tracking on dark grounds. |

### Choosing a face

The criteria, in order — and a face that fails the first three is not a
candidate however handsome it is:

1. **Drawn for the medium.** Long reading on screens, across rendering
   technologies.
2. **Variable**, so weight is an axis rather than a pile of static files.
3. **The figure set we rely on**: old-style (`onum`) for prose, lining and
   tabular (`lnum`, `tnum`) for tables.
4. An **optical-size axis** (`opsz`) is a real advantage — the face is then
   several designs, and text and display sizes get the cut they were drawn for.
5. Measured x-height, cap height and descender, added to `FontMetrics` **from
   the file**, never looked up.

Martel failed on 2 and 3 — static weights only, `kern` and `liga` and nothing
else — which is how a candidate gets ruled out without anyone appealing to
taste.

### The measurement toolkit

Font tables, in a scratch script — x-height, cap height, descender, and which
OpenType features exist:

```python
# OS/2: sxHeight at +86, sCapHeight at +88 (version ≥ 2); head: unitsPerEm at +18
```

Glyph and text measurement, in a test — `ReadingMeasure.advance` and
`widthOf` wrap `TextPainter` and cache by family, size and weight.

`test/typography_measure_test.dart` is a **measuring stick, not a guard**: run
it to print what the bundled faces actually do — advances, characters per line
at candidate widths, the effect of the optical-size axis. It prints; it does not
assert. Extend it when you need a number.

Rendering: build for web, serve `build/web`, and screenshot headless Chrome with
`?open=sample&theme=paper&serif=<family>&paragraphs=indented`. Comparing two
faces on the same real document at the same *letter* size is a fair comparison;
comparing specimens at the same nominal size is not.

### What past mistakes taught us

Real failures from this codebase, so you can recognise them:

- **Reaching for a new typeface when the problem was size.** The page felt
  underwhelming; the cause was a 7% x-height deficit, not the face.
- **Patching a symptom.** A heading gap was shortened because it appeared too
  large, while the actual problem was that the page had no baseline grid and
  the whole document was off the beat.
- **Adding a signal instead of removing one.** A quotation marked by a rule, a
  colour *and* italic. Three cues where one would do, and the italic hurt
  reading.
- **Believing a number that was never measured.** `softLineBreak: true` had every
  hard-wrapped document rendering its source's 80-column wrapping onto the page,
  invisible until the column narrowed enough to expose it.

The sources are recorded in
[docs/04-presentation/10-sources.md](docs/04-presentation/10-sources.md) — the
book, the research, and the checklist used as an audit — so the next person can
check the reasoning against the originals instead of taking our word for it. If
you settle something new, add it there.

## The docs are part of the build

`docs/` is an inventory of what every component is for and how it is wired,
written to be read *inside Visual MD* — drop the folder on the app. It is
guarded by two suites and one tool:

- `test/architecture/dependency_rules_test.dart` — the ring rules above.
- `test/docs/docs_library_test.dart` — opens `docs/` through the app's own
  domain code and fails on a broken link, a missing anchor, a folder without a
  README, a document without a title, a placeholder word, or a `file:line`
  citation pointing at code that is not there.
- `tool/check_citations.py` — the second pass, for what a regex cannot see: a
  citation whose range still exists but no longer *says* what the sentence
  claims. Advisory, roughly five false positives; read every hit.

```sh
flutter test test/docs                # the gate
python3 tool/check_citations.py       # after any refactor that moves code
```

Conventions when writing here: one component per document, the seven sections
from
[docs/00-foundation/05-component-document-template.md](docs/00-foundation/05-component-document-template.md)
in order, every claim cited as `` `lib/path/file.dart:12-20` ``, a README in
every folder whose link text matches each target's H1 exactly, 40–140 lines,
and no placeholders.

**Citations rot silently.** Inserting a test mid-file once shifted five
citations written minutes earlier; a ring move left one pointing at an import
block. Both stayed "valid ranges". Verify spans with `sed -n`, never with
arithmetic.

## House style

- `final class` by default; `sealed` for closed sets; `abstract interface class`
  for ports; `abstract final class` for a namespace.
- Comments explain **why**, not what. If a decision would look arbitrary to the
  next reader, the comment is the place the reasoning lives.
- Test names are sentences about behaviour: *"a heading sits closer to what it
  introduces than to what it follows"*, not *"testGapBefore"*.
- Record incomplete work in
  [docs/07-roadmap/02-backlog.md](docs/07-roadmap/02-backlog.md), with the reason
  it remains open, instead of leaving an unactionable `TODO`.
- Fonts are bundled under `assets/fonts/` with their OFL licence text, which
  ships and is registered for the licence page. If you add one, add its
  x-height, cap height and descender to `FontMetrics` — measured from the file,
  not looked up.

## Where it is going

The kernel — open a folder, shelve it, read with an outline — is meant to feel
finished and change rarely. Everything else attaches at the edge as typed hooks:
events for what happened, extension points for what to contribute, UI slots for
where to show it. It is a direction, not yet code; do not build the framework
before the plugins that need it exist. See
[docs/07-roadmap/01-plugin-architecture.md](docs/07-roadmap/01-plugin-architecture.md).

Known gaps:

- **Tables are not on the beat** — their height is content-driven. The rule
  permits the departure; it is still the one place the grid breaks.
- **No justification or hyphenation.** The remaining book signal. Flutter has
  `TextAlign.justify` but no hyphenation, and justification without it gives
  rivers; real hyphenation means Knuth–Liang patterns and verifying Flutter
  honours `U+00AD`.
- **Hanging punctuation only applies to a paragraph's opening mark**, not to
  every line that happens to begin with one — that needs per-line control the
  text engine does not expose.
- **Relative images do not resolve.**
- **Windows is scaffolded but never built** — it needs a Windows machine.
- **The macOS app is unsigned**, so it runs for whoever built it and Gatekeeper
  refuses it for anyone else.

## Before calling a change complete

```sh
bin/tools/beautipass.sh   # canonical format, every gate, web + host build
```

Then look at the change in the running app. The automated gates establish the
contracts; a visual review catches rendering problems they cannot see.
