#!/usr/bin/env sh
set -eu
REPO="$PWD"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }
echo dummy > "$TMP/sample.bin"
cd "$TMP"

SESS=$(sh "$REPO/skills/reverse-engineering/new_session.sh" sample.bin incident-42 2026-01-01_00-00-00) \
  || fail "new_session nonzero"
[ "$SESS" = "vibe-reverse-2026-01-01_00-00-00" ] || fail "unexpected session: $SESS"
B="$SESS/sample.bin"
for f in 00-target.md findings.md STATE.md; do [ -f "$B/$f" ] || fail "$f missing"; done
for d in artifacts scripts; do [ -d "$B/$d" ] || fail "$d/ missing"; done
[ -f "$SESS/index.md" ] || fail "index.md missing"
grep -qi authorization "$B/00-target.md" || fail "00-target missing authorization"
grep -qi "executive summary" "$SESS/index.md" || fail "index.md missing exec summary"
grep -q "sample.bin" "$SESS/index.md" || fail "index.md missing binary link"

echo payload > payload.dll
PB=$(sh "$REPO/skills/reverse-engineering/add_binary.sh" "$SESS" payload.dll sample.bin) \
  || fail "add_binary nonzero"
[ "$PB" = "$SESS/payload.dll" ] || fail "unexpected payload dir: $PB"
[ -f "$SESS/payload.dll/STATE.md" ] || fail "payload STATE.md missing"
grep -q "child of sample.bin" "$SESS/index.md" || fail "index.md missing parent link"

echo "PASS: test_new_session.sh"
