#!/usr/bin/env bash
set -Eeuo pipefail

readonly TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ARCHIVE="${1:?Pass the macOS xcarchive}"
readonly APP_BUNDLE="$ARCHIVE/Products/Applications/Visual MD.app"
readonly MERMAN_DYLIB="$APP_BUNDLE/Contents/Frameworks/libmerman_ffi.dylib"
readonly MERMAN_DSYM="$ARCHIVE/dSYMs/libmerman_ffi.dylib.dSYM"
readonly ARCHIVE_INFO="$ARCHIVE/Info.plist"

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

uuid_set() {
  dwarfdump --uuid "$1" |
    awk '{print $2, $3}' |
    sort
}

[[ -d "$ARCHIVE" ]] || fail "Archive does not exist: $ARCHIVE"
[[ -d "$APP_BUNDLE" ]] || fail "Archive has no Visual MD app: $ARCHIVE"
[[ -f "$ARCHIVE_INFO" ]] || fail "Archive has no Info.plist: $ARCHIVE"
[[ -f "$MERMAN_DYLIB" ]] || fail "Archive has no Merman dylib: $ARCHIVE"
[[ -d "$MERMAN_DSYM" ]] || fail "Archive has no Merman dSYM: $ARCHIVE"

readonly ARCHIVE_TEAM="$(
  /usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:Team' \
    "$ARCHIVE_INFO" 2>/dev/null || true
)"
readonly SIGNING_IDENTITY="$(
  /usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:SigningIdentity' \
    "$ARCHIVE_INFO" 2>/dev/null || true
)"
[[ -n "$ARCHIVE_TEAM" ]] || fail 'Archive is not assigned to an Apple team'
[[ -n "$SIGNING_IDENTITY" && "$SIGNING_IDENTITY" != '-' ]] ||
  fail 'Archive has no Apple signing identity'

"$TOOLS_DIR/validate-macos-bundle.sh" "$APP_BUNDLE"

readonly DYLIB_UUIDS="$(uuid_set "$MERMAN_DYLIB")"
readonly DSYM_UUIDS="$(uuid_set "$MERMAN_DSYM")"
[[ -n "$DYLIB_UUIDS" ]] || fail 'Merman dylib declares no Mach-O UUIDs'
[[ "$DSYM_UUIDS" == "$DYLIB_UUIDS" ]] || {
  printf 'error: Merman dSYM UUIDs do not match the embedded dylib\n' >&2
  printf 'dylib:\n%s\n' "$DYLIB_UUIDS" >&2
  printf 'dSYM:\n%s\n' "$DSYM_UUIDS" >&2
  exit 1
}

printf 'Archive validation passed (team %s).\n' "$ARCHIVE_TEAM"
