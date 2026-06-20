#!/usr/bin/env sh
set -eu
SCRIPT="skills/re-static/ghidra_decompile.sh"
sh tests/fixtures/build.sh >/dev/null 2>&1 || true
TARGET="tests/fixtures/crackme1"
[ -f "$TARGET" ] || { echo "SKIP: no compiler to build fixture"; exit 0; }
OUT="$(mktemp -d)"; trap 'rm -rf "$OUT"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

REPORT="$(sh "$SCRIPT" "$TARGET" "$OUT")" || fail "ghidra_decompile.sh exited non-zero"
printf '%s' "$REPORT" | grep -Eqi 'engine: (ghidra|radare2|objdump)' || fail "no engine line"
ARTLINE=$(printf '%s' "$REPORT" | sed -n 's/^output: //p' | head -1)
[ -n "$ARTLINE" ] || fail "no output: line"
[ -s "$ARTLINE" ] || fail "output artifact empty/missing: $ARTLINE"

echo "PASS: test_static.sh"
