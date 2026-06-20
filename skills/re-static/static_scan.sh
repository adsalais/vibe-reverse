#!/usr/bin/env sh
# static_scan.sh — capability + string scan (capa + FLOSS). NEVER executes target.
# Tool-optional: a missing tool is reported and skipped. These can be SLOW on large
# binaries — launch per references/long-running-ops.md when needed.
# Usage: static_scan.sh <target> <out-dir>
set -eu
TARGET="${1:?usage: static_scan.sh <target> <out-dir>}"
OUT="${2:?usage: static_scan.sh <target> <out-dir>}"
ART="$OUT/artifacts"; mkdir -p "$ART/capa" "$ART/floss"
[ -f "$TARGET" ] || { echo "no such file: $TARGET" >&2; exit 1; }

if command -v capa >/dev/null 2>&1; then
  capa "$TARGET" > "$ART/capa/capa.txt" 2>/dev/null \
    || echo "(capa failed / unsupported format)" > "$ART/capa/capa.txt"
  echo "capa:  $ART/capa/capa.txt"
else
  echo "capa:  not on PATH (skipped)"
fi

if command -v floss >/dev/null 2>&1; then
  floss "$TARGET" > "$ART/floss/floss.txt" 2>/dev/null \
    || echo "(floss failed / unsupported format)" > "$ART/floss/floss.txt"
  echo "floss: $ART/floss/floss.txt"
else
  echo "floss: not on PATH (skipped)"
fi
