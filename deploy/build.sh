#!/usr/bin/env sh
# build.sh — build vibe-reverse:latest on an internet-connected host.
# Run from the repo root. Place your internal CA at deploy/ca.pem (optional).
set -eu

# Always run from the repo root (this script lives in deploy/), so the docker
# build context "." and the deploy/* , skills/, requirements/ paths resolve
# no matter where build.sh is invoked from.
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

# pinned versions (override via env)
OPENCODE_VERSION="${OPENCODE_VERSION:-1.17.8}"   # must be >= 1.0.154 for the offline env vars
# Ghidra: confirm the current asset URL + sha at the releases page:
#   https://github.com/NationalSecurityAgency/ghidra/releases
GHIDRA_URL="${GHIDRA_URL:-https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.1.2_build/ghidra_12.1.2_PUBLIC_20260605.zip}"
GHIDRA_SHA256="b62e81a0390618466c019c60d8c2f796ced2509c4c1aea4a37644a77272cf99d"
GHIDRA_SHA256="${GHIDRA_SHA256:?set GHIDRA_SHA256 to the sha256 of the Ghidra zip (see releases page)}"
# radare2 + upx are not in Debian bookworm — fetch official releases:
RADARE2_DEB_URL="${RADARE2_DEB_URL:-https://github.com/radareorg/radare2/releases/download/6.1.6/radare2_6.1.6_amd64.deb}"
UPX_URL="${UPX_URL:-https://github.com/upx/upx/releases/download/v5.2.0/upx-5.2.0-amd64_linux.tar.xz}"
# capa + FLOSS standalone Linux releases (set the matching sha256 from the release page):
CAPA_URL="${CAPA_URL:-https://github.com/mandiant/capa/releases/download/v9.4.0/capa-v9.4.0-linux.zip}"
CAPA_SHA256="07800a1d20a21eb18fc98716e2ae81b668e0c9a04defd588c8aa17ea3d3281e4"
CAPA_SHA256="${CAPA_SHA256:?set CAPA_SHA256 to the sha256 of the capa linux zip}"
FLOSS_URL="${FLOSS_URL:-https://github.com/mandiant/flare-floss/releases/download/v3.1.1/floss-v3.1.1-linux.zip}"
# FLOSS release publishes no sha256 — fetched over HTTPS without an integrity pin.
# Detect-It-Easy .deb for Debian (diec CLI):
DIE_DEB_URL="${DIE_DEB_URL:-https://github.com/horsicq/DIE-engine/releases/download/3.21/die_3.21_Debian_13_amd64.deb}"
DIE_DEB_SHA256="47ed1299fe0fcdf3549e4077573db9651c228144b22a372729eb014548332fcd"
DIE_DEB_SHA256="${DIE_DEB_SHA256:?set DIE_DEB_SHA256 to the sha256 of the DIE .deb}"
# Java for Ghidra 12.x (JDK 21) now comes from Debian trixie apt (openjdk-21-jdk)
# inside the Dockerfile — no staged JDK tarball, so no JDK build args are needed.

# CA placeholder so the build never breaks without an internal CA
if [ ! -f deploy/ca.pem ]; then
  echo "no deploy/ca.pem — building WITHOUT an internal CA"
  : > deploy/ca.pem
fi

docker build -t vibe-reverse:latest -f deploy/Dockerfile \
  --build-arg OPENCODE_VERSION="$OPENCODE_VERSION" \
  --build-arg GHIDRA_URL="$GHIDRA_URL" \
  --build-arg GHIDRA_SHA256="$GHIDRA_SHA256" \
  --build-arg RADARE2_DEB_URL="$RADARE2_DEB_URL" \
  --build-arg UPX_URL="$UPX_URL" \
  --build-arg CAPA_URL="$CAPA_URL" \
  --build-arg CAPA_SHA256="$CAPA_SHA256" \
  --build-arg FLOSS_URL="$FLOSS_URL" \
  --build-arg DIE_DEB_URL="$DIE_DEB_URL" \
  --build-arg DIE_DEB_SHA256="$DIE_DEB_SHA256" \
  .

echo "built vibe-reverse:latest"
docker image inspect vibe-reverse:latest --format 'size: {{.Size}} bytes'
