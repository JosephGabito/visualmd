# Search Results

## Purpose and boundary

The search model names what the reader asks for and what was found: a
`SearchQuery`, each `TextMatch`, and the matches grouped with their `Document`
as a `DocumentSearchResult` (`lib/domain/search/search_result.dart`). It
contains no matching algorithm and no Flutter types. Searching is technical;
the meaning of its answer belongs to the domain.

## Present wiring

A query is a non-empty literal (`lib/domain/search/search_result.dart`). A
match is a half-open offset range in the plain text the reader sees, plus an
excerpt for result lists (`lib/domain/search/search_result.dart`). The
range convention lets rendering ask whether a match overlaps a particular
run without knowing how the match was produced (`lib/domain/search/search_result.dart`).

Results are grouped by document rather than returned as one flat list
(`lib/domain/search/search_result.dart`). That keeps library order and
document identity attached while allowing the API to flatten occurrences for
display.

## Inputs and outputs

| Type | Input | Output |
|------|-------|--------|
| `SearchQuery` | non-empty literal | text the adapter must treat literally |
| `TextMatch` | start, end, excerpt | one visible occurrence |
| `DocumentSearchResult` | document, ordered matches | one document's answer |

Offsets address `DocumentContent.text`, whose blocks are joined in source
order (`lib/domain/reading/content/document_content.dart`).

## Events

None today. Search is a question, not a change to the library, so it does not
publish a domain event.

## Lifecycle

The values are created for one query and discarded when its text or scope
changes. They do not belong to the `Library` aggregate and are never persisted.

## Failure and recovery

`SearchQuery('')` throws `ArgumentError` (`lib/domain/search/search_result.dart`).
The application avoids constructing it for an empty field. Match constructors
assert a non-negative, non-empty range (`lib/domain/search/search_result.dart`), so invalid adapter output is
reported during checked development instead of becoming an impossible
highlight range.

## Transition

Case sensitivity or whole-word options would extend `SearchQuery`; an index can
replace the adapter without changing the result model. Visible-text offsets
grouped by document remain the shared meaning used by the page and result
panel.
