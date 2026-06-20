# Air-gap Deployment — Plan 2: The microVM detonation sandbox — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax. **This plan is empirical bring-up** — booting a custom guest will take iteration; treat the "expected output" as the target and debug toward it.

**Goal:** Add a throwaway, **no-network** QEMU/KVM microVM that detonates a sample inside the (networked) `vibe-reverse` container, and point `re-dynamic` at it — so malware execution is caged behind a separate kernel with no network device.

**Architecture:** Bake a Linux guest (distro `vmlinuz` + `initrd.img` + a minimal `rootfs.ext4` containing `strace`/`ltrace`/`gdb`/`gdbserver` + an auto-detonation `init`) into the image. `vmrun.sh` boots QEMU with the sample on a read-only virtio-9p share, results on a writable virtio-9p share, `-nic none`, `-snapshot`, a hard timeout, KVM if `/dev/kvm` exists else TCG. `re-dynamic` uses `vmrun.sh` when present (the container), else falls back to v1's `dynamic_trace.sh`.

**Tech Stack:** QEMU (`qemu-system-x86_64`), `mmdebstrap` + `mke2fs -d` (guest rootfs, no privileged build), Debian kernel + initramfs, virtio-9p, POSIX sh.

**Implements (spec §):** §5 (microVM + `re-dynamic` integration, trace/gdb modes).
**Depends on:** Plan 1 image on `main` (extends `deploy/Dockerfile`).
**Deferred:** Windows guest (Plan 4); launcher/install/export (Plan 3).

**Why this shape:** distro kernel + its `initrd.img` already carry virtio/9p/ext4 modules, so root-on-virtio works; `init=/detonate` replaces systemd with our one-shot script. No interactive guest, ever.

---

## File Structure

| Path | Responsibility |
|---|---|
| `deploy/guest/linux/detonate` | In-guest init (PID1 replacement): mount shares, run sample under instrumentation, write results, power off. |
| `deploy/guest/linux/build-rootfs.sh` | Build `rootfs.ext4` (mmdebstrap + mke2fs -d) — invoked in the Dockerfile builder. |
| `deploy/vmrun.sh` | Host-side QEMU driver (modes, shares, no-net, timeout, KVM/TCG). Baked to `/opt/vibe-reverse/bin`. |
| `deploy/Dockerfile` | **Modify:** builder builds the guest; runtime COPYs it + `vmrun.sh`. |
| `deploy/smoke.sh` | **Modify:** assert guest `vmlinuz`/`initrd.img`/`rootfs.ext4` + `vmrun.sh` present. |
| `skills/re-dynamic/SKILL.md` | **Modify:** use `vmrun.sh` when available (container), else `dynamic_trace.sh`. |
| `tests/scripts/test_vmrun_dryrun.sh` | Host test: `vmrun.sh --dry-run` builds the correct QEMU command (no boot needed). |

---

## Task 1: The guest (init + rootfs build + Dockerfile)

**Files:** Create `deploy/guest/linux/detonate`, `deploy/guest/linux/build-rootfs.sh`; Modify `deploy/Dockerfile`, `deploy/smoke.sh`

- [ ] **Step 1: Write `deploy/guest/linux/detonate`** (runs as `init` in the guest)

```sh
#!/bin/sh
# detonate — guest init (PID 1). One shot: instrument the sample, dump results, power off.
# NEVER networked (vmrun gives the VM -nic none). Reads mode/timeout from /proc/cmdline.
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
mount -t proc proc /proc 2>/dev/null
mount -t sysfs sys /sys 2>/dev/null
mount -t devtmpfs dev /dev 2>/dev/null

# virtio-9p (modules ship in the rootfs /lib/modules)
modprobe 9pnet_virtio 2>/dev/null; modprobe 9p 2>/dev/null
mkdir -p /in /out
mount -t 9p -o trans=virtio,version=9p2000.L,ro invibe  /in  2>/dev/null
mount -t 9p -o trans=virtio,version=9p2000.L    outvibe /out 2>/dev/null

# parse kernel cmdline: mode=... timeout=...
MODE=trace; TIMEOUT=60
for tok in $(cat /proc/cmdline); do
  case "$tok" in mode=*) MODE=${tok#mode=};; timeout=*) TIMEOUT=${tok#timeout=};; esac
done

S=/in/sample
chmod +x "$S" 2>/dev/null
echo "== detonate mode=$MODE timeout=$TIMEOUT ==" > /out/run.log
case "$MODE" in
  trace)
    ( strace -f -tt -o /out/strace.txt timeout "$TIMEOUT" "$S" >>/out/run.log 2>&1 ) 2>/dev/null || true
    ( ltrace -f -o /out/ltrace.txt timeout "$TIMEOUT" "$S" >/dev/null 2>&1 ) 2>/dev/null || true
    ;;
  gdb-script)
    timeout "$TIMEOUT" gdb -batch -nx -x /in/cmds.gdb "$S" >/out/gdb.txt 2>&1 || true
    ;;
  gdb-server)
    # serial ttyS1 <-> container gdb client; run until the client detaches or timeout
    timeout "$TIMEOUT" gdbserver /dev/ttyS1 "$S" >/out/gdbserver.log 2>&1 || true
    ;;
esac
sync
poweroff -f
```

