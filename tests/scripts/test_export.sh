#!/usr/bin/env sh
set -eu
fail() { echo "FAIL: $1" >&2; exit 1; }
D="$(mktemp -d)"; trap 'rm -rf "$D"' EXIT
# VIBE_SKIP_SAVE makes export write a placeholder instead of a multi-GB docker save.
VIBE_SKIP_SAVE=1 sh deploy/export.sh "$D" >/dev/null 2>&1 || fail "export.sh failed"
B="$D/vibe-reverse-bundle.tgz"
[ -f "$B" ] || fail "bundle not produced"
LIST=$(tar tzf "$B")
for f in vibe-reverse-bundle/install.sh vibe-reverse-bundle/vibe-reverse vibe-reverse-bundle/config/opencode.json vibe-reverse-bundle/SHA256SUMS; do
  printf '%s' "$LIST" | grep -q "$f" || fail "bundle missing $f"
done
echo "PASS: test_export.sh"
