#!/usr/bin/env bash
set -Eeuo pipefail

distribution=0
if [[ "${1:-}" == '--distribution' ]]; then
  distribution=1
  shift
fi

readonly APP_BUNDLE="${1:?Pass the built macOS application bundle}"
readonly MERMAN_DYLIB="$APP_BUNDLE/Contents/Frameworks/libmerman_ffi.dylib"
readonly PORTABLE_NAME='@rpath/libmerman_ffi.dylib'
readonly INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
readonly PRIVACY_MANIFEST="$APP_BUNDLE/Contents/Resources/PrivacyInfo.xcprivacy"
readonly PLIST_BUDDY='/usr/libexec/PlistBuddy'

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

plist_value() {
  "$PLIST_BUDDY" -c "Print :$2" "$1" 2>/dev/null
}

require_plist_value() {
  local plist="$1"
  local key="$2"
  local expected="$3"
  local actual
  actual="$(plist_value "$plist" "$key")" ||
    fail "Missing $key in $plist"
  [[ "$actual" == "$expected" ]] ||
    fail "$key in $plist is '$actual'; expected '$expected'"
}

if [[ ! -f "$MERMAN_DYLIB" ]]; then
  printf 'Missing embedded Merman library: %s\n' "$MERMAN_DYLIB" >&2
  exit 1
fi

failure=0
while IFS= read -r -d '' binary; do
  file "$binary" | grep -q 'Mach-O' || continue
  while IFS= read -r dependency; do
    case "$dependency" in
      /*/libmerman_ffi.dylib)
        printf 'Non-portable Merman dependency in %s: %s\n' \
          "$binary" "$dependency" >&2
        failure=1
        ;;
    esac
  done < <(otool -L "$binary" | awk 'NR > 1 {print $1}')
done < <(find "$APP_BUNDLE/Contents" -type f -print0)

identity_count=0
while IFS= read -r identity; do
  ((identity_count += 1))
  if [[ "$identity" != "$PORTABLE_NAME" ]]; then
    printf 'Non-portable Merman install name: %s\n' "$identity" >&2
    failure=1
  fi
done < <(
  otool -D "$MERMAN_DYLIB" |
    awk '/libmerman_ffi[.]dylib$/ {sub(/^[[:space:]]*/, ""); print}'
)

if ((identity_count == 0)); then
  printf 'Merman dylib declares no install name: %s\n' "$MERMAN_DYLIB" >&2
  failure=1
fi

((failure == 0)) || exit 1
codesign --verify --deep --strict "$APP_BUNDLE"

require_plist_value \
  "$INFO_PLIST" CFBundleIdentifier 'com.visualmd.visualmd'
require_plist_value \
  "$INFO_PLIST" LSApplicationCategoryType 'public.app-category.productivity'
require_plist_value \
  "$INFO_PLIST" ITSAppUsesNonExemptEncryption 'false'

[[ -f "$PRIVACY_MANIFEST" ]] ||
  fail "Missing application privacy manifest: $PRIVACY_MANIFEST"
plutil -lint "$PRIVACY_MANIFEST" >/dev/null
require_plist_value "$PRIVACY_MANIFEST" NSPrivacyTracking 'false'
require_plist_value \
  "$PRIVACY_MANIFEST" \
  'NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPIType' \
  'NSPrivacyAccessedAPICategoryFileTimestamp'

readonly ENTITLEMENTS="$(mktemp -t visual-md-entitlements).plist"
trap 'rm -f "$ENTITLEMENTS"' EXIT
codesign --display --entitlements :- "$APP_BUNDLE" \
  >"$ENTITLEMENTS" 2>/dev/null
plutil -lint "$ENTITLEMENTS" >/dev/null

require_plist_value \
  "$ENTITLEMENTS" 'com.apple.security.app-sandbox' 'true'
require_plist_value \
  "$ENTITLEMENTS" 'com.apple.security.files.bookmarks.app-scope' 'true'
require_plist_value \
  "$ENTITLEMENTS" 'com.apple.security.files.user-selected.read-write' 'true'
require_plist_value \
  "$ENTITLEMENTS" 'com.apple.security.network.client' 'true'

for forbidden in \
  'com.apple.security.cs.allow-jit' \
  'com.apple.security.get-task-allow' \
  'com.apple.security.network.server'; do
  if plist_value "$ENTITLEMENTS" "$forbidden" >/dev/null; then
    fail "Release app carries forbidden entitlement: $forbidden"
  fi
done

readonly SIGNATURE_DETAILS="$(codesign --display --verbose=4 "$APP_BUNDLE" 2>&1)"
[[ "$SIGNATURE_DETAILS" == *'runtime'* ]] ||
  fail 'Release app does not enable the hardened runtime'

if ((distribution == 1)); then
  [[ "$SIGNATURE_DETAILS" != *'Signature=adhoc'* ]] ||
    fail 'Distribution app is still ad-hoc signed'
  [[ "$SIGNATURE_DETAILS" == *'Authority=Developer ID Application:'* ]] ||
    fail 'Distribution app is not signed with Developer ID Application'
  [[ "$SIGNATURE_DETAILS" != *'TeamIdentifier=not set'* ]] ||
    fail 'Distribution app has no signing team'
  [[ "$SIGNATURE_DETAILS" == *'Timestamp='* ]] ||
    fail 'Distribution signature has no secure timestamp'
  xcrun stapler validate "$APP_BUNDLE"
  spctl --assess --verbose=4 --type execute "$APP_BUNDLE"
fi
