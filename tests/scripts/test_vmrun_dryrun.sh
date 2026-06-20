#!/usr/bin/env sh
set -eu
SCRIPT="deploy/vmrun.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
printf '\177ELF' > "$TMP/sample"          # dummy "sample"
fail() { echo "FAIL: $1" >&2; exit 1; }
# dry-run prints the QEMU command without booting; guest files need not exist.
OUT=$(VIBE_GUEST_DIR="$TMP/guest" sh "$SCRIPT" "$TMP/sample" "$TMP/out" --mode trace --dry-run) \
  || fail "vmrun --dry-run exited non-zero"
printf '%s' "$OUT" | grep -q 'qemu-system-x86_64' || fail "no qemu command"
printf '%s' "$OUT" | grep -q -- '-nic none'        || fail "network not disabled"
printf '%s' "$OUT" | grep -q -- '-snapshot'        || fail "not throwaway (-snapshot)"
printf '%s' "$OUT" | grep -q 'mode=trace'          || fail "mode not passed"
echo "PASS: test_vmrun_dryrun.sh"
