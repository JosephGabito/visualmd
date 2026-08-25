#!/usr/bin/env bash
set -Eeuo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_shared.sh"

readonly WEB_ROOT="$PROJECT_ROOT/web"
readonly PACKAGE_ROOT="$WEB_ROOT/node_modules/@mermanjs/web-render"
readonly VENDOR_ROOT="$WEB_ROOT/vendor/merman-web"
readonly RENDER_ENTRY="$VENDOR_ROOT/dist/package-entries/render.js"
readonly WASM_BINARY="$VENDOR_ROOT/artifacts/wasm/merman_wasm_bg.wasm"
readonly NODE_COMMAND="${NODE_BINARY:-node}"

package_version() {
  local package_json="$1/package.json"
  [[ -f "$package_json" ]] || return 1
  "$NODE_COMMAND" -p "require('$package_json').version"
}

vendor_is_current() {
  [[ -f "$RENDER_ENTRY" && -f "$WASM_BINARY" ]] || return 1
  [[ "$(package_version "$VENDOR_ROOT")" == "$EXPECTED_VERSION" ]]
}

cd "$PROJECT_ROOT"
require_tool "$NODE_COMMAND"
require_tool npm
readonly EXPECTED_VERSION="$(
  "$NODE_COMMAND" -p \
    "require('$WEB_ROOT/package.json').dependencies['@mermanjs/web-render']"
)"

if vendor_is_current; then
  exit 0
fi

section "Install pinned Merman web runtime"
npm ci --prefix "$WEB_ROOT" --ignore-scripts --no-audit --no-fund

if [[ "$(package_version "$PACKAGE_ROOT")" != "$EXPECTED_VERSION" ]]; then
  fail "npm installed an unexpected @mermanjs/web-render version"
fi

mkdir -p "$WEB_ROOT/vendor"
readonly STAGING_DIR="$(mktemp -d "$WEB_ROOT/vendor/.merman-web.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
cp -R "$PACKAGE_ROOT/." "$STAGING_DIR/"

# Both paths are fixed children of web/vendor; replacing this generated copy
# cannot reach source files or another dependency tree.
rm -rf "$VENDOR_ROOT"
mv "$STAGING_DIR" "$VENDOR_ROOT"
trap - EXIT

vendor_is_current || fail "Merman web runtime is incomplete after installation"
