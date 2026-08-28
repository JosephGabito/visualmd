#!/usr/bin/env bash
set -Eeuo pipefail

# Merman 0.7.0's universal dylib was published with one absolute install name
# per architecture. The linker copies those CI paths into every consumer. Do
# this after CocoaPods embeds its products so the application remains portable
# without modifying the pub cache or the signed package source.
readonly APP_BUNDLE="${TARGET_BUILD_DIR:?}/${WRAPPER_NAME:?}"
readonly MERMAN_DYLIB="$APP_BUNDLE/Contents/Frameworks/libmerman_ffi.dylib"
readonly MERMAN_FRAMEWORK="$APP_BUNDLE/Contents/Frameworks/merman.framework"
readonly PORTABLE_NAME='@rpath/libmerman_ffi.dylib'

generate_merman_dsym() {
  [[ "${ACTION:-}" == 'install' ]] || return 0
  [[ "${DEBUG_INFORMATION_FORMAT:-}" == *'dwarf-with-dsym'* ]] || return 0
  [[ -n "${DWARF_DSYM_FOLDER_PATH:-}" ]] || return 0

  # Merman publishes this dylib without a companion dSYM. App Store Connect
  # requires a matching DWARF object for every Mach-O UUID even when the
  # upstream binary contains only its public symbol table. Generate that
  # companion from the repaired universal binary while Xcode is archiving;
  # Xcode then collects it beside the target's other dSYMs.
  local output="$DWARF_DSYM_FOLDER_PATH/libmerman_ffi.dylib.dSYM"
  local diagnostics
  if ! diagnostics="$(dsymutil "$MERMAN_DYLIB" -o "$output" 2>&1)"; then
    printf '%s\n' "$diagnostics" >&2
    return 1
  fi
  [[ -f "$output/Contents/Resources/DWARF/libmerman_ffi.dylib" ]]
}

rewrite_merman_references() {
  local binary="$1"
  [[ -f "$binary" ]] || return 0
  file "$binary" | grep -q 'Mach-O' || return 0

  local dependencies=()
  local dependency
  while IFS= read -r dependency; do
    case "$dependency" in
      /*/libmerman_ffi.dylib)
        dependencies+=("$dependency")
        ;;
    esac
  done < <(otool -L "$binary" | awk 'NR > 1 {print $1}' | sort -u)

  ((${#dependencies[@]} > 0)) || return 0
  codesign --remove-signature "$binary" 2>/dev/null || true
  for dependency in "${dependencies[@]}"; do
    install_name_tool -change "$dependency" "$PORTABLE_NAME" "$binary"
  done
}

while IFS= read -r -d '' binary; do
  rewrite_merman_references "$binary"
done < <(find "$APP_BUNDLE/Contents/MacOS" -maxdepth 1 -type f -print0)

if [[ -d "$MERMAN_FRAMEWORK" ]]; then
  codesign --remove-signature "$MERMAN_FRAMEWORK" 2>/dev/null || true
fi
rewrite_merman_references "$MERMAN_FRAMEWORK/Versions/A/merman"

if [[ -f "$MERMAN_DYLIB" ]]; then
  codesign --remove-signature "$MERMAN_DYLIB" 2>/dev/null || true
  install_name_tool -id "$PORTABLE_NAME" "$MERMAN_DYLIB"
  generate_merman_dsym
fi

# CocoaPods signed the two embedded products before this phase. Repairing their
# Mach-O headers invalidates those signatures, so restore them with the same
# identity Xcode selected for the application. Xcode signs the application
# itself after all build phases have completed.
if [[ "${CODE_SIGNING_ALLOWED:-NO}" == 'YES' ]]; then
  readonly SIGNING_IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:--}"
  if [[ -f "$MERMAN_DYLIB" ]]; then
    codesign --force --sign "$SIGNING_IDENTITY" \
      --preserve-metadata=identifier,entitlements,flags,runtime \
      "$MERMAN_DYLIB"
  fi
  if [[ -d "$MERMAN_FRAMEWORK" ]]; then
    codesign --force --sign "$SIGNING_IDENTITY" \
      --preserve-metadata=identifier,entitlements,flags,runtime \
      "$MERMAN_FRAMEWORK"
  fi
fi
