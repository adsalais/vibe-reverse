#!/usr/bin/env sh
# dynamic_trace.sh — trace a target's syscalls/library calls. THIS RUNS THE TARGET.
# Only use on trusted (your own) or sandboxed targets — see re-dynamic SKILL.md.
# Usage: dynamic_trace.sh <target> <output-dir> [args...]
set -eu
TARGET="${1:?usage: dynamic_trace.sh <target> <output-dir> [args...]}"
OUT="${2:?usage: dynamic_trace.sh <target> <output-dir> [args...]}"
shift 2
ART="$OUT/artifacts"; mkdir -p "$ART"
[ -f "$TARGET" ] || { echo "no such file: $TARGET" >&2; exit 1; }

if command -v strace >/dev/null 2>&1; then
  ENGINE=strace; TRACE="$ART/strace.txt"
  strace -f -o "$TRACE" "$TARGET" "$@" >/dev/null 2>&1 || true
elif command -v ltrace >/dev/null 2>&1; then
  ENGINE=ltrace; TRACE="$ART/ltrace.txt"
  ltrace -f -o "$TRACE" "$TARGET" "$@" >/dev/null 2>&1 || true
elif command -v gdb >/dev/null 2>&1; then
  ENGINE=gdb; TRACE="$ART/gdb.txt"
  gdb -batch -ex run -ex bt --args "$TARGET" "$@" > "$TRACE" 2>&1 || true
else
  echo "no tracer (strace/ltrace/gdb) on PATH — unexpected on the air-gapped image" >&2; exit 1
fi

echo "engine: $ENGINE"
echo "trace: $TRACE"
