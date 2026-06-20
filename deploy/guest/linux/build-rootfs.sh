#!/bin/sh
# build-rootfs.sh <kernel-version> <out-ext4> — build a minimal guest rootfs image.
# Uses mmdebstrap (no root/mount needed) + mke2fs -d (populate without mounting).
set -eu
KVER="$1"; OUT="$2"
ROOT="$(mktemp -d)"
# Suite MUST match the host image (python:3.12-slim-trixie). fakechroot LD_PRELOADs
# a lib built against the host glibc into the target chroot; a cross-suite target
# (e.g. bookworm on a trixie host) makes dpkg/ld-linux crash during install.
mmdebstrap --mode=fakechroot --variant=minbase \
  --include=strace,ltrace,gdb,gdbserver,busybox,libc6,kmod \
  trixie "$ROOT" >/dev/null
# kernel modules for 9p (copied from the builder's installed image)
mkdir -p "$ROOT/lib/modules"
cp -a "/lib/modules/$KVER" "$ROOT/lib/modules/" 2>/dev/null || true
# our init
cp /tmp/detonate "$ROOT/detonate"; chmod +x "$ROOT/detonate"
# fakechroot bakes the build-root path into some symlinks (e.g. the dynamic loader
# ld-linux), which then dangle at boot -> no dynamic binaries. Strip the $ROOT prefix.
find "$ROOT" -type l | while read -r l; do
  t=$(readlink "$l"); case "$t" in "$ROOT"/*) ln -sf "${t#$ROOT}" "$l";; esac
done
# pack to ext4 WITHOUT mounting
SIZE=$(du -sm "$ROOT" | cut -f1); SIZE=$((SIZE + 128))
mke2fs -q -t ext4 -d "$ROOT" "$OUT" "${SIZE}M"
rm -rf "$ROOT"
echo "built $OUT (${SIZE}M)"
