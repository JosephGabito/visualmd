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
