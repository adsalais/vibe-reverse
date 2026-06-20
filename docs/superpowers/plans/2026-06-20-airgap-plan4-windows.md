# Air-gap Deployment — Plan 4: Windows guest (documented & ready) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Ship a complete, documented Windows dynamic-analysis path: `vmrun.sh --guest windows` (no-network QEMU/KVM, sample-in via ISO, results-out via a FAT disk), a Procmon-based in-guest detonate agent, and a runbook for preparing the licensed Windows `qcow2`. End-to-end detonation needs the analyst-supplied image; everything else ships and is dry-run/regression tested.

**Architecture:** Extend `vmrun.sh` with a `--guest windows` branch: boot `windows.qcow2` (`-snapshot`, `-nic none`), pass the sample on a read-only ISO, return results on a pre-formatted FAT disk read back with `mtools` (no mount). The guest auto-runs `detonate.ps1` at logon (Procmon capture → CSV + dropped-file listing → FAT disk → shutdown).

**Tech Stack:** QEMU, `xorriso`/`genisoimage` (sample ISO), `dosfstools` (`mkfs.vfat`), `mtools` (`mcopy`), PowerShell (in guest), Sysinternals Procmon.

**Implements (spec §):** §5 Windows subsection (vmrun windows path, agent, runbook, dry-run).
**Depends on:** Plan 2 (`vmrun.sh`, microVM) + Plan 1 image on `main`.
**Boundary:** We cannot ship Windows; the analyst prepares + supplies `~/.config/vibe-reverse/guests/windows.qcow2` per the runbook.

---

## File Structure

| Path | Responsibility |
|---|---|
| `deploy/vmrun.sh` | **Modify:** add `--guest windows` branch (ISO in, FAT-disk out, no net, snapshot). |
| `deploy/Dockerfile` | **Modify:** runtime adds `xorriso dosfstools mtools`. |
| `deploy/smoke.sh` | **Modify:** assert the ISO/FAT/mtools tools exist. |
| `deploy/guest/windows/detonate.ps1` | In-guest agent: Procmon capture of the sample → results disk → shutdown. |
| `deploy/guest/windows/detonate.cmd` | Logon bootstrap that runs `detonate.ps1`. |
| `deploy/windows-guest.md` | Runbook: prepare + seal the licensed Windows qcow2. |
| `skills/re-dynamic/SKILL.md` | **Modify:** note the `--guest windows` route for PE samples. |
| `tests/scripts/test_vmrun_windows_dryrun.sh` | Windows dry-run produces the right QEMU command (no image needed). |

---

## Task 1: vmrun.sh `--guest windows` + dry-run test + tools

**Files:** Modify `deploy/vmrun.sh`, `deploy/Dockerfile`, `deploy/smoke.sh`; Create `tests/scripts/test_vmrun_windows_dryrun.sh`

- [ ] **Step 1: Write the failing test `tests/scripts/test_vmrun_windows_dryrun.sh`**

```sh
#!/usr/bin/env sh
set -eu
SCRIPT="deploy/vmrun.sh"; TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
printf 'MZ' > "$TMP/sample.exe"
fail() { echo "FAIL: $1" >&2; exit 1; }
OUT=$(VIBE_WIN_IMAGE="$TMP/windows.qcow2" sh "$SCRIPT" "$TMP/sample.exe" "$TMP/out" --guest windows --dry-run) \
  || fail "windows --dry-run exited non-zero"
for s in "qemu-system-x86_64" "windows.qcow2" "-cdrom" "-nic none" "-snapshot"; do
  printf '%s' "$OUT" | grep -q -- "$s" || fail "missing: $s"
done
echo "PASS: test_vmrun_windows_dryrun.sh"
```

- [ ] **Step 2: Run it — verify it FAILS** (vmrun has no windows branch yet).

- [ ] **Step 3: Rewrite `deploy/vmrun.sh`** with a `--guest` switch (linux default + windows). Full file:

```sh
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
```

- [ ] **Step 4: Add Windows tools to `deploy/Dockerfile` runtime apt** — add `xorriso dosfstools mtools` to the runtime `apt-get install` list.

