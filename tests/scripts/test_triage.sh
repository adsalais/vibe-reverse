#!/usr/bin/env sh
set -eu
SCRIPT="skills/re-triage/triage.sh"
sh tests/fixtures/build.sh >/dev/null 2>&1 || true
TARGET="tests/fixtures/crackme1"
[ -f "$TARGET" ] || { echo "SKIP: no compiler to build fixture"; exit 0; }
OUT="$(mktemp -d)"; trap 'rm -rf "$OUT"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

REPORT="$(sh "$SCRIPT" "$TARGET" "$OUT")" || fail "triage.sh exited non-zero"
printf '%s' "$REPORT" | grep -qi "ELF"     || fail "did not detect ELF type"
printf '%s' "$REPORT" | grep -qi "entropy" || fail "no entropy line"
printf '%s' "$REPORT" | grep -qi "sha256"  || fail "no sha256 line"
printf '%s' "$REPORT" | grep -qi "family"  || fail "no family line"
[ -f "$OUT/artifacts/triage.txt" ]         || fail "triage.txt artifact not written"

echo "PASS: test_triage.sh"
