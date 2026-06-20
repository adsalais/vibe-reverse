# Air-Gapped Deployment (`vibe-reverse`) — Design Spec

- **Date:** 2026-06-20
- **Status:** Approved design — pre-implementation
- **Next step:** turn into implementation plans via `superpowers:writing-plans`
- **Builds on:** the v1 reverse-engineering harness (10 skills on `main`).

---

## 1. Summary & goal

Package the harness for **real malware analysis by a blue team on an air-gapped
network**. Deliver a Docker image (`vibe-reverse:latest`) containing the classic
RE tools, the 10 skills, and **opencode**, built on an internet-connected box and
shipped to the air-gapped network as a single bundle. On an analyst host, the
analyst `cd`s into a folder holding a sample, runs **`vibe-reverse`**, and gets
the opencode TUI; all plans/reports land in that folder, owned by the analyst.

The defining constraint: **the container is networked (to reach internal
OpenAI-compatible LLMs), so malware must never touch that network — every
execution happens in a no-network nested microVM.**

## 2. Context & constraints (decisions on record)

| Decision | Choice |
|---|---|
| Malware execution sandbox | **Nested microVM over KVM** (QEMU), separate kernel, no network |
| Container privileges on hosts | Caps / user-ns OK → `--device /dev/kvm` + `--group-add kvm` acceptable |
| Internal LLM API | **OpenAI-compatible** (custom provider, base URL + bearer key) |
| Analyst hosts | **Linux x86_64** |
| Dynamic-analysis targets | **Linux ELF now; Windows PE documented & ready** (analyst supplies the licensed image) |
| opencode config | file `~/.config/opencode/opencode.json` (we pin via `OPENCODE_CONFIG`) — *verified in source* |
| opencode credentials | file `auth.json` in `$XDG_DATA_HOME/opencode/` — *verified*; flat object keyed by provider id, `{"type":"api","key":"…"}`, mode 0600 |
| opencode offline | `OPENCODE_DISABLE_MODELS_FETCH=1` + `OPENCODE_DISABLE_AUTOUPDATE=1` (*verified real, opencode ≥ v1.0.154*) + pre-installed `@ai-sdk/openai-compatible` + inline local models |

Static analysis (triage, strings, Ghidra decompilation, solving) works on **both
Linux ELF and Windows PE** with no execution; only *dynamic* analysis needs a
matching guest OS.

## 3. Architecture & security model

### Pipeline (build online → ship → run offline)
```
[ internet build box ]
  build.sh  → docker build (multi-stage) → vibe-reverse:latest
              RE tools + Ghidra + uv venv (angr/z3) + opencode + 10 skills
              + QEMU + Linux guest (kernel+rootfs) + internal CA
  export.sh → dist/vibe-reverse-bundle.tgz
              (image.tar.gz + install.sh + vibe-reverse + sample config/auth
               + README + windows-guest.md + SHA256SUMS)
        │  sneakernet
        ▼
[ air-gapped analyst host — Linux x86_64 ]
  install.sh → docker load ; seed ~/.config/vibe-reverse ; install ~/.local/bin/vibe-reverse
        ▼
  cd /cases/incident-42 ; vibe-reverse → opencode TUI ; reports land in the folder
```

### Two network zones (the security model)
```
┌─ CONTAINER  (networked → internal OpenAI-compatible LLM only) ───────────────┐
│   opencode + skills  ──  static analysis (READ-ONLY) of the sample           │
│         │ re-dynamic ONLY                                                     │
│         ▼                                                                     │
│   ┌─ microVM  (QEMU/KVM · separate kernel · -netdev none = NO network) ────┐ │
│   │  sample detonates here under strace/ltrace/gdb · hard timeout · throwaway│ │
│   │  IN: sample via read-only 9p   ·   OUT: trace via writable 9p          │ │
│   └──────────────────────────────────────────────────────────────────────┘ │
└─ host flags: --device /dev/kvm  --group-add kvm  --user $UID:$GID  -v $PWD:/work ─┘
```
- The container is networked **only** for the agent↔LLM channel and only ever
  *reads* the sample (static analysis).
- Malware runs **only** in the microVM — separate kernel, **no network device**.
  A VM escape would still have to beat KVM to reach the container's network.
- Sample in via **read-only** 9p; trace out via **writable** 9p. **No interactive
  shell in the VM** — detonation is automated with a hard timeout, then the VM is
  discarded (`-snapshot`).

### Why QEMU (not Firecracker)
apt-installable and simple to bake/drive offline; virtio-9p makes sample-in /
trace-out trivial; and it can host a **Windows** guest later (Firecracker cannot),
matching the "Windows droppable-in" decision.