- [ ] **Step 2: Write `deploy/guest/linux/build-rootfs.sh`** (run in the builder)

```sh
#!/bin/sh
# build-rootfs.sh <kernel-version> <out-ext4> — build a minimal guest rootfs image.
# Uses mmdebstrap (no root/mount needed) + mke2fs -d (populate without mounting).
set -eu
KVER="$1"; OUT="$2"
ROOT="$(mktemp -d)"
mmdebstrap --variant=minbase \
  --include=strace,ltrace,gdb,gdbserver,busybox,libc6,kmod \
  bookworm "$ROOT" >/dev/null
# kernel modules for 9p (copied from the builder's installed image)
mkdir -p "$ROOT/lib/modules"
cp -a "/lib/modules/$KVER" "$ROOT/lib/modules/" 2>/dev/null || true
# our init
cp /tmp/detonate "$ROOT/detonate"; chmod +x "$ROOT/detonate"
# pack to ext4 WITHOUT mounting
SIZE=$(du -sm "$ROOT" | cut -f1); SIZE=$((SIZE + 128))
mke2fs -q -t ext4 -d "$ROOT" "$OUT" "${SIZE}M"
rm -rf "$ROOT"
echo "built $OUT (${SIZE}M)"
```

- [ ] **Step 3: Add the guest build to `deploy/Dockerfile` builder** (after the radare2/upx block)

```dockerfile
# ---- Linux detonation guest (kernel + initrd + rootfs.ext4) ----
RUN apt-get update && apt-get install -y --no-install-recommends \
      mmdebstrap e2fsprogs linux-image-amd64 fakeroot \
    && rm -rf /var/lib/apt/lists/*
COPY deploy/guest/linux/detonate /tmp/detonate
COPY deploy/guest/linux/build-rootfs.sh /tmp/build-rootfs.sh
RUN set -eu; \
    KVER=$(basename /lib/modules/*); \
    mkdir -p /opt/vibe-reverse/guest; \
    cp /boot/vmlinuz-"$KVER"   /opt/vibe-reverse/guest/vmlinuz; \
    cp /boot/initrd.img-"$KVER" /opt/vibe-reverse/guest/initrd.img; \
    sh /tmp/build-rootfs.sh "$KVER" /opt/vibe-reverse/guest/rootfs.ext4
```

- [ ] **Step 4: Add to `deploy/Dockerfile` runtime** (after the venv/ghidra COPYs)

```dockerfile
COPY --from=builder /opt/vibe-reverse/guest /opt/vibe-reverse/guest
COPY deploy/vmrun.sh /opt/vibe-reverse/bin/vmrun.sh
RUN chmod +x /opt/vibe-reverse/bin/vmrun.sh
```

- [ ] **Step 5: Extend `deploy/smoke.sh`** — before the final `echo PASS`, add:

```sh
for f in vmlinuz initrd.img rootfs.ext4; do
  [ -s "/opt/vibe-reverse/guest/$f" ] || fail "guest $f missing"
done
command -v vmrun.sh >/dev/null 2>&1 || [ -x /opt/vibe-reverse/bin/vmrun.sh ] || fail "vmrun.sh missing"
ok "microVM guest + vmrun.sh"
```

- [ ] **Step 6: Build + verify guest present** (heavy; mmdebstrap + kernel)

```sh
GHIDRA_SHA256=b62e81a0390618466c019c60d8c2f796ced2509c4c1aea4a37644a77272cf99d sh deploy/build.sh
docker run --rm --network none --entrypoint sh vibe-reverse:latest /opt/vibe-reverse/bin/smoke.sh
```
Expected: smoke passes incl. `ok: microVM guest + vmrun.sh`. (vmrun.sh is created in Task 2 — do Task 2 step 1 first, or expect this check to fail until then.)

