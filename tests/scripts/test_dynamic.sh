#!/usr/bin/env sh
set -eu
sh tests/fixtures/build.sh >/dev/null 2>&1 || true
BIN="tests/fixtures/crackme1"
[ -f "$BIN" ] || { echo "SKIP: no compiler"; exit 0; }
command -v strace >/dev/null 2>&1 || command -v gdb >/dev/null 2>&1 || { echo "SKIP: no tracer"; exit 0; }
OUTD="$(mktemp -d)"; trap 'rm -rf "$OUTD"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

# crackme1 is a SAFE, in-house fixture — running it under a tracer is fine.
REP=$(sh skills/re-dynamic/dynamic_trace.sh "$BIN" "$OUTD" AB BC) || fail "nonzero exit"
T=$(printf '%s' "$REP" | sed -n 's/^trace: //p' | head -1)
[ -s "$T" ] || fail "empty/missing trace: $T"
grep -Eq 'execve|write|openat|exit|main' "$T" || fail "no recognizable trace content"

echo "PASS: test_dynamic.sh"
