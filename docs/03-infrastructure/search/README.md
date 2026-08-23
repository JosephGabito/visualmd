# Search Adapter

Search begins with the content a reader can see, not the Markdown punctuation
around it. The adapter uses the existing Markdown parser to obtain that text,
then performs escaped, case-insensitive literal matching with Dart's standard
matching engine.

Because neither step depends on a browser or filesystem, current-document and
library search behave the same way on web and desktop. Search receives domain
values and returns match positions and excerpts; deciding how to display or
navigate those matches remains in the application and API rings.

## On this shelf

- [LiteralDocumentSearch](01-literal-document-search.md) explains match
  semantics, excerpts, ordering, and the application port it implements.
