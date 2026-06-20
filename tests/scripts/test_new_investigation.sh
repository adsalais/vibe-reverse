#!/usr/bin/env sh
set -eu
SCRIPT="skills/reverse-engineering/new_investigation.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

# Run inside a temp dir with a fixed date for determinism.
DIR="$(cd "$TMP" && sh "$OLDPWD/$SCRIPT" demo 2026-01-01)" || fail "non-zero exit"
[ "$DIR" = "docs/reverse/2026-01-01-demo" ] || fail "unexpected path: $DIR"
BASE="$TMP/docs/reverse/2026-01-01-demo"
[ -f "$BASE/00-target.md" ] || fail "00-target.md missing"
[ -f "$BASE/findings.md" ] || fail "findings.md missing"
[ -d "$BASE/artifacts" ] || fail "artifacts/ missing"
[ -d "$BASE/scripts" ] || fail "scripts/ missing"
grep -qi "authorization" "$BASE/00-target.md" || fail "00-target.md missing authorization prompt"

echo "PASS: test_new_investigation.sh"
