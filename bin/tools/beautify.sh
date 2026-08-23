#!/usr/bin/env bash
set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_shared.sh"
prepare_project

section "Format Dart"
dart format "${DART_PATHS[@]}"

section "Format Swift"
if has_swift_format; then
  swift format --in-place --parallel "${SWIFT_PATHS[@]}"
else
  note "Skipped: swift-format is not available on this platform."
fi

printf '\nBeauty pass complete.\n'
