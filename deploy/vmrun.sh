#!/usr/bin/env sh
# vmrun.sh — detonate a sample in a throwaway, NO-NETWORK QEMU microVM.
# Usage: vmrun.sh <sample> <out-dir> [--guest linux|windows]
#                 [--mode trace|gdb-script|gdb-server] [--timeout SEC]
#                 [--gdb-script FILE] [--dry-run]
set -eu
GUEST_DIR="${VIBE_GUEST_DIR:-/opt/vibe-reverse/guest}"
KERNEL="$GUEST_DIR/vmlinuz"; INITRD="$GUEST_DIR/initrd.img"; ROOTFS="$GUEST_DIR/rootfs.ext4"
WIN_IMG="${VIBE_WIN_IMAGE:-/guests/windows.qcow2}"
SAMPLE="${1:?usage: vmrun.sh <sample> <out-dir> [opts]}"
OUT="${2:?usage: vmrun.sh <sample> <out-dir> [opts]}"; shift 2
GUEST=linux; MODE=trace; TIMEOUT=60; GDBSCRIPT=""; DRY=0
while [ $# -gt 0 ]; do case "$1" in
  --guest) GUEST="$2"; shift 2;; --mode) MODE="$2"; shift 2;;
  --timeout) TIMEOUT="$2"; shift 2;; --gdb-script) GDBSCRIPT="$2"; shift 2;;
  --dry-run) DRY=1; shift;; *) echo "unknown arg: $1" >&2; exit 2;; esac; done
[ -f "$SAMPLE" ] || { echo "no such sample: $SAMPLE" >&2; exit 1; }
ACCEL=tcg; [ -w /dev/kvm ] && ACCEL=kvm

if [ "$GUEST" = windows ]; then
  if [ "$DRY" = 1 ]; then
    echo "accel=$ACCEL guest=windows image=$WIN_IMG"
    echo "qemu-system-x86_64 -accel $ACCEL -m 4096 -smp 2 -display none -no-reboot -snapshot" \
         "-drive file=$WIN_IMG,format=qcow2,if=ide" \
         "-drive file=<results.img>,format=raw,if=ide" \
         "-cdrom <sample.iso> -nic none"
    [ -f "$WIN_IMG" ] || echo "note: $WIN_IMG not present — supply a prepared Windows qcow2 (see windows-guest.md)"
    exit 0
  fi
  [ -f "$WIN_IMG" ] || { echo "Windows guest image not found: $WIN_IMG (see windows-guest.md)" >&2; exit 1; }
  WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
  mkdir -p "$WORK/in" "$WORK/out"; cp "$SAMPLE" "$WORK/in/sample.exe"
  ISO="$WORK/sample.iso"; RES="$WORK/results.img"
  ( command -v xorriso >/dev/null 2>&1 && xorriso -as mkisofs -quiet -V VIBESAMPLE -o "$ISO" "$WORK/in" ) \
    || genisoimage -quiet -V VIBESAMPLE -o "$ISO" "$WORK/in"
  truncate -s 256M "$RES"; mkfs.vfat -n VIBEOUT "$RES" >/dev/null 2>&1
  HARD=$(( TIMEOUT + 300 ))
  timeout "$HARD" qemu-system-x86_64 -accel "$ACCEL" -m 4096 -smp 2 -display none -no-reboot -snapshot \
    -drive file="$WIN_IMG",format=qcow2,if=ide \
    -drive file="$RES",format=raw,if=ide \
    -cdrom "$ISO" -nic none >/dev/null 2>&1 || true
  ART="$OUT/artifacts/dynamic"; mkdir -p "$ART"
  mcopy -s -n -i "$RES" ::/ "$ART/" 2>/dev/null || true
  echo "accel: $ACCEL (windows)"; echo "results: $ART"; ls -1 "$ART" 2>/dev/null || true
  exit 0
fi

# ---- linux guest ----
APPEND="console=ttyS0 root=/dev/vda rw init=/detonate panic=-1 mode=$MODE timeout=$TIMEOUT"
if [ "$DRY" = 1 ]; then
  echo "accel=$ACCEL guest=linux"
  echo "qemu-system-x86_64 -accel $ACCEL -m 1024 -smp 1 -nographic -no-reboot -snapshot" \
       "-kernel $KERNEL -initrd $INITRD -append '$APPEND'" \
       "-drive file=$ROOTFS,if=virtio,format=raw" \
       "-fsdev local,id=in,path=<in>,readonly=on -device virtio-9p-pci,fsdev=in,mount_tag=invibe" \
       "-fsdev local,id=out,path=<out> -device virtio-9p-pci,fsdev=out,mount_tag=outvibe" \
       "-nic none"
  exit 0
fi
[ -f "$KERNEL" ] && [ -f "$ROOTFS" ] || { echo "guest not found in $GUEST_DIR" >&2; exit 1; }
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/in" "$WORK/out"; cp "$SAMPLE" "$WORK/in/sample"
[ -n "$GDBSCRIPT" ] && cp "$GDBSCRIPT" "$WORK/in/cmds.gdb"
HARD=$(( TIMEOUT + 120 ))
timeout "$HARD" qemu-system-x86_64 -accel "$ACCEL" -m 1024 -smp 1 -nographic -no-reboot -snapshot \
  -kernel "$KERNEL" -initrd "$INITRD" -append "$APPEND" \
  -drive file="$ROOTFS",if=virtio,format=raw \
  -fsdev local,id=in,path="$WORK/in",security_model=none,readonly=on \
  -device virtio-9p-pci,fsdev=in,mount_tag=invibe \
  -fsdev local,id=out,path="$WORK/out",security_model=none \
  -device virtio-9p-pci,fsdev=out,mount_tag=outvibe \
  -nic none >/dev/null 2>&1 || true
ART="$OUT/artifacts/dynamic"; mkdir -p "$ART"; cp -a "$WORK/out/." "$ART/" 2>/dev/null || true
echo "accel: $ACCEL"; echo "results: $ART"; ls -1 "$ART" 2>/dev/null || true
