# Domain

The domain is Visual MD's shared understanding of a reading library. It knows
what a document is, how folders become a shelf, what headings make an outline,
and how a saved workspace describes a reading session. It does not know whether
those documents came from a browser, a macOS folder, or an in-memory test.

That separation is practical: the product's behaviour can be read and tested as
plain Dart, while platform code remains free to focus on moving bytes. Code in
`lib/domain/` therefore uses no Flutter, packages, or I/O.

## The model in four parts

- `lib/domain/library/` turns discovered markdown into ordered roots, folders,
  and documents.
- `lib/domain/reading/` describes the content shown on the page and the outline
  a reader uses to move through it.
- `lib/domain/search/` represents a literal query and the visible-text matches
  found for it.
- `lib/domain/workspace/` captures the sources, order, theme, and active
  document needed to restore a reading room.

## Documents on this shelf

| Document | What you will learn |
|----------|---------------------|
| [Library Aggregate](01-library-aggregate.md) | The roots, folders, documents, and identities that form a library. |
| [Shelving Rules](02-shelving-rules.md) | How scanned files become a pruned, naturally sorted tree. |
| [Document Outline](03-document-outline.md) | How headings become the sections a reader navigates. |
| [Invariants](04-invariants.md) | The behaviours the model keeps consistent and where each is tested. |
| [Document Content](05-document-content.md) | The blocks and inline runs used to preserve an author's markdown. |
| [Search Results](06-search-results.md) | How literal matches are represented and grouped by document. |
| [Document Source Identity](07-document-source-identity.md) | How one physical markdown remains the same document across different scans. |
| [Workspace Aggregate](08-workspace-aggregate.md) | The durable description of source membership, order, theme, and reading intent. |

## How the domain participates in a feature

The [Application](../02-application/README.md) ring asks the domain to make
decisions. For example, `AddFolder` receives scanned files from a port, asks
`LibraryBuilder` to shelve them, then saves the resulting `Library`. It does not
need to know how the scan happened, and the domain does not need to know who
requested it.

Markdown tokenisation follows the same shape. An adapter behind the
[Document Parser Port](../02-application/04-document-parser-port.md) performs
the technical parsing, then returns the domain's `DocumentContent`. The model
defines the result; infrastructure supplies it. [Dependency Direction](../00-foundation/03-dependency-direction.md)
shows the complete relationship.

For a guided tour, begin with [Library Aggregate](01-library-aggregate.md), then
follow [Shelving Rules](02-shelving-rules.md). Continue with
[Document Outline](03-document-outline.md) and [Document Content](05-document-content.md)
when you are ready to move from the shelf into a single document. The shared
terms used throughout are collected in [Ubiquitous Language](../00-foundation/02-ubiquitous-language.md).