- [ ] **Step 5: Extend `deploy/smoke.sh`** — before `echo PASS`, add:

```sh
for t in xorriso mkfs.vfat mcopy; do command -v "$t" >/dev/null 2>&1 || fail "windows-path tool missing: $t"; done
ok "windows-path tools (iso/fat/mtools)"
```

- [ ] **Step 6: Run both dry-run tests — verify PASS**

```sh
sh tests/scripts/test_vmrun_dryrun.sh          # linux (regression)
sh tests/scripts/test_vmrun_windows_dryrun.sh  # windows
```

- [ ] **Step 7: Commit**

```sh
git add deploy/vmrun.sh deploy/Dockerfile deploy/smoke.sh tests/scripts/test_vmrun_windows_dryrun.sh
git commit -m "Airgap P4 T1: vmrun.sh --guest windows (ISO in / FAT out, no net) + tools + dry-run test"
```

---

## Task 2: In-guest agent + runbook

**Files:** Create `deploy/guest/windows/detonate.ps1`, `deploy/guest/windows/detonate.cmd`, `deploy/windows-guest.md`

- [ ] **Step 1: Write `deploy/guest/windows/detonate.ps1`**

```powershell
# detonate.ps1 — Windows in-guest detonation agent (auto-run at logon; see windows-guest.md).
# Finds the sample on the VIBESAMPLE CD, runs it under Procmon, writes results to the
# VIBEOUT disk, then shuts down. The VM has NO network (vmrun gives -nic none).
$ErrorActionPreference = "SilentlyContinue"
$TimeoutSec = 60
$cd  = (Get-Volume -FileSystemLabel VIBESAMPLE).DriveLetter + ":"
$out = (Get-Volume -FileSystemLabel VIBEOUT).DriveLetter + ":"
$sample  = Join-Path $cd  "sample.exe"
$procmon = "C:\Tools\Procmon.exe"
$pml     = Join-Path $out "procmon.pml"

"== detonate $(Get-Date -Format o) ==" | Out-File -Encoding ascii (Join-Path $out "run.log")
Start-Process $procmon -ArgumentList "/AcceptEula","/Quiet","/Minimized","/BackingFile",$pml -WindowStyle Hidden
Start-Sleep 3
$p = Start-Process -FilePath $sample -PassThru
if (-not $p.WaitForExit($TimeoutSec * 1000)) { try { $p.Kill() } catch {} }
Start-Sleep 2
Start-Process $procmon -ArgumentList "/Terminate" -Wait
Start-Process $procmon -ArgumentList "/OpenLog",$pml,"/SaveAs",(Join-Path $out "procmon.csv") -Wait
Get-ChildItem $env:TEMP -Recurse -ErrorAction SilentlyContinue |
  Select-Object FullName,Length,LastWriteTime | Out-File -Encoding ascii (Join-Path $out "temp_listing.txt")
"done" | Out-File -Append -Encoding ascii (Join-Path $out "run.log")
Stop-Computer -Force
```

- [ ] **Step 2: Write `deploy/guest/windows/detonate.cmd`** (logon bootstrap)

```bat
@echo off
powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File C:\Tools\detonate.ps1
```

