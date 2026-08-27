# Reader performance benchmark

The native reader benchmark measures the real `ReadingPane` after parsing, so
its numbers describe widget construction, layout, paint, scrolling, and a
one-block document update. It runs the same viewport with 100, 1,000, and 5,000
paragraphs. A viewport-bounded renderer should mount approximately the same
number of paragraph widgets at every size. The update journey uses a real
revisioned tail mutation and records how many source records the navigation and
render indexes visit; an ordinary append must report exactly one at every
corpus size. A second append is injected while a ballistic scroll is active;
that journey records its own frame distribution and must continue moving the
reader while still visiting only the new record.

The same run then exercises the generated-document pipeline rather than a
hand-built mutation. It commits 5,000 Markdown paragraphs through
`GeneratedDocumentStreamSession`, starts a ballistic scroll, and publishes 60
small deltas forming 20 more paragraphs. This covers transport ordering,
coalescing policy, chunked source retention, incremental Markdown parsing,
persistent document revisions, outline projection, navigation and render
indexing, viewport geometry, layout, and paint. Every published revision must
parse fewer than 256 source characters, visit exactly one outline, navigation,
and render record, keep fewer than 40 paragraphs mounted, and allow the
ballistic scroll to continue.

Run it on macOS in profile mode:

```sh
export PATH="/opt/homebrew/bin:$PATH"
flutter drive --profile \
  --dart-define=INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=false \
  --driver=test_driver/performance_test_driver.dart \
  --target=integration_test/reading_performance_test.dart \
  -d macos
```

The machine-readable result is written to
`build/integration_response_data.json`. Compare scaling across the three rows,
not a single absolute duration: thermal state and concurrent desktop work can
move wall-clock timings, while an implementation that grows with total block
count remains visible in the curve.

The first eager-versus-sliver measurement is retained in
`benchmark/results/2026-08-28-viewport-sliver.md`.
The first revisioned-append measurement is retained in
`benchmark/results/2026-08-28-revisioned-append.md`.
The first end-to-end generated Markdown stream measurement is retained in
`benchmark/results/2026-08-28-generated-stream.md`.

The atomic-block benchmark isolates one fenced code block at 1,000, 10,000,
and 50,000 lines. It establishes the pre-virtualization slope separately from
the top-level sliver benchmark:

```sh
flutter drive --profile \
  --dart-define=INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=false \
  --driver=test_driver/performance_test_driver.dart \
  --target=integration_test/atomic_block_performance_test.dart \
  -d macos
```

The first atomic-code scaling measurement is retained in
`benchmark/results/2026-08-28-atomic-code-block.md`.
The first viewport-windowed comparison is retained in
`benchmark/results/2026-08-28-windowed-code-block.md`.
