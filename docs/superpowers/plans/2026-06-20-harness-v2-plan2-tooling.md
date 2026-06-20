# Harness v2 — Plan 2: Tooling & Docker — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bake all the advanced-RE tooling into the air-gapped image (and the `requirements/` installers): the Python libraries, the FLARE/DIE **standalone binaries** (capa, FLOSS, Detect-It-Easy), and `yara`; extend the build-time import check and `smoke.sh` so a broken/missing tool fails loudly.

**Architecture:** `deploy/Dockerfile` is a builder→runtime multi-stage build. New Python libs go in `requirements/python-tools.txt` (installed globally). Tools that conflict with angr's pinned stack (capa, FLOSS) are baked as **standalone release binaries** staged in the builder (the existing radare2/upx pattern); DIE ships as a Debian `.deb` (the radare2 pattern). `build.sh` gains pinned URL+sha build args. Offline tests are **static grep checks** (no docker); real verification is `build.sh` + `smoke.sh` on an internet host.

**Tech Stack:** Docker (multi-stage), Debian trixie apt, global pip (Python 3.12), POSIX `sh`.

**Implements (spec sections):** §7 (all tooling), parts of §8 (smoke assertions).
**Depends on:** Plan 1 (air-gap framing, no-install rule) on `main`.
**Deferred:** the skills that *use* these tools (Plans 3–4).

**Plan sequence:** Plan 2 of 4.

## Global Constraints

- Base image **`python:3.12-slim-trixie`**; pin **`angr==9.2.221`** (z3 arrives via angr); Python tools install **globally** (no venv/uv in the container).
- Conflict-prone FLARE tools (capa, FLOSS) are baked as **standalone Linux binaries**, NOT pip — to protect angr's `claripy/pyvex/cle/z3` resolution.
- Pinned downloads are **sha256-verified**; the build **fails closed** if a sha is unset (the `${VAR:?}` pattern, like `GHIDRA_SHA256`).
- The build runs an **import check**; a broken/conflicting install fails the build.
- Offline tests must not require docker or network (static checks only).
- Commit messages end with: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

## File Structure

| Path | Responsibility |
|---|---|
| `requirements/python-tools.txt` | + capstone, keystone, unicorn, lief, pefile, pyelftools, yara-python, r2pipe, pwntools, miasm, qiling, speakeasy, Triton. |
| `deploy/Dockerfile` | Stage capa/FLOSS/DIE in builder; apt `yara`; install standalone bins; extend import check. |
| `deploy/build.sh` | Pinned URL+sha build args for capa/FLOSS/DIE. |
| `deploy/smoke.sh` | Assert new tools present + importable. |
| `requirements/Dockerfile` | Mirror: apt `yara`; the shared python-tools.txt. |
| `requirements/setup.sh` | Host: install new pip libs into the venv; note standalone bins are container-only. |
| `tests/scripts/test_requirements.sh` | Assert key new pip libs are listed. |
| `tests/scripts/test_deploy_image.sh` | Assert the new tool lines in the Dockerfile/build.sh. |
| `AGENTS.md` | Deployment notes for the new tooling. |

---

## Task 1: Expand `requirements/python-tools.txt`

**Files:**
- Modify: `requirements/python-tools.txt`, `tests/scripts/test_requirements.sh`

- [ ] **Step 1: Add the assertion first in `tests/scripts/test_requirements.sh`**

After the existing `angr` assertion (line 10), add:

```sh
for pkg in capstone keystone-engine unicorn lief pefile pyelftools \
           yara-python r2pipe pwntools miasm qiling; do
  grep -qi "$pkg" requirements/python-tools.txt || fail "python-tools.txt missing $pkg"
done
```

- [ ] **Step 2: Run it — verify it FAILS**

Run: `sh tests/scripts/test_requirements.sh`
Expected: FAIL ("python-tools.txt missing capstone").

- [ ] **Step 3: Rewrite `requirements/python-tools.txt`**