## 4. The image — multi-stage Dockerfile + CA + opencode hardening

### Stage 1 `builder` (internet; discarded)
- apt: `curl wget unzip git ca-certificates mmdebstrap e2fsprogs linux-image-amd64 python3`
- assembles: **opencode** (pinned ≥ v1.0.154 standalone binary) **+ pre-installed
  `@ai-sdk/openai-compatible`**; **Ghidra** → `/opt/ghidra`; **uv venv** at
  `/opt/vibe-reverse/venv` (angr, z3 — pinned to system python via
  `uv venv --python /usr/bin/python3`, or `--relocatable`); **Linux guest**
  (`vmlinuz` from `linux-image-amd64` + a minimal Debian `rootfs.ext4` with
  `strace`/`ltrace`/`gdb`/`gdbserver`/`busybox` + the detonation `init`, built via
  `mmdebstrap` + `mke2fs -d`, **no privileged/mount needed**).

### Stage 2 `runtime` (slim; shipped) — `FROM debian:stable-slim`
- apt (runtime only): `file binutils binwalk radare2 gdb ltrace strace upx-ucl xxd qemu-system-x86 qemu-utils python3 ca-certificates`
- `COPY --from=builder`: opencode binary + the AI-SDK package, `/opt/ghidra`,
  `/opt/vibe-reverse/venv` (**same path** for venv portability), guest
  `vmlinuz`+`rootfs.ext4`, the 10 skills → `/opt/vibe-reverse/skills`,
  `vmrun.sh` + entrypoint → `/opt/vibe-reverse/bin`.
- `ENV RE_HARNESS_VENV=/opt/vibe-reverse/venv` · `PATH += /opt/ghidra/support:/opt/vibe-reverse/bin`
- `ENV OPENCODE_DISABLE_MODELS_FETCH=1 OPENCODE_DISABLE_AUTOUPDATE=1`
- `ENTRYPOINT` = the entrypoint script (runs opencode in `/work` — §6).

Multi-stage payoff: toolchains, apt caches, the Ghidra zip, mmdebstrap cruft, and
the kernel package never ship — only unpacked artifacts.

### Internal CA
`build.sh` expects `deploy/ca.pem` (next to the Dockerfile):
```dockerfile
COPY deploy/ca.pem /usr/local/share/ca-certificates/internal-ca.crt
RUN update-ca-certificates
ENV NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt \
    SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
```
`update-ca-certificates` → system trust; `NODE_EXTRA_CA_CERTS` → opencode trusts
the internal CA over TLS; `SSL_CERT_FILE`/`REQUESTS_CA_BUNDLE` → Python. No CA?
`build.sh` writes an empty placeholder and skips registration.

### opencode offline hardening (verified)
`OPENCODE_DISABLE_MODELS_FETCH=1` stops the unconditional `models.dev` fetch;
`OPENCODE_DISABLE_AUTOUPDATE=1` stops update checks; `@ai-sdk/openai-compatible`
is pre-installed (no runtime npm); local models are defined **inline** in
`opencode.json` (with `limit`), so models.dev is never needed. Config also sets
`"share":"disabled"` + `"autoupdate":false` (belt-and-suspenders). The smoke test
runs opencode under network isolation to prove no blocking phone-home.

## 5. The microVM sandbox + `re-dynamic`

### Guest (baked, stage 1)
`vmlinuz` + minimal Debian `rootfs.ext4` with `strace`/`ltrace`/`gdb`/`gdbserver`/
`busybox` + a detonation `init` that runs one job and powers off (no human enters
the guest).

### `vmrun.sh` (called by `re-dynamic`)
```
vmrun.sh <sample> <out-dir> [--guest linux|windows] [--mode trace|gdb-script|gdb-server] [--timeout N] [--dry-run]
  → qemu-system-x86_64 [-enable-kvm | TCG fallback if no /dev/kvm] -m 1G -nographic -snapshot
    -kernel vmlinuz -append "console=ttyS0 mode=… timeout=…"
    -drive rootfs.ext4              (throwaway)
    -virtfs sample  (READ-ONLY 9p)      ← malware in
    -virtfs results (READ-WRITE 9p)     ← traces out
    -netdev none                         ← NO network
    [-serial unix:/run/gdb.sock          for --mode gdb-server]
  → hard wall-clock timeout kills the VM
  → results copied to <case>/artifacts/dynamic/ (strace.txt, ltrace.txt, gdb.txt, dropped files, fs-diff, attempted-net IOCs)
```
- **`trace`** (default): strace+ltrace, dropped files, fs-diff, *attempted* (failed) network syscalls = IOCs.
- **`gdb-script`**: `gdb -batch -x <agent-written script>`.
- **`gdb-server`**: `gdbserver` on a serial port → container-side gdb client over a unix socket (**not TCP**; VM stays net-free); the agent debugs iteratively.