- [ ] **Step 3: Write `deploy/windows-guest.md`** — the runbook. Cover, concretely:
  - Create the qcow2 + install Windows in QEMU (one-time, on the internet/build host).
  - Install Sysinternals Procmon to `C:\Tools\Procmon.exe`; copy `detonate.ps1`/`detonate.cmd` to `C:\Tools\`.
  - Enable auto-logon (netplwiz / `DefaultUserName`+`DefaultPassword` registry) and register `detonate.cmd` as a logon scheduled task (or Startup folder).
  - Disable Windows Update/Defender network features (the VM has no net anyway), set a short boot.
  - Shut down cleanly, then place the image at `~/.config/vibe-reverse/guests/windows.qcow2`.
  - Note: `vmrun.sh --guest windows <sample.exe> <inv>` passes the sample on the `VIBESAMPLE` CD and reads results from the `VIBEOUT` disk; verify once with a benign EXE.

- [ ] **Step 4: Commit**

```sh
git add deploy/guest/windows deploy/windows-guest.md
git commit -m "Airgap P4 T2: Windows detonate agent (Procmon) + windows-guest.md runbook"
```

---

## Task 3: Route PE → windows; rebuild; smoke; merge

**Files:** Modify `skills/re-dynamic/SKILL.md`

- [ ] **Step 1: Edit `skills/re-dynamic/SKILL.md`** — in the "Sandbox: microVM" section, after the `vmrun.sh` usage line, add:

```markdown
For a **Windows PE** sample, detonate in the Windows guest instead:
`vmrun.sh <sample.exe> <investigation-dir> --guest windows` (requires a prepared
`~/.config/vibe-reverse/guests/windows.qcow2`; see windows-guest.md).
```

- [ ] **Step 2: Rebuild + offline smoke** (now asserts the iso/fat/mtools tools)

```sh
GHIDRA_SHA256=b62e81a0390618466c019c60d8c2f796ced2509c4c1aea4a37644a77272cf99d sh deploy/build.sh
docker run --rm --network none --entrypoint sh vibe-reverse:latest /opt/vibe-reverse/bin/smoke.sh
```
Expected: all `ok:` incl. `windows-path tools (iso/fat/mtools)`.

- [ ] **Step 3: Regression — Linux detonation still works**

```sh
docker run --rm --device /dev/kvm -v "$PWD/tests/fixtures:/f:ro" --entrypoint sh vibe-reverse:latest -c \
  '/opt/vibe-reverse/bin/vmrun.sh /f/crackme1 /tmp/o --mode trace --timeout 15; wc -l < /tmp/o/artifacts/dynamic/strace.txt'
```
Expected: a non-zero strace line count (Linux path unbroken by the refactor).

- [ ] **Step 4: Windows dry-run inside the image**

```sh
docker run --rm --entrypoint sh vibe-reverse:latest -c \
  'printf MZ >/tmp/s.exe; /opt/vibe-reverse/bin/vmrun.sh /tmp/s.exe /tmp/o --guest windows --dry-run'
```
Expected: the QEMU windows command + the "windows.qcow2 not present — see windows-guest.md" note.

- [ ] **Step 5: Full host suite**, then commit + **merge** (finishing-a-development-branch).

```sh
for t in tests/scripts/*.sh; do sh "$t" >/dev/null 2>&1 && echo "ok $(basename $t)" || echo "FAIL $(basename $t)"; done
git add skills/re-dynamic/SKILL.md && git commit -m "Airgap P4 T3: re-dynamic routes Windows PE to --guest windows"
git checkout main && git merge <branch> && git branch -d <branch>
```

---

## Self-Review (author's check against the spec)

- **Spec coverage (Plan 4):** `vmrun.sh --guest windows` §5 ✓ (T1: ISO in, FAT out via mtools, `-nic none`, `-snapshot`, image-presence check); in-guest Procmon agent §5 ✓ (T2); runbook §5 ✓ (T2); PE routing §5 ✓ (T3); dry-run testable-without-license §5 ✓ (T1 + T3 S4).
- **Placeholders:** none — full `vmrun.sh` (both guests), agent `.ps1`/`.cmd`, runbook outline with concrete steps, tool additions, tests. The only un-runnable-here part is the *actual* Windows detonation (needs the licensed qcow2) — explicitly the documented boundary, dry-run-validated.
- **Consistency:** ISO label `VIBESAMPLE` + disk label `VIBEOUT` match between `vmrun.sh` and `detonate.ps1`; sample path `sample.exe` matches (vmrun copies to `in/sample.exe`, ISO carries it, ps1 reads `VIBESAMPLE:\sample.exe`); `WIN_IMG` default `/guests/windows.qcow2` matches the launcher's `-v $CFG/guests:/guests:ro`; results land in `artifacts/dynamic/` like the Linux path; Linux branch unchanged in behavior (regression test T3 S3).
```
