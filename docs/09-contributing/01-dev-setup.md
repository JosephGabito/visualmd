# Development Setup

Visual MD uses Flutter's stable channel and declares its Dart constraint in
`pubspec.yaml`. A web checkout needs Flutter, Chrome, and Node with npm to
reproduce the pinned Mermaid WASM runtime. Native builds also need the
toolchain for their host platform.

## Install and check Flutter

Follow Flutter's installation guide for your operating system, then confirm
that the selected SDK satisfies the project constraint:

```sh
flutter --version
flutter doctor
flutter pub get
```

On Apple Silicon with Flutter installed through Homebrew, the command is
usually `/opt/homebrew/bin/flutter`. If a separate Homebrew Dart shadows the
one bundled with Flutter, put Flutter's `bin` directory first on `PATH` so the
analyzer, formatter, and build all use the same SDK.

`flutter doctor` may report tools for targets Visual MD does not build. The
relevant checks are:

- **Chrome** for the web target.
- **Xcode** for macOS. The full application, not only Command Line Tools, is
  required; see [macOS](../06-platforms/02-macos.md).
- **Visual Studio with Desktop development with C++** for Windows. The target
  is built and verified with Visual Studio 2022; see
  [Windows](../06-platforms/03-windows.md).

Android and iOS are not current project targets.

## Run the reader

```sh
bin/tools/prepare-web-assets.sh
flutter run -d chrome     # web, opens Chrome
flutter run -d macos      # native macOS window; requires Xcode
flutter run -d windows    # native Windows window; requires Visual Studio
```

The preparation command runs `npm ci` from `web/package-lock.json` only when
the generated runtime is absent or stale, then copies that exact package into
the ignored `web/vendor/` tree consumed by the browser bridge
(`bin/tools/prepare-web-assets.sh`). The complete validation command performs
the same preparation automatically.

Use a target reported by `flutter devices`. While a run is active:

| Key | Does |
|-----|------|
| `r` | Hot reload — keeps state and applies most Dart/widget changes |
| `R` | Hot restart — restarts the Dart application |
| `q` | Quit |

Hot reload does not apply native-host changes. Changes to composition-root
wiring can also require a hot restart. After editing `macos/`, `windows/`, or
another native host, stop and start the run again.

## Use the project commands

```sh
bin/tools/beautify.sh       # format authored Dart and Swift source
bin/tools/validate.sh       # check formatting, analysis, tests, docs, builds
bin/tools/beautipass.sh     # format, then validate everything
```

`validate.sh` is the local and CI entry point. It checks Dart and authored
Swift formatting without rewriting files, validates the shell scripts, runs
the analyzer and test suite, checks documentation, then builds the web release
and the native release supported by the host. A host without Swift reports
that the Swift check was skipped; the macOS CI job exercises it.

`beautify.sh` formats authored Dart and Swift only. Generated Flutter host
files stay owned by their generators, while Markdown is checked through the
documentation suite.

Build outputs are written to:

- `build/web` for the web release;
- `build/macos/Build/Products/Release/` for macOS;
- `build/windows/x64/runner/Release/` for Windows.

## Useful web launch options

The web target accepts launch options that make repeatable visual review easy:
`?open=sample`, `?theme=<id>`, `?paragraphs=indented`, and
`?serif=Alegreya|Literata`. [Web](../06-platforms/01-web.md) explains which values are
available and which choices are temporary.

Continue with [Testing and Validation](02-testing-and-validation.md) for the
focused suites and the complete pre-review check.
