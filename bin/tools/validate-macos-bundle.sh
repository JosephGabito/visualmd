#!/usr/bin/env bash
set -Eeuo pipefail

readonly APP_BUNDLE="${1:?Pass the built macOS application bundle}"
readonly MERMAN_DYLIB="$APP_BUNDLE/Contents/Frameworks/libmerman_ffi.dylib"
readonly PORTABLE_NAME='@rpath/libmerman_ffi.dylib'

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
