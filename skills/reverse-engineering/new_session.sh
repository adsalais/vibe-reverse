#!/usr/bin/env sh
# new_session.sh — create a vibe-reverse session in the CWD and register the first
# binary. Prints the session dir (relative). NEVER executes the target.
# Usage: new_session.sh <binary-path> [case-slug] [datetime]
set -eu
BIN="${1:?usage: new_session.sh <binary-path> [case-slug] [datetime]}"
SLUG="${2:-case}"
DT="${3:-$(date +%Y-%m-%d_%H-%M-%S)}"
SESS="vibe-reverse-${DT}"
mkdir -p "$SESS"

if [ ! -f "$SESS/index.md" ]; then
  cat > "$SESS/index.md" <<EOF
# Session — ${SLUG} — ${DT}

## Executive summary
<fill at wrap-up: case verdict + the most important findings across all binaries>

## Binaries
EOF
fi

sh "$(dirname "$0")/add_binary.sh" "$SESS" "$BIN" >/dev/null
echo "$SESS"