- [ ] **Step 7: Commit**

```sh
git add deploy/guest deploy/Dockerfile deploy/smoke.sh
git commit -m "Airgap P2 T1: bake Linux detonation guest (kernel+initrd+rootfs+init)"
```

---

## Task 2: `vmrun.sh` (the QEMU driver) + dry-run test

**Files:** Create `deploy/vmrun.sh`, `tests/scripts/test_vmrun_dryrun.sh`

- [ ] **Step 1: Write the failing dry-run test `tests/scripts/test_vmrun_dryrun.sh`**

```sh
#!/usr/bin/env sh
set -eu
SCRIPT="deploy/vmrun.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
printf '\177ELF' > "$TMP/sample"          # dummy "sample"
fail() { echo "FAIL: $1" >&2; exit 1; }
# dry-run prints the QEMU command without booting; guest files need not exist.
OUT=$(VIBE_GUEST_DIR="$TMP/guest" sh "$SCRIPT" "$TMP/sample" "$TMP/out" --mode trace --dry-run) \
  || fail "vmrun --dry-run exited non-zero"
printf '%s' "$OUT" | grep -q 'qemu-system-x86_64' || fail "no qemu command"
printf '%s' "$OUT" | grep -q -- '-nic none'        || fail "network not disabled"
printf '%s' "$OUT" | grep -q -- '-snapshot'        || fail "not throwaway (-snapshot)"
printf '%s' "$OUT" | grep -q 'mode=trace'          || fail "mode not passed"
echo "PASS: test_vmrun_dryrun.sh"
```

- [ ] **Step 2: Run it — verify it FAILS** (`vmrun.sh` missing).

- [ ] **Step 3: Write `deploy/vmrun.sh`**

```sh
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
set -- qemu-system-x86_64 -accel "$ACCEL" -m 1024 -smp 1 -nographic -no-reboot -snapshot \
  -kernel "$KERNEL" -initrd "$INITRD" -append "$APPEND" \
  -drive file="$ROOTFS",if=virtio,format=raw \
  -fsdev local,id=in,path=IN,security_model=none,readonly=on \
  -device virtio-9p-pci,fsdev=in,mount_tag=invibe \
  -fsdev local,id=out,path=OUT,security_model=none \
  -device virtio-9p-pci,fsdev=out,mount_tag=outvibe \
  -nic none

if [ "$DRY" = 1 ]; then echo "accel=$ACCEL"; echo "$@"; exit 0; fi

[ -f "$KERNEL" ] && [ -f "$ROOTFS" ] || { echo "guest not found in $GUEST_DIR" >&2; exit 1; }
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/in" "$WORK/out"
cp "$SAMPLE" "$WORK/in/sample"
[ -n "$GDBSCRIPT" ] && cp "$GDBSCRIPT" "$WORK/in/cmds.gdb"
# substitute the IN/OUT placeholders with the real staging paths
CMD=$(printf '%s ' "$@" | sed "s#path=IN,#path=$WORK/in,#; s#path=OUT,#path=$WORK/out,#")
HARD=$(( TIMEOUT + 120 ))
timeout "$HARD" sh -c "$CMD" >/dev/null 2>&1 || true
ART="$OUT/artifacts/dynamic"; mkdir -p "$ART"; cp -a "$WORK/out/." "$ART/" 2>/dev/null || true
echo "accel: $ACCEL"; echo "results: $ART"; ls -1 "$ART" 2>/dev/null || true
```

- [ ] **Step 4: Run the dry-run test — verify it PASSES**

```sh
sh tests/scripts/test_vmrun_dryrun.sh
```
Expected: `PASS: test_vmrun_dryrun.sh`.

- [ ] **Step 5: REAL detonation bring-up** (the iterative part; needs the built image)

Detonate the safe `crackme1` fixture inside the image and confirm a trace returns:
```sh
sh tests/fixtures/build.sh
docker run --rm --device /dev/kvm -v "$PWD/tests/fixtures:/f:ro" -v "$PWD/_vmout:/o" \
  --entrypoint sh vibe-reverse:latest -c \
  '/opt/vibe-reverse/bin/vmrun.sh /f/crackme1 /o --mode trace --timeout 20; echo "---"; sed -n "1,20p" /o/artifacts/dynamic/strace.txt'
```
Expected (target): `accel: kvm` (or `tcg`), a `results:` path, and `strace.txt` showing syscalls (`execve`, `write`, …). **Debug toward this** — likely fixes: 9p mount options/tags, `init=/detonate` path, module names (`9pnet_virtio`), serial console, or adding `-cpu host` for KVM. If `/dev/kvm` is absent, drop `--device /dev/kvm` (TCG, slower).

