# Writing Docs

These documents are part of the product: they are written to be read in Visual
MD and checked alongside the code. Automated checks keep the library navigable;
the conventions below keep its explanations useful to people.

## Template

Component documents follow
[the component document template](../00-foundation/05-component-document-template.md):
the same sections in the same order, so a reader always knows where to look.
Index documents (`README.md` in each folder), decisions and roadmap items are
free-form but still start with a single `#` title.

## Checking for drift

`test/docs/docs_library_test.dart` proves that a cited range *exists*. A
refactor can leave that range present while changing what it says, so a valid
line number is necessary but not sufficient evidence.

`tool/check_citations.py` is the second pass. For each paragraph it collects
the symbols the prose names in backticks, and asks whether any cited span
still mentions one of them:

```sh
python3 tool/check_citations.py
```

It reports missing files, out-of-range spans, and paragraphs whose citations
no longer mention anything they discuss. It is a warning tool, not a gate: a
paragraph may legitimately cite a caller rather than a declaration, so read
every hit before changing anything. Run it after any refactor that moves code
between files or rings.

## Citations

Every claim about code carries evidence: an inline-code path with a line or
line range.

```
`lib/application/use_cases/add_folder.dart:40-53`
`lib/main.dart:21`
`macos/Runner/MainFlutterWindow.swift:14-24`
```

- Paths start with `lib/`, `test/`, `macos/`, `web/`, `windows/` or `docs/`
  and are relative to the repository root; `pubspec.yaml` and `README.md` at
  the root are also citable.
- Get line numbers from the file, never from memory:

  ```sh
  cat -n lib/application/use_cases/add_folder.dart
  grep -n "Future<AddedFolder> execute" lib/application/use_cases/add_folder.dart
  ```

- Cite the smallest range that supports the claim.
- When code moves, regenerate the citations in every document that names the
  file — `grep -rn "add_folder.dart" docs/` finds them.

Component documents — everything outside `00-foundation/`, `08-decisions/`
and the READMEs — must contain at least one citation.

## Links

- Relative, with the `.md` suffix: `[Shelving rules](../01-domain/02-shelving-rules.md)`.
- Anchors are GitHub-style: lowercase, punctuation dropped, spaces to hyphens.
  `## Rule of three` is `#rule-of-three`. Duplicate headings get `-1`, `-2`.
- Link only to anchors you have confirmed exist in the target document.
- Cross-shelf links (`../`) are welcome; they exercise the reader's link
  resolution.

## Structure

- One `#` H1 per document, first line. It is the title the shelf shows.
- Every folder has a `README.md` that indexes its documents; it opens first on
  that shelf.
- Number documents for reading order (`01-`, `02-`); decisions use four
  digits (`0001-`). Folder names sort naturally, so `10-` follows `9-`.
- Keep documents between roughly 40 and 140 lines. Split rather than scroll.
- No placeholder text. Write what is true today or leave the section out.

## Understanding docs-test feedback

`test/docs/docs_library_test.dart` opens `docs/` through the real scanner
and builder, then reports by reason:

| Reason printed | What to fix |
|----------------|-------------|
| `folders without a README` | Add a `README.md` to the listed folder (`test/docs/docs_library_test.dart:51-60`). |
| a list of untitled paths | Give the document a `#` H1 or a `title:` in front matter (`test/docs/docs_library_test.dart:62-65`). |
| a list of dirty paths | Remove placeholder words (`test/docs/docs_library_test.dart:67-72`). |
| `broken links` | Each entry says `(no document)` or `(no anchor)` (`test/docs/docs_library_test.dart:74-92`). |
| `stale citations` | Each entry says `(missing file)` or `(file has N lines)` (`test/docs/docs_library_test.dart:94-115`). |
| `component documents without any file:line evidence` | Add a citation (`test/docs/docs_library_test.dart:117-124`). |

Citations inside fenced code blocks are checked too; links inside fences are
not. Run just this suite while writing:

```sh
flutter test test/docs
```

## Review the result in Visual MD

Open the `docs/` folder in Visual MD. If the shelf order, the titles, or the
outline makes the guide harder to follow, adjust the document before review.
The app itself is the most representative preview. See
[Testing and Validation](02-testing-and-validation.md).