```text
# Python tools for the RE harness — installed GLOBALLY in the container
# (requirements/Dockerfile, deploy/Dockerfile) or into a host venv (setup.sh).
# Pin angr — it brings a consistent stack (archinfo/pyvex/claripy/cle) AND z3.
# Pinning angr stops the resolver backtracking to an ancient broken 9.0.x.
angr==9.2.221

# disassemble / assemble / emulate (patching, deobfuscation, devirt helpers)
capstone
keystone-engine
unicorn

# parse / modify binary formats
lief
pefile
pyelftools

# signatures, radare2 scripting, exploit/CTF utilities
yara-python
r2pipe
pwntools

# control-flow deobfuscation & devirtualization frameworks
miasm

# emulation: unpack / config-extract without full detonation
qiling
# Windows user-mode malware emulation (pairs with the Windows guest)
speakeasy-emulator

# Triton (Quarkslab) — taint + symbolic DBA for devirtualization.
# If no platform wheel installs cleanly, build it in the Dockerfile builder stage
# instead (see deploy/Dockerfile) and drop this line.
triton-library

# NOTE: pin exact versions once the first container build succeeds (the build's
# import check is the gate); record the resolved versions here for reproducibility.
# capa + FLOSS are NOT here — they ship as standalone binaries (deploy/Dockerfile)
# to avoid dragging vivisect deps into angr's resolution.
```

- [ ] **Step 4: Run the test — verify it PASSES** (`PASS: test_requirements.sh`).

- [ ] **Step 5: Commit**

```sh
git add requirements/python-tools.txt tests/scripts/test_requirements.sh
git commit -m "Plan2-2 T1: expand python-tools.txt with the advanced-RE libraries"
```

---

## Task 2: `deploy/Dockerfile` — stage capa/FLOSS/DIE, apt yara, extend import check

**Files:**
- Modify: `deploy/Dockerfile`, `deploy/build.sh`, `tests/scripts/test_deploy_image.sh`

- [ ] **Step 1: Add the failing static assertions to `tests/scripts/test_deploy_image.sh`**

Before the final `echo "PASS..."`, add:

```sh
# advanced-RE tooling baked
grep -q 'yara' "$D"  || fail "Dockerfile does not apt-install yara"
grep -qi 'capa' "$D" || fail "Dockerfile does not stage capa"
grep -qi 'floss' "$D" || fail "Dockerfile does not stage FLOSS"
grep -qi 'diec\|detect-it-easy\|die.deb' "$D" || fail "Dockerfile does not install Detect-It-Easy"
grep -q 'import capstone' "$D" || fail "Dockerfile import check missing new libs"
# build.sh passes the new pinned download args
grep -q 'CAPA_URL'  deploy/build.sh || fail "build.sh missing CAPA_URL arg"
grep -q 'FLOSS_URL' deploy/build.sh || fail "build.sh missing FLOSS_URL arg"
grep -q 'DIE_DEB_URL' deploy/build.sh || fail "build.sh missing DIE_DEB_URL arg"
```

- [ ] **Step 2: Run it — verify it FAILS**

Run: `sh tests/scripts/test_deploy_image.sh`
Expected: FAIL ("Dockerfile does not apt-install yara").

- [ ] **Step 3: Add the build args to the builder stage of `deploy/Dockerfile`**

After the existing `ARG UPX_URL` line, add:

```dockerfile
ARG CAPA_URL
ARG CAPA_SHA256
ARG FLOSS_URL
ARG FLOSS_SHA256
ARG DIE_DEB_URL
ARG DIE_DEB_SHA256
```

- [ ] **Step 4: Stage capa/FLOSS/DIE in the builder stage**

Immediately after the existing radare2+upx staging `RUN` block (the one ending `&& rm -rf /tmp/upx.tar.xz /tmp/upx-*`), add:

