# Contributing to Visual MD

Thank you for taking an interest in Visual MD. A good contribution begins with
one reader-facing problem, follows that problem through the existing code, and
changes no more than the solution requires.

The [contributor guide](docs/09-contributing/README.md) covers setup, testing,
platform work, documentation, themes, and the project's dependency boundaries.
For the shortest app-only loop:

```sh
flutter pub get
flutter test
flutter analyze
```

Before opening a pull request, run `bin/tools/beautipass.sh` and look at any
visible change in the running application. Please explain the behavior that
changed, why it changed, and how you checked it.

By submitting a contribution, you agree that it may be distributed under the
project's [MIT License](LICENSE).
