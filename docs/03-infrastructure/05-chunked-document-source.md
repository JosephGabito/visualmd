# Chunked Document Source

## Purpose and boundary

`ChunkedDocumentSource` retains source which is still arriving without copying
the accepted prefix for every append. It owns exact chunk storage and bounded
range materialization. It does not define a transport, parse Markdown, decide
when a block is committed, or publish UI state
(`lib/infrastructure/streaming/chunked_document_source.dart`).

The component lives in infrastructure because storage is a technical policy.
The domain continues to describe document blocks, while the application will
later describe the ordered stream protocol which supplies the chunks.

## Present wiring

The buffer is currently the first isolated kernel of the streaming path. It is
not used for completed local files, whose scanners still return one complete
string. Keeping that path unchanged makes this component measurable before a
transport or parser session depends on it.

The next adapter will retain one buffer per active generated document and ask
only for its provisional parser window. Full materialization remains explicit
for final equivalence checks and compatibility consumers.

## Inputs and outputs

`append(String)` accepts the exact characters delivered by an upstream decoder.
It records the new chunk and its starting Dart string offset. `range(start,
end)` returns only `[start, end)`, locating the first chunk by binary search and
visiting only chunks which intersect that range. `tailFrom(start)` names the
common parser operation, while `materialize()` deliberately exposes the cost
of joining the complete source.

Offsets use Dart's native UTF-16 string units, so they are directly valid for
`substring`. A future byte transport must decode UTF-8 across chunk boundaries
before appending; byte offsets and string offsets are different contracts.

## Events

None. This is a synchronous storage object and does not publish a stream. A
transport coordinator will own ordering, batching, and notification.

## Lifecycle

One instance belongs to one stream generation. Appending is amortized `O(1)`
with respect to previously accepted source. Reading a window costs
`O(log c + k + w)`, where `c` is total chunk count, `k` is the number of chunks
intersecting the window, and `w` is the output size. Completing or canceling a
generation releases the buffer with its owning session.

## Failure and recovery

Empty appends are ignored. Invalid ranges throw `RangeError` before source is
read. The buffer does not silently clamp, reorder, deduplicate, or decode input;
those rules require stream identity and sequence information outside this
component.

`test/infrastructure/chunked_document_source_test.dart` verifies exact source,
cross-chunk windows, Unicode offsets, and range failures against a ten-thousand
chunk prefix.

## Transition

The next slice is a Markdown parser session with a committed prefix and a
provisional tail. It will consume bounded ranges from this component and emit
the revisioned mutations already understood by `DocumentContent`
(`lib/domain/reading/content/document_content.dart`). The completed-file parser
remains the final-equivalence oracle until the incremental path proves every
supported Markdown shape.
