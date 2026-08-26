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

`test/docs/docs_library_test.dart` proves that every referenced source file
exists and rejects exact line citations. A file reference survives unrelated
insertions and formatting; a line range does not. Review still decides whether
the owning file supports the prose, because that is a semantic judgement.

## Source references

Every claim about code carries evidence: the smallest owning source file,
written as an inline-code path.

```
`lib/application/use_cases/add_folder.dart`
`lib/main.dart`
`macos/Runner/MainFlutterWindow.swift`
```

- Paths start with `lib/`, `test/`, `macos/`, `web/`, `windows/` or `docs/`
  and are relative to the repository root; `pubspec.yaml` and `README.md` at
  the root are also citable.
- Do not append line numbers. Moving unrelated code must not stale the prose.
- When ownership moves to another file, update every document that names the
  old one — `rg "add_folder.dart" docs/` finds them.

Component documents — everything outside `00-foundation/`, `08-decisions/`
and the READMEs — must contain at least one source reference.

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
- Aim for roughly 40 to 140 lines. A longer document is justified when it keeps
  one contract or research trail intact; split it when the parts can stand on
  their own rather than merely to satisfy a count.
- No placeholder text. Write what is true today or leave the section out.

## Understanding docs-test feedback

`test/docs/docs_library_test.dart` opens `docs/` through the real scanner
and builder, then reports by reason:

| Reason printed | What to fix |
|----------------|-------------|
| `folders without a README` | Add a `README.md` to the listed folder (`test/docs/docs_library_test.dart`). |
| a list of untitled paths | Give the document a `#` H1 or a `title:` in front matter (`test/docs/docs_library_test.dart`). |
| a list of dirty paths | Remove placeholder words (`test/docs/docs_library_test.dart`). |
| `broken links` | Each entry says `(no document)` or `(no anchor)` (`test/docs/docs_library_test.dart`). |
| `missing source files` | Update or remove the file reference (`test/docs/docs_library_test.dart`). |
| `exact line citations` | Remove the line suffix and keep the owning file (`test/docs/docs_library_test.dart`). |
| `component documents without source evidence` | Add an owning source file (`test/docs/docs_library_test.dart`). |

Source references inside fenced code blocks are checked too; links inside
fences are not. Run just this suite while writing:

```sh
flutter test test/docs
```

## Review the result in Visual MD

Open the `docs/` folder in Visual MD. If the shelf order, the titles, or the
outline makes the guide harder to follow, adjust the document before review.
The app itself is the most representative preview. See
[Testing and Validation](02-testing-and-validation.md).
