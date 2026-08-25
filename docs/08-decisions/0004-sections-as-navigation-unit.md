# 0004 — Sections as the Navigation Unit

Status: Accepted · 2026-08-22 · **superseded in part, 2026-08-22**

> **Superseded in part.** The reader now parses documents into its own content
> model and renders them with its own renderer, so the page is no longer cut
> into sections and re-parsed per section. The *navigation* decision stands:
> heading anchors are still the scroll targets, still derived in the domain,
> still matched by `GlobalKey`. What changed is where the keys come from: the
> document renderer registers one per heading as it builds
> (`lib/api/render/document_view.dart`) instead of the pane keying one
> `MarkdownBody` per `Section`. `DocumentOutline.sections` still exists and is
> still tested, but nothing renders from it. See
> [Document View](../05-api/12-document-view.md) and
> [Document Content](../01-domain/05-document-content.md).

## Context

The outline panel must scroll the page to a heading precisely, and highlight
the heading currently being read. A single markdown widget rendering the
whole document exposes no heading positions, so neither is possible without
reaching into the renderer's internals. The alternative — using a markdown
widget library with its own table-of-contents controller — would duplicate
the domain's notion of a heading and tie the domain to a rendering package.

## Decision

The domain cuts each document into **sections** at every heading. A
`Section` is a heading (or none, for leading prose) plus the markdown up to
the next heading, heading line included. The page renders each section as its
own `MarkdownBody` inside a `KeyedSubtree` whose key is the heading's anchor.
Outline clicks call `Scrollable.ensureVisible` on that key; the active heading
is found by measuring the keyed render boxes against a line 120 px below the
top of the page.

Because reference-style link definitions may live in a different section than
the links that use them, the original section renderer required every
definition to be copied into every section. *(No longer needed: the document is
parsed once, whole. The obsolete copying was removed; sections are again exact
source slices.)*

## Consequences

- The outline and the page are driven by the same `DocumentOutline`; there is
  exactly one parser, and it is in the domain with tests.
- Scroll targets are exact to the pixel and need no knowledge of the markdown
  renderer.
- Markdown constructs that span a heading boundary are cut. In practice a
  heading ends any paragraph, list or quote, so only uncommon cases
  (a heading inside an open HTML block) are affected. Fenced code blocks are
  safe: the parser never treats a `#` inside a fence as a heading.
- Each section was a separate widget; very long documents with hundreds of
  headings built hundreds of them. The renderer that replaced this builds one
  widget per *block* instead, which is a finer grain but no longer re-parses
  anything. A lazy list remains the remedy for very long documents.
- Text selection across sections works because the column sits inside one
  `SelectionArea`.

## Evidence

- `Section` and its contract: `lib/domain/reading/section.dart`.
- Cutting exact source slices at boundaries: `lib/domain/reading/document_outline.dart`.
- Fenced code blocks are skipped while scanning for headings: `lib/domain/reading/document_outline.dart`.
- The pane owns the anchor keys and clears them per document: `lib/api/widgets/reading_pane.dart`, `lib/api/widgets/reading_pane.dart`.
- Scroll to an anchor: `lib/api/widgets/reading_pane.dart`.
- Heading keys registered as blocks build: `lib/api/render/document_view.dart`.
- Tests: `test/domain/document_outline_test.dart` (exact sections, reference-linked headings and fences).
- Written description: [Reading Pane](../05-api/04-reading-pane.md), [Document Outline](../01-domain/03-document-outline.md).
