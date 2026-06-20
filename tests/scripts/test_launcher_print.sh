#!/usr/bin/env sh
set -eu
L="deploy/vibe-reverse"
fail() { echo "FAIL: $1" >&2; exit 1; }
OUT=$(VIBE_CONFIG=/tmp/none sh "$L" --print) || fail "--print exited non-zero"
for s in "docker run" "--rm" "HOST_UID" "HOST_GID" "/work" "OPENCODE_CONFIG=/cfg/opencode.json" "vibe-reverse:latest"; do
  printf '%s' "$OUT" | grep -q -- "$s" || fail "missing: $s"
done
# the remap model replaces --user and the /state tmpfs
printf '%s' "$OUT" | grep -q -- "--user"  && fail "launcher still passes --user"
printf '%s' "$OUT" | grep -q -- "--tmpfs" && fail "launcher still mounts a tmpfs"

# tui.json is mapped into opencode's config dir only when present in the config dir
if printf '%s' "$OUT" | grep -q "tui.json"; then fail "tui.json mapped when absent"; fi
TCFG="$(mktemp -d)"; trap 'rm -rf "$TCFG"' EXIT
echo '{}' > "$TCFG/tui.json"
OUT2=$(VIBE_CONFIG="$TCFG" sh "$L" --print) || fail "--print (tui.json) exited non-zero"
printf '%s' "$OUT2" | grep -q -- "$TCFG/tui.json:/home/vibe/.config/opencode/tui.json:ro" \
  || fail "tui.json not mapped to /home/vibe config dir"

echo "PASS: test_launcher_print.sh"
