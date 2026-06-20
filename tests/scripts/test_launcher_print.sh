#!/usr/bin/env sh
set -eu
L="deploy/vibe-reverse"
fail() { echo "FAIL: $1" >&2; exit 1; }
OUT=$(VIBE_CONFIG=/tmp/none sh "$L" --print) || fail "--print exited non-zero"
for s in "docker run" "--rm" "--user" "/work" "OPENCODE_CONFIG=/cfg/opencode.json" "--tmpfs /state" "vibe-reverse:latest"; do
  printf '%s' "$OUT" | grep -q -- "$s" || fail "missing: $s"
done
echo "PASS: test_launcher_print.sh"
