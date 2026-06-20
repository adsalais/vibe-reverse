#!/usr/bin/env sh
set -eu
SCRIPT="skills/re-static/ghidra_decompile.sh"
fail() { echo "FAIL: $1" >&2; exit 1; }

# Guard against script/postScript name drift (the Ghidra branch can't be run on
# a host without Ghidra, so verify the referenced postScript file exists here).
PS=$(grep -o -- '-postScript [A-Za-z0-9_.]*' "$SCRIPT" | awk '{print $2}')
[ -n "$PS" ] || fail "no -postScript referenced in $SCRIPT"
[ -f "skills/re-static/$PS" ] || fail "postScript referenced but missing: skills/re-static/$PS"

sh tests/fixtures/build.sh >/dev/null 2>&1 || true
TARGET="tests/fixtures/crackme1"
[ -f "$TARGET" ] || { echo "SKIP: no compiler to build fixture (postScript guard OK)"; exit 0; }
OUT="$(mktemp -d)"; trap 'rm -rf "$OUT"' EXIT

REPORT="$(sh "$SCRIPT" "$TARGET" "$OUT")" || fail "ghidra_decompile.sh exited non-zero"
printf '%s' "$REPORT" | grep -Eqi 'engine: (ghidra|radare2|objdump)' || fail "no engine line"
ARTLINE=$(printf '%s' "$REPORT" | sed -n 's/^output: //p' | head -1)
[ -n "$ARTLINE" ] || fail "no output: line"
[ -s "$ARTLINE" ] || fail "output artifact empty/missing: $ARTLINE"

echo "PASS: test_static.sh"