```dockerfile
# capa + FLOSS: FLARE standalone Linux release binaries (zip -> single binary).
# Staged here, copied to runtime — they are NOT pip-installed (vivisect deps would
# clash with angr's pinned stack). Detect-It-Easy ships as a Debian .deb (diec CLI).
RUN curl -fsSL "$CAPA_URL"  -o /tmp/capa.zip \
 && echo "${CAPA_SHA256}  /tmp/capa.zip"  | sha256sum -c - \
 && unzip -q /tmp/capa.zip -d /tmp/capa && cp /tmp/capa/capa /opt/dl/capa \
 && curl -fsSL "$FLOSS_URL" -o /tmp/floss.zip \
 && echo "${FLOSS_SHA256}  /tmp/floss.zip" | sha256sum -c - \
 && unzip -q /tmp/floss.zip -d /tmp/floss && cp /tmp/floss/floss /opt/dl/floss \
 && chmod +x /opt/dl/capa /opt/dl/floss \
 && curl -fsSL "$DIE_DEB_URL" -o /opt/dl/die.deb \
 && echo "${DIE_DEB_SHA256}  /opt/dl/die.deb" | sha256sum -c - \
 && rm -rf /tmp/capa.zip /tmp/capa /tmp/floss.zip /tmp/floss
```

(The single-binary path inside each zip — `capa`/`floss` — matches the current FLARE standalone layout; if a future release nests it, adjust the `cp` source.)

- [ ] **Step 5: apt `yara` + install standalone bins in the runtime stage**

In the runtime `apt-get install` list, add `yara` to the package list (same line group as `file binutils binwalk gdb …`), and add the DIE `.deb` to the install set the way `radare2.deb` is installed. Then install capa/FLOSS. Concretely, change the runtime tools `RUN` to:

```dockerfile
COPY --from=builder /opt/dl /opt/dl
RUN apt-get update && apt-get install -y --no-install-recommends \
      file binutils binwalk gdb ltrace strace xxd yara \
      qemu-system-x86 qemu-utils xorriso dosfstools mtools \
      ca-certificates openjdk-21-jdk passwd util-linux \
      /opt/dl/radare2.deb /opt/dl/die.deb \
 && install -Dm755 /opt/dl/upx   /usr/local/bin/upx \
 && install -Dm755 /opt/dl/capa  /usr/local/bin/capa \
 && install -Dm755 /opt/dl/floss /usr/local/bin/floss \
 && test -x /usr/lib/jvm/java-21-openjdk-amd64/bin/java \
 && rm -rf /var/lib/apt/lists/* /opt/dl
```

- [ ] **Step 6: Extend the build-time import check**

Change the python-tools `RUN` import line from:

```dockerfile
 && python -c 'import angr, z3' \
```
to:

```dockerfile
 && python -c 'import angr, z3, capstone, unicorn, keystone, lief, pefile, elftools, miasm, qiling, yara, r2pipe' \
 && python -c 'import pwn, speakeasy' \
 && python -c 'import triton' \
```

(Splitting the risky imports pinpoints which fails. If `import triton` cannot be made to pass via the `triton-library` wheel, replace this line with a builder-stage source build of Triton and copy its module in — see the note in `python-tools.txt`.)

- [ ] **Step 7: Add the pinned args to `deploy/build.sh`**

After the `UPX_URL` line, add:

```sh
# capa + FLOSS standalone Linux releases (set the matching sha256 from the release page):
CAPA_URL="${CAPA_URL:-https://github.com/mandiant/capa/releases/download/v9.2.1/capa-v9.2.1-linux.zip}"
CAPA_SHA256="${CAPA_SHA256:?set CAPA_SHA256 to the sha256 of the capa linux zip}"
FLOSS_URL="${FLOSS_URL:-https://github.com/mandiant/flare-floss/releases/download/v3.1.1/floss-v3.1.1-linux.zip}"
FLOSS_SHA256="${FLOSS_SHA256:?set FLOSS_SHA256 to the sha256 of the floss linux zip}"
# Detect-It-Easy .deb for Debian (diec CLI):
DIE_DEB_URL="${DIE_DEB_URL:-https://github.com/horsicq/DIE-engine/releases/download/3.10/die_3.10_amd64_Debian_13.deb}"
DIE_DEB_SHA256="${DIE_DEB_SHA256:?set DIE_DEB_SHA256 to the sha256 of the DIE .deb}"
```

And pass them in the `docker build` invocation (add to the existing `--build-arg` list):

