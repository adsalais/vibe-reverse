#!/usr/bin/env sh
set -eu
fail() { echo "FAIL: $1" >&2; exit 1; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
# a file whose strings include classic anti-debug / anti-VM markers
printf 'ptrace IsDebuggerPresent TracerPid VBoxGuest vmware\n' > "$TMP/s.bin"
OUT=$(sh skills/re-antianalysis/antianalysis_scan.sh "$TMP/s.bin" "$TMP/inv") || fail "nonzero"
printf '%s' "$OUT" | grep -q '\[FLAG\] anti-debug' || fail "anti-debug not flagged"
printf '%s' "$OUT" | grep -q '\[FLAG\] anti-VM'    || fail "anti-VM not flagged"
[ -f "$TMP/inv/artifacts/antianalysis/antianalysis.txt" ] || fail "report missing"
# a clean file flags nothing in those categories
printf 'hello world\n' > "$TMP/clean.bin"
OUT2=$(sh skills/re-antianalysis/antianalysis_scan.sh "$TMP/clean.bin" "$TMP/inv2")
printf '%s' "$OUT2" | grep -q '\[FLAG\] anti-debug' && fail "false positive on clean file" || true
echo "PASS: test_antianalysis_scan.sh"
