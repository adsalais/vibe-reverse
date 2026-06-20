#!/usr/bin/env sh
set -eu
fail() { echo "FAIL: $1" >&2; exit 1; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
M=$(sh skills/re-deobfuscate/deob_map.sh "$TMP/inv") || fail "nonzero"
[ -f "$M" ] || fail "map not created"
grep -qi "peel" "$M"   || fail "map missing peel guidance"
grep -qi "status" "$M" || fail "map missing status column"
echo "PASS: test_deob_map.sh"