```sh
  --build-arg CAPA_URL="$CAPA_URL" \
  --build-arg CAPA_SHA256="$CAPA_SHA256" \
  --build-arg FLOSS_URL="$FLOSS_URL" \
  --build-arg FLOSS_SHA256="$FLOSS_SHA256" \
  --build-arg DIE_DEB_URL="$DIE_DEB_URL" \
  --build-arg DIE_DEB_SHA256="$DIE_DEB_SHA256" \
```

- [ ] **Step 8: Run the static test — verify it PASSES**

Run: `sh tests/scripts/test_deploy_image.sh`
Expected: `PASS: test_deploy_image.sh`

- [ ] **Step 9: Commit**

```sh
git add deploy/Dockerfile deploy/build.sh tests/scripts/test_deploy_image.sh
git commit -m "Plan2-2 T2: bake capa/FLOSS/DIE + yara; extend build import check + build.sh args"
```

---

## Task 3: `deploy/smoke.sh` — assert the new tools

**Files:**
- Modify: `deploy/smoke.sh`

- [ ] **Step 1: Add tool-presence checks to `deploy/smoke.sh`**

After the existing "global python z3+angr" block, add:

```sh
# advanced-RE standalone binaries on PATH
for t in capa floss yara diec; do
  command -v "$t" >/dev/null 2>&1 || fail "$t missing from PATH"
done
ok "capa/floss/yara/diec"

# advanced-RE python libs importable (global)
python3 -c 'import capstone, unicorn, keystone, lief, pefile, elftools, miasm, qiling, yara, r2pipe' \
  || fail "global python cannot import the advanced-RE libs"
python3 -c 'import pwn, speakeasy, triton' \
  || fail "global python cannot import pwn/speakeasy/triton"
ok "advanced-RE python libs"
```

- [ ] **Step 2: Syntax-check it offline**

Run: `sh -n deploy/smoke.sh`
Expected: no output (valid).
Also re-run `sh tests/scripts/test_deploy_image.sh` (it greps smoke.sh) → still `PASS`.

- [ ] **Step 3: Commit**

```sh
git add deploy/smoke.sh
git commit -m "Plan2-2 T3: smoke.sh asserts capa/floss/yara/diec + advanced-RE python libs"
```

---

## Task 4: Mirror `requirements/Dockerfile` + `requirements/setup.sh`

**Files:**
- Modify: `requirements/Dockerfile`, `requirements/setup.sh`

- [ ] **Step 1: Add `yara` to `requirements/Dockerfile` apt line**

