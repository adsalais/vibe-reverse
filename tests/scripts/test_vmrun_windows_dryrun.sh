#!/usr/bin/env sh
set -eu
SCRIPT="deploy/vmrun.sh"; TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
printf 'MZ' > "$TMP/sample.exe"
fail() { echo "FAIL: $1" >&2; exit 1; }
OUT=$(VIBE_WIN_IMAGE="$TMP/windows.qcow2" sh "$SCRIPT" "$TMP/sample.exe" "$TMP/out" --guest windows --dry-run) \
  || fail "windows --dry-run exited non-zero"
for s in "qemu-system-x86_64" "windows.qcow2" "-cdrom" "-nic none" "-snapshot"; do
  printf '%s' "$OUT" | grep -q -- "$s" || fail "missing: $s"
done
echo "PASS: test_vmrun_windows_dryrun.sh"
