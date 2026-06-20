#!/usr/bin/env sh
set -eu
REPO="$PWD"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }
echo dummy > "$TMP/sample.bin"
cd "$TMP"
SESS=$(sh "$REPO/skills/reverse-engineering/new_session.sh" sample.bin demo 2026-01-01_00-00-00)
printf '# 01 triage plan\n' > "$SESS/sample.bin/01-triage-plan.md"

OUT=$(sh "$REPO/skills/reverse-engineering/session_status.sh" "$SESS") || fail "nonzero"
printf '%s' "$OUT" | grep -q "session: $SESS" || fail "missing session header"
printf '%s' "$OUT" | grep -q "sample.bin"     || fail "missing binary name"
printf '%s' "$OUT" | grep -q "01-triage-plan.md" || fail "missing latest plan"

# default (no arg) picks the newest session in CWD
OUT2=$(sh "$REPO/skills/reverse-engineering/session_status.sh") || fail "default nonzero"
printf '%s' "$OUT2" | grep -q "sample.bin" || fail "default did not find session"

echo "PASS: test_session_status.sh"