Change the apt install line to include `yara`:

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
        file binutils binwalk radare2 gdb ltrace strace upx-ucl xxd yara \
        ca-certificates curl git unzip \
    && rm -rf /var/lib/apt/lists/*
```

(The shared `requirements/python-tools.txt` already adds the new libs; the existing `import angr, z3` check stays. capa/FLOSS/DIE standalone staging is the air-gapped `deploy/` image's job — `requirements/` is the simpler dev image, so note them as optional in a comment.)

Add this comment after the pip block:

```dockerfile
# capa / FLOSS / Detect-It-Easy are not pip packages; for this dev image, fetch the
# standalone release binaries manually if needed (the air-gapped deploy/ image bakes them).
```

- [ ] **Step 2: Update `requirements/setup.sh`** — install the new libs into the host venv; note standalone tools

The venv install already runs `pip install -r python-tools.txt`, so the new libs come along. Add `yara` to `SYS_APT`/`SYS_BREW`, and append a note before the final `Done` heredoc:

```sh
cat <<'STANDALONE'
==> standalone tools (not pip; fetch manually if you want them on a host)
  capa  : https://github.com/mandiant/capa/releases       (standalone linux zip)
  FLOSS : https://github.com/mandiant/flare-floss/releases (standalone linux zip)
  DIE   : https://github.com/horsicq/DIE-engine/releases   (diec CLI)
STANDALONE
```

Change `SYS_APT` to:
```sh
SYS_APT="file binutils binwalk radare2 gdb ltrace strace upx-ucl xxd yara"
```

- [ ] **Step 3: Run the requirements test — still PASSES**

Run: `sh tests/scripts/test_requirements.sh`
Expected: `PASS: test_requirements.sh` (setup.sh still uses the venv + `RE_HARNESS_VENV`, no uv).

- [ ] **Step 4: Commit**

```sh
git add requirements/Dockerfile requirements/setup.sh
git commit -m "Plan2-2 T4: mirror yara + new libs into requirements/ dev installers"
```

---

## Task 5: Build + smoke integration verification + deployment docs

**Files:**
- Modify: `AGENTS.md`

> This task needs an **internet-connected host with Docker**; it is the real
> verification that the offline static tests cannot do.

- [ ] **Step 1: Pin the new shas and build the image**

```sh
# Look up the current sha256 of each release asset, then:
export CAPA_SHA256=...  FLOSS_SHA256=...  DIE_DEB_SHA256=...
sh deploy/build.sh
```
Expected: build completes; the import-check `RUN` lines pass (this proves the pip set + Triton resolve together). If `import triton` fails, switch to the builder-stage source build per the `python-tools.txt` note and rebuild.

- [ ] **Step 2: Smoke-test the image offline**

```sh
docker run --rm --network none \
  --entrypoint sh vibe-reverse:latest /opt/vibe-reverse/bin/smoke.sh
```
Expected: `PASS: smoke.sh` (incl. the new `capa/floss/yara/diec` + python-lib lines).

- [ ] **Step 3: Record the resolved pins**

Edit `requirements/python-tools.txt` to replace the "pin exact versions once…" note with the exact `==` versions the successful build resolved (run `docker run --rm --entrypoint pip vibe-reverse:latest freeze | grep -iE 'capstone|unicorn|keystone|lief|pefile|pyelftools|yara|r2pipe|pwntools|miasm|qiling|speakeasy|triton'`). Commit.

- [ ] **Step 4: Update `AGENTS.md` deployment notes**

In "Deployment notes (hard-won — don't regress)", add bullets:
- capa + FLOSS are baked as **standalone Linux binaries** (staged in the builder, `install`-ed to `/usr/local/bin`) — never pip, to keep vivisect out of angr's resolution.
- Detect-It-Easy ships as a Debian `.deb` (`diec` CLI), installed like `radare2.deb`.
- `yara` is from apt; the rest (capstone/unicorn/keystone/lief/pefile/pyelftools/miasm/qiling/pwntools/speakeasy/triton) install globally via `python-tools.txt`; the build's `import` check is the gate.
- Triton is the integration risk: prefer the `triton-library` wheel; fall back to a builder-stage source build if no wheel resolves.

- [ ] **Step 5: Commit**

```sh
git add AGENTS.md requirements/python-tools.txt
git commit -m "Plan2-2 T5: verified image build + smoke; pin resolved versions; deployment notes"
```

---

## Self-Review (author's check against the spec)

- **Spec coverage (Plan 2 slice):** Python libs §7.1 ✓ (T1, T5 pins); standalone binaries §7.2 ✓ (T2 capa/FLOSS/DIE); apt yara §7.3 ✓ (T2/T4); image/requirements mirror §7.4 ✓ (T4); import-check gate §7.1 ✓ (T2 Step 6); smoke assertions §8 ✓ (T3); Triton risk §13 ✓ (T1 note, T2 Step 6, T5 fallback).
- **Placeholders:** none that are open-ended — URLs are concrete examples, shas use the repo's fail-closed `${VAR:?}` guard (the same pattern as `GHIDRA_SHA256`), and version pinning is an explicit post-build step (T5), not a "TODO".
- **Type/name consistency:** build args `CAPA_URL/CAPA_SHA256/FLOSS_URL/FLOSS_SHA256/DIE_DEB_URL/DIE_DEB_SHA256` are declared in the Dockerfile (T3), set+passed in build.sh (T7), and grep-asserted in the test (T1); import names match package names (`pyelftools`→`elftools`, `yara-python`→`yara`, `keystone-engine`→`keystone`, `pwntools`→`pwn`, `triton-library`→`triton`) in both the Dockerfile check and smoke.sh.
```