### `re-dynamic` integration
In the image, `re-dynamic`'s helper is swapped from v1's host-level
`dynamic_trace.sh` to **`vmrun.sh`** — same skill, same consent+sandbox
discipline, now backed by a separate-kernel VM. The SKILL.md red-flags
("just run it on the host") apply with full force.

### Windows guest — documented & ready (analyst supplies the image)
- `vmrun.sh --guest windows`: real path — `-enable-kvm -snapshot -netdev none`,
  boots `windows.qcow2`, sample in on a **read-only ISO**, results out on a
  **pre-formatted results disk** (IDE/SATA → no virtio drivers needed; virtio
  documented as a perf option), hard timeout, throwaway.
- In-guest agent `deploy/guest/windows/detonate.ps1`+`.cmd`: at boot, finds the
  sample on the CD, runs it under **Procmon** (`/Quiet /Minimized /BackingFile`,
  timed), exports the log (PML→CSV/XML) + dropped-file/registry diffs to the
  results disk, shuts down. (Sysmon optional.)
- Runbook `deploy/windows-guest.md`: one-time prep of the qcow2 (install Windows,
  install Procmon, register the agent as an auto-logon scheduled task, seal),
  placed at `~/.config/vibe-reverse/guests/windows.qcow2`.
- `re-triage`'s PE detection suggests the `--guest windows` route.
- **Testable without a license:** `vmrun.sh --guest windows --dry-run` prints/validates
  the QEMU command + ISO/results wiring and asserts the image exists.
- **Boundary:** we cannot ship Windows itself; everything else (plumbing, agent,
  IOC export, runbook, dry-run) ships and works.

## 6. Launcher, install & opencode config/auth

### Host config dir `~/.config/vibe-reverse/` (seeded by `install.sh`)
```
opencode.json   # custom OpenAI-compatible provider + inline model + skills.paths
auth.json       # {"internal":{"type":"api","key":"…"}}  (chmod 600)
guests/         # optional windows.qcow2
```

**`opencode.json`** (provider id `internal` must match the `model` prefix and the
auth key):
```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "internal/our-model",
  "share": "disabled",
  "autoupdate": false,
  "experimental": { "openTelemetry": false },
  "provider": {
    "internal": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Internal LLM",
      "options": { "baseURL": "https://llm.internal.example/v1" },
      "models": { "our-model": { "name": "Our Model", "limit": { "context": 128000, "output": 16384 } } }
    }
  },
  "skills": { "paths": ["/opt/vibe-reverse/skills"] }
}
```
**`auth.json`** (chmod 600):
```json
{ "internal": { "type": "api", "key": "YOUR-BEARER-TOKEN" } }
```

### Launcher `~/.local/bin/vibe-reverse`
```sh
docker run --rm -it \
  --user "$(id -u):$(id -g)" --group-add "$(getent group kvm | cut -d: -f3)" --device /dev/kvm \
  -v "$PWD":/work -w /work \
  -v "$HOME/.config/vibe-reverse":/cfg:ro \
  $( [ -d "$HOME/.config/vibe-reverse/guests" ] && echo -v "$HOME/.config/vibe-reverse/guests":/guests:ro ) \
  --tmpfs /state:mode=1777 \
  -e HOME=/state -e XDG_DATA_HOME=/state -e XDG_CACHE_HOME=/state \
  -e OPENCODE_CONFIG=/cfg/opencode.json \
  vibe-reverse:latest
```
- **UID mapping**: files written into the case folder are owned by the analyst, never root; baked artifacts are world-readable.
- **KVM perms**: `--group-add kvm` lets the mapped non-root user reach `/dev/kvm`.
- **State**: opencode's writable HOME/cache is a throwaway `--tmpfs /state:mode=1777`.
- **Config/auth**: config pinned read-only via `OPENCODE_CONFIG`; the **entrypoint** copies `/cfg/auth.json` → `$XDG_DATA_HOME/opencode/auth.json` (chmod 600) so opencode finds the credential in its writable data dir.
- Network stays default-bridge (LLM only, ideally egress-restricted by site policy); the malware's isolation is the microVM's job.
- A `--print` flag echoes the `docker run` without executing (for testing/audit).

