#!/usr/bin/env sh
# export.sh [DIST_DIR] — build one sneakernet bundle for the air-gapped network.
# Set VIBE_SKIP_SAVE=1 to skip the (large) docker save (used by tests).
set -eu
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
IMAGE="${VIBE_IMAGE:-vibe-reverse:latest}"
DIST="${1:-dist}"
STAGE="$DIST/vibe-reverse-bundle"
rm -rf "$STAGE"; mkdir -p "$STAGE/config"

if [ "${VIBE_SKIP_SAVE:-0}" = 1 ]; then
  echo "(VIBE_SKIP_SAVE) placeholder image tar" > "$STAGE/vibe-reverse-image.tar.gz"
else
  echo "saving image (large; minutes)..."; docker save "$IMAGE" | gzip > "$STAGE/vibe-reverse-image.tar.gz"
fi

cp "$HERE/install.sh" "$HERE/vibe-reverse" "$STAGE/"
cp "$HERE/config/opencode.json" "$HERE/config/auth.json.sample" "$HERE/config/tui.json" "$STAGE/config/"
[ -f "$HERE/README.md" ] && cp "$HERE/README.md" "$STAGE/"
[ -f "$HERE/windows-guest.md" ] && cp "$HERE/windows-guest.md" "$STAGE/"
( cd "$STAGE" && find . -type f ! -name SHA256SUMS | sort | xargs sha256sum > SHA256SUMS )
( cd "$DIST" && tar czf vibe-reverse-bundle.tgz vibe-reverse-bundle )
echo "bundle: $DIST/vibe-reverse-bundle.tgz"
