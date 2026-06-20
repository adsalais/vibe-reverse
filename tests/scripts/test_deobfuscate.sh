#!/usr/bin/env sh
set -eu
sh tests/fixtures/build.sh >/dev/null 2>&1 || true
BIN="tests/fixtures/crackme1"
[ -f "$BIN" ] || { echo "SKIP: no compiler"; exit 0; }
OUT=$(sh skills/re-deobfuscate/unpack.sh "$BIN" "$(mktemp -d)") || { echo "FAIL: nonzero" >&2; exit 1; }
printf '%s' "$OUT" | grep -qi "no known packer" || { echo "FAIL: expected no-packer msg, got: $OUT" >&2; exit 1; }
echo "PASS: test_deobfuscate.sh"
