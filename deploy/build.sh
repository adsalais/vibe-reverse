#!/usr/bin/env sh
# build.sh — build vibe-reverse:latest on an internet-connected host.
# Run from the repo root. Place your internal CA at deploy/ca.pem (optional).
set -eu

# pinned versions (override via env)
OPENCODE_VERSION="${OPENCODE_VERSION:-1.17.8}"   # must be >= 1.0.154 for the offline env vars
# Ghidra: confirm the current asset URL + sha at the releases page:
#   https://github.com/NationalSecurityAgency/ghidra/releases
GHIDRA_URL="${GHIDRA_URL:-https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.1.2_build/ghidra_12.1.2_PUBLIC_20260605.zip}"
GHIDRA_SHA256="${GHIDRA_SHA256:?set GHIDRA_SHA256 to the sha256 of the Ghidra zip (see releases page)}"
# radare2 + upx are not in Debian bookworm — fetch official releases:
RADARE2_DEB_URL="${RADARE2_DEB_URL:-https://github.com/radareorg/radare2/releases/download/6.1.6/radare2_6.1.6_amd64.deb}"
UPX_URL="${UPX_URL:-https://github.com/upx/upx/releases/download/v5.2.0/upx-5.2.0-amd64_linux.tar.xz}"

# CA placeholder so the build never breaks without an internal CA
[ -f deploy/ca.pem ] || { echo "no deploy/ca.pem — building WITHOUT an internal CA"; : > deploy/ca.pem; }

docker build -t vibe-reverse:latest -f deploy/Dockerfile \
  --build-arg OPENCODE_VERSION="$OPENCODE_VERSION" \
  --build-arg GHIDRA_URL="$GHIDRA_URL" \
  --build-arg GHIDRA_SHA256="$GHIDRA_SHA256" \
  --build-arg RADARE2_DEB_URL="$RADARE2_DEB_URL" \
  --build-arg UPX_URL="$UPX_URL" \
  .

echo "built vibe-reverse:latest"
docker image inspect vibe-reverse:latest --format 'size: {{.Size}} bytes'
