#!/usr/bin/env sh
# Behavioral test for preflight.sh — host-independent assertions.
set -eu
SCRIPT="skills/re-preflight/preflight.sh"
OUT="$(mktemp -d)"; trap 'rm -rf "$OUT"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

OUTPUT="$(sh "$SCRIPT" "$OUT")" || fail "preflight.sh exited non-zero"

# Table prints every registry tool, regardless of what's installed:
for t in file radare2 angr z3 binwalk; do
  printf '%s' "$OUTPUT" | grep -q "$t" || fail "table missing row: $t"
done
printf '%s' "$OUTPUT" | grep -qi "TOOL" || fail "table header missing"

# Artifacts created:
[ -f "$OUT/install.sh" ] || fail "install.sh not created"
[ -x "$OUT/install.sh" ] || fail "install.sh not executable"
head -n1 "$OUT/install.sh" | grep -q '^#!' || fail "install.sh missing shebang"
[ -f "$OUT/Dockerfile.snippet" ] || fail "Dockerfile.snippet not created"
grep -qi "ghidra" "$OUT/Dockerfile.snippet" || fail "Dockerfile.snippet missing Ghidra recipe"

# Generated Docker RUN lines must be well-formed (space after flag/keyword):
! grep -Eq 'apt-get install -y[^ ]' "$OUT/Dockerfile.snippet" || fail "apt line malformed (no space after -y)"
! grep -Eq 'pip install[^ ]' "$OUT/Dockerfile.snippet" || fail "pip line malformed (no space after install)"

echo "PASS: test_preflight.sh"