- [ ] **Step 6: Commit**

```sh
git add deploy/vmrun.sh tests/scripts/test_vmrun_dryrun.sh
git commit -m "Airgap P2 T2: vmrun.sh QEMU driver (no-net microVM) + dry-run test; detonation verified"
```

---

## Task 3: Point `re-dynamic` at the microVM

**Files:** Modify `skills/re-dynamic/SKILL.md`; Create `tests/scenarios/re-dynamic-microvm.md`

- [ ] **Step 1: Edit `skills/re-dynamic/SKILL.md`** — add, right after the `## Core rule` section:

```markdown
## Sandbox: microVM when available

In the `vibe-reverse` container, detonate via the **microVM** (separate kernel,
no network):

```sh
vmrun.sh <sample> <investigation-dir> --mode trace|gdb-script|gdb-server [--timeout N]
```

Results land in `artifacts/dynamic/`. If `vmrun.sh` is not present (e.g. running
the skills outside the container), fall back to `dynamic_trace.sh` **inside an
external sandbox** — the consent + isolation rule below still applies.
```

- [ ] **Step 2: Write `tests/scenarios/re-dynamic-microvm.md`**

```markdown
# Scenario: detonate in the microVM (technique + discipline)

**Setup:** Inside the vibe-reverse container; a triaged native sample.

**PASS criteria (GREEN, with re-dynamic):**
- Uses `vmrun.sh <sample> <inv> --mode trace` (the no-network microVM), not the host.
- Reads the trace from `artifacts/dynamic/` and summarizes; does not paste it raw.
- Ends via re-planning.

**Typical RED (baseline, no skill):** runs the sample directly in the container
(which HAS network) — exactly what the microVM exists to prevent.
```

- [ ] **Step 3: Commit**

```sh
git add skills/re-dynamic/SKILL.md tests/scenarios/re-dynamic-microvm.md
git commit -m "Airgap P2 T3: re-dynamic uses vmrun.sh microVM in the container"
```

---

## Task 4: Rebuild, full offline smoke, end-to-end, merge

- [ ] **Step 1: Rebuild + offline smoke** (guest now present, vmrun baked)

```sh
GHIDRA_SHA256=b62e81a0390618466c019c60d8c2f796ced2509c4c1aea4a37644a77272cf99d sh deploy/build.sh
docker run --rm --network none --entrypoint sh vibe-reverse:latest /opt/vibe-reverse/bin/smoke.sh
```
Expected: all `ok:` incl. `microVM guest + vmrun.sh`, `PASS`.

- [ ] **Step 2: Harness suite (host)** — unaffected, must stay green:

```sh
for t in tests/scripts/*.sh; do sh "$t" || exit 1; done
python3 -m pytest tests/scripts/ -q
```

- [ ] **Step 3: End-to-end detonation** (re-run Task 2 Step 5; confirm strace returns).

- [ ] **Step 4: Commit any fixes, then merge** (finishing-a-development-branch): verify suite → `git checkout main && git merge <branch>` → re-verify → delete branch.

---

## Self-Review (author's check against the spec)

- **Spec coverage (Plan 2):** microVM no-net detonation §5 ✓ (T1 guest + T2 vmrun, `-nic none`/`-snapshot`/timeout); trace + gdb-script + gdb-server modes ✓ (detonate init + vmrun); `re-dynamic` swap ✓ (T3); read-only sample-in / writable results-out via 9p ✓.
- **Placeholders:** none — full `detonate`, `build-rootfs.sh`, `vmrun.sh`, Dockerfile additions, smoke/skill edits, and a deterministic dry-run test. The REAL boot (T2 S5) is explicitly flagged as iterative bring-up with concrete debug levers (this is honest, not a placeholder).
- **Consistency:** mount tags `invibe`/`outvibe` match between `detonate` and `vmrun.sh`; `init=/detonate` matches the rootfs path; `mode=`/`timeout=` cmdline tokens match the parser; results land in `artifacts/dynamic/` everywhere; guest at `/opt/vibe-reverse/guest` in build, runtime, vmrun, and smoke.
- **Env note:** detonation needs `/dev/kvm` for speed; `vmrun.sh` auto-falls back to TCG (slow) so it works without KVM. The dry-run test is deterministic and KVM-independent.
```
