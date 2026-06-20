#!/usr/bin/env sh
# vmrun.sh — detonate a sample in a throwaway, NO-NETWORK QEMU microVM.
# Usage: vmrun.sh <sample> <out-dir> [--mode trace|gdb-script|gdb-server]
#                 [--timeout SEC] [--gdb-script FILE] [--dry-run]
set -eu
GUEST_DIR="${VIBE_GUEST_DIR:-/opt/vibe-reverse/guest}"
KERNEL="$GUEST_DIR/vmlinuz"; INITRD="$GUEST_DIR/initrd.img"; ROOTFS="$GUEST_DIR/rootfs.ext4"
SAMPLE="${1:?usage: vmrun.sh <sample> <out-dir> [opts]}"
OUT="${2:?usage: vmrun.sh <sample> <out-dir> [opts]}"; shift 2
MODE=trace; TIMEOUT=60; GDBSCRIPT=""; DRY=0
while [ $# -gt 0 ]; do case "$1" in
  --mode) MODE="$2"; shift 2;; --timeout) TIMEOUT="$2"; shift 2;;
  --gdb-script) GDBSCRIPT="$2"; shift 2;; --dry-run) DRY=1; shift;;
  *) echo "unknown arg: $1" >&2; exit 2;; esac; done
[ -f "$SAMPLE" ] || { echo "no such sample: $SAMPLE" >&2; exit 1; }

ACCEL=tcg; [ -w /dev/kvm ] && ACCEL=kvm
APPEND="console=ttyS0 root=/dev/vda rw init=/detonate panic=-1 mode=$MODE timeout=$TIMEOUT"

if [ "$DRY" = 1 ]; then
  echo "accel=$ACCEL"
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
mkdir -p "$WORK/in" "$WORK/out"
cp "$SAMPLE" "$WORK/in/sample"
[ -n "$GDBSCRIPT" ] && cp "$GDBSCRIPT" "$WORK/in/cmds.gdb"

# Invoke QEMU directly so multi-word -append keeps its quoting. NO network device.
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
