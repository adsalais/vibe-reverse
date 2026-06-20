#!/usr/bin/env sh
# install.sh — install the vibe-reverse harness on this (air-gapped) host.
# Run from the extracted bundle directory.
set -eu
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
CFG="$HOME/.config/vibe-reverse"
BIN="$HOME/.local/bin"
IMG_TAR="$HERE/vibe-reverse-image.tar.gz"

# 1. load the image (if present in the bundle)
if [ -f "$IMG_TAR" ]; then
  echo "loading image (large)..."; gunzip -c "$IMG_TAR" | docker load
else
  echo "note: $IMG_TAR not found — skipping 'docker load' (load the image separately)" >&2
fi

# 2. seed config + auth (NEVER clobber an existing file)
mkdir -p "$CFG/guests"
[ -f "$CFG/opencode.json" ] || cp "$HERE/config/opencode.json" "$CFG/opencode.json"
[ -f "$CFG/tui.json" ]      || cp "$HERE/config/tui.json"      "$CFG/tui.json"
if [ ! -f "$CFG/auth.json" ]; then cp "$HERE/config/auth.json.sample" "$CFG/auth.json"; chmod 600 "$CFG/auth.json"; fi

# 3. install the launcher
mkdir -p "$BIN"
install -m 0755 "$HERE/vibe-reverse" "$BIN/vibe-reverse"

cat <<EOF

Installed.
  launcher: $BIN/vibe-reverse   (ensure $BIN is on your PATH)
  config:   $CFG/opencode.json  (set your internal LLM baseURL + model id)
  auth:     $CFG/auth.json      (set your bearer token; already chmod 600)
  tui:      $CFG/tui.json       (opencode TUI keybinds; edit to taste)
Then:  cd <case-folder> && vibe-reverse
EOF
