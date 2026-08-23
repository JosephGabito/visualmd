#!/usr/bin/env bash
set -Eeuo pipefail

readonly TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$TOOLS_DIR/beautify.sh"
exec "$TOOLS_DIR/validate.sh"
