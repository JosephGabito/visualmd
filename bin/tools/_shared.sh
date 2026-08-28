#!/usr/bin/env bash

# Shared paths and output for the project commands. Every entrypoint resolves
# the repository from its own location, so contributors and CI may invoke it
# from any working directory.
readonly TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$TOOLS_DIR/../.." && pwd)"

readonly QUIET_VIEWPORT_ROOT="$PROJECT_ROOT/packages/quiet_viewport"
readonly DART_PATHS=(
  lib
  test
  packages/quiet_viewport/lib
  packages/quiet_viewport/test
)
readonly SWIFT_PATHS=(
  macos/Runner/AppDelegate.swift
  macos/Runner/MainFlutterWindow.swift
  macos/RunnerTests/RunnerTests.swift
)

section() {
  printf '\n==> %s\n' "$1"
}
note() {
  printf '    %s\n' "$1"
}

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "Required tool not found: $1"
}

has_swift_format() {
  command -v swift >/dev/null 2>&1 && swift format --version >/dev/null 2>&1
}

prepare_project() {
  cd "$PROJECT_ROOT"
  require_tool dart
  require_tool flutter
  require_tool python3
}

resolve_dependencies() {
  section "Resolve project dependencies"
  flutter pub get
  (
    cd "$QUIET_VIEWPORT_ROOT"
    dart pub get
  )
}