### `install.sh` (air-gapped host)
1. `docker load -i vibe-reverse-image.tar.gz`
2. seed `~/.config/vibe-reverse/{opencode.json,auth.json}` only if absent (never clobber); `chmod 600 auth.json`; `mkdir guests/`
3. install `~/.local/bin/vibe-reverse` (chmod +x)
4. print next steps: edit `opencode.json` (baseURL/model) + `auth.json` (key); ensure `~/.local/bin` on PATH; `cd <case> && vibe-reverse`

## 7. build / export / bundle

- **`deploy/build.sh`** (repo root): ensure `deploy/ca.pem` (placeholder if absent);
  `docker build -t vibe-reverse:latest -f deploy/Dockerfile .` (context = repo root
  for `skills/`, `requirements/python-tools.txt`, `deploy/`); build args for pinned
  versions (opencode, Ghidra, guest kernel, VM mem); print image size.
- **`deploy/export.sh`** → `dist/vibe-reverse-bundle.tgz` = `docker save | gzip` +
  `install.sh` + `vibe-reverse` + `config/{opencode.json,auth.json.sample}` +
  `README.md` + `windows-guest.md` + `SHA256SUMS`.

## 8. Repo layout (new `deploy/`; v1 harness untouched)
```
deploy/
  Dockerfile build.sh export.sh install.sh vibe-reverse vmrun.sh entrypoint.sh
  ca.pem(gitignored) windows-guest.md README.md
  config/{opencode.json,auth.json.sample}
  guest/linux/{init,build-rootfs.sh}
  guest/windows/{detonate.ps1,detonate.cmd}
dist/ (gitignored)
```
`vmrun.sh`, `entrypoint.sh`, and the 10 skills are baked into the image.

## 9. Testing
- **Image smoke test** (`deploy/smoke.sh`, inside the image, **under network
  isolation**): opencode starts with no blocking phone-home; `analyzeHeadless`
  present; venv imports `z3`+`angr`; `qemu-system-x86_64` present; skills at
  `/opt/vibe-reverse/skills`; guest `vmlinuz`+`rootfs.ext4` present; CA in trust store.
- **Linux microVM test**: detonate a benign sample via `vmrun.sh --mode trace`,
  assert a trace returns. Uses `-enable-kvm` when `/dev/kvm` exists, else **TCG
  fallback** (slower) — testable without KVM.
- **Windows path**: `vmrun.sh --guest windows --dry-run` validates the QEMU command
  + image presence (no license needed).
- **Launcher/install**: `sh -n`; launcher `--print` echoes the `docker run`;
  `install.sh` idempotency (no-clobber config).

## 10. Implementation decomposition (separate plans)
1. **Image + CA + opencode hardening + `build.sh` + smoke test.**
2. **Linux microVM** (`vmrun.sh` + guest rootfs/init + `re-dynamic` swap + tests).
3. **Launcher + install + config/auth + `export.sh`/bundle.**
4. **Windows guest path** (`vmrun.sh --guest windows` + agent + runbook + dry-run).

## 11. Open items (resolved during the plans)
- Pin exact versions: opencode (≥ v1.0.154; choose a recent tag), Ghidra, guest
  kernel; record in `build.sh` build args.
- `/dev/kvm` is expected on analyst hosts; `vmrun.sh` TCG fallback covers absence
  (with a logged slowness warning).
- Windows end-to-end depends on the analyst-supplied licensed `qcow2`.
- Confirm the opencode standalone-binary install path/layout when baking (and that
  the pinned tag honors the two disable env vars — covered by the net-isolation
  smoke test).

## 12. Success criteria
- On an internet box, `build.sh` then `export.sh` produce one `vibe-reverse-bundle.tgz`.
- On a clean air-gapped Linux host, `install.sh` loads the image, seeds config/auth,
  installs the launcher; after the analyst fills `opencode.json`/`auth.json`,
  `cd <case> && vibe-reverse` opens opencode wired to the internal LLM, with the 10
  skills available.
- Static analysis runs on Linux **and** Windows samples; `re-dynamic` detonates a
  Linux sample in the microVM with **no network** and returns a trace; Windows
  detonation works once a prepared `qcow2` is supplied.
- Files written to the case folder are owned by the analyst (host UID), never root.
- opencode performs **no blocking network call** other than to the configured
  internal LLM (verified under isolation).

## 13. Security boundary & authorization
This is **authorized blue-team / defensive** analysis on an air-gapped network.
Defense in depth: static-by-default; malware executes **only** inside a
no-network microVM (separate kernel); the container's network is for the internal
LLM only; nothing from a detonation persists (`-snapshot`, tmpfs). The harness's
existing `re-dynamic` consent+sandbox discipline is retained and strengthened.
