#!/usr/bin/env sh
set -eu
fail() { echo "FAIL: $1" >&2; exit 1; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
echo dummy > "$TMP/sample.bin"
OUT=$(sh skills/re-static/static_scan.sh "$TMP/sample.bin" "$TMP/inv") || fail "nonzero"
[ -d "$TMP/inv/artifacts/capa" ]  || fail "capa artifact dir missing"
[ -d "$TMP/inv/artifacts/floss" ] || fail "floss artifact dir missing"
printf '%s' "$OUT" | grep -qi capa  || fail "no capa status line"
printf '%s' "$OUT" | grep -qi floss || fail "no floss status line"
echo "PASS: test_static_scan.sh"
