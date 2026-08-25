#!/usr/bin/env bash
set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_shared.sh"
prepare_project

section "Check Dart formatting"
dart format --output=none --set-exit-if-changed "${DART_PATHS[@]}"

section "Check Swift formatting"
if has_swift_format; then
  swift format lint --strict --parallel "${SWIFT_PATHS[@]}"
else
  note "Skipped: swift-format is not available on this platform."
fi

section "Check shell syntax"
for script in "$TOOLS_DIR"/*.sh; do
  bash -n "$script"
done

section "Prepare pinned web assets"
"$TOOLS_DIR/prepare-web-assets.sh"

section "Analyze Dart and Flutter"
flutter analyze

section "Run all tests"
flutter test

section "Build web release"
flutter build web --release

case "$(uname -s)" in
  Darwin)
    section "Build macOS release"
    flutter build macos --release
    section "Audit macOS bundle"
    "$TOOLS_DIR/validate-macos-bundle.sh" \
      "build/macos/Build/Products/Release/Visual MD.app"
    ;;
  MINGW* | MSYS* | CYGWIN*)
    section "Build Windows release"
    flutter build windows --release
    ;;
  *)
    section "Build native desktop release"
    note "Skipped: this host has no configured Visual MD desktop target."
    ;;
esac

printf '\nValidation passed.\n'
