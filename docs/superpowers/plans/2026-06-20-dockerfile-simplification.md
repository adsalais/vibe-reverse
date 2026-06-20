# Dockerfile Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Simplify both container builds — newer Debian base with apt JDK 21, global pip (no uv/venv), a baked `vibe` user remapped to the host uid via `setpriv` — without weakening the air-gap deployment model.

**Architecture:** Unify both Dockerfiles on `python:3.12-slim-trixie` (Debian 13 + validated CPython 3.12). Java comes from Debian trixie's apt `openjdk-21-jdk`; Python tools install globally and are verified at build time. The deploy image bakes a `vibe` user; at runtime the entrypoint starts as root, remaps `vibe` onto the host's uid/gid, then drops to it with `setpriv`. This deletes the staged Temurin tarball, the `uv` venv, the world-writable `/etc/passwd` hack, and `ensure-user.sh`.

**Tech Stack:** Docker (multi-stage), Debian trixie, Python 3.12, angr/z3, Ghidra 12.x + OpenJDK 21, opencode, QEMU microVM, POSIX `sh`.

## Global Constraints

- Base image (both Dockerfiles): **`python:3.12-slim-trixie`**. Keep Python **3.12** (do not use trixie's system 3.13 — angr is validated on 3.12).
- Pin **`angr==9.2.221`** (brings z3 transitively). Do **not** add packages beyond the current pin unless the spec says so.
- **Air-gap:** everything is fetched at *build* time (internet host); the image runs with **no network**. Pinned downloads (Ghidra/radare2/upx/opencode) keep their URL+SHA build args.
- **Never run `opencode` at build time** (TUI hang). Keep `OPENCODE_DISABLE_MODELS_FETCH=1` + `OPENCODE_DISABLE_AUTOUPDATE=1`.
- Helper scripts are POSIX `sh` with `set -eu`. Degrade gracefully when a tool is absent.
- Every commit message ends with: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`
- `RE_HARNESS_VENV` is left **unset** in the container; the skills' `${RE_HARNESS_VENV:-…}/bin/python` fallback resolves to global `python3` (skills are unchanged).

## File Structure

| File | Responsibility | Task |
|------|----------------|------|
| `requirements/Dockerfile` | standalone dev image: trixie base, global pip | 1 |
| `requirements/setup.sh` | host install: stdlib venv (no uv) | 1 |
| `requirements/README.md` | doc: global-in-container / venv-on-host | 1 |
| `tests/scripts/test_requirements.sh` | guard for the requirements/ artifacts | 1 |
| `deploy/Dockerfile` | air-gap image: trixie, apt JDK 21, global pip, vibe user | 2 |
| `deploy/build.sh` | build args (drop Temurin) | 2 |
| `tests/scripts/test_deploy_image.sh` | **new** static guard for deploy/ artifacts | 2, 3 |
| `deploy/entrypoint.sh` | root → remap vibe → setpriv drop | 3 |
| `deploy/ensure-user.sh` | **deleted** | 3 |
| `deploy/smoke.sh` | in-image checks (global python, vibe/setpriv) | 3 |
| `deploy/vibe-reverse` | launcher: HOST_UID/GID, no --user/--tmpfs | 4 |
| `tests/scripts/test_launcher_print.sh` | guard for launcher --print | 4 |
| `skills/re-preflight/preflight.sh` | install hints (pip, not uv) | 5 |
| `AGENTS.md` | deployment notes + smoke command | 5 |

---

### Task 1: requirements/ side — trixie base, global pip in container, stdlib venv on host

**Files:**
- Modify: `requirements/Dockerfile`
- Modify: `requirements/setup.sh`
- Modify: `requirements/README.md`
- Test: `tests/scripts/test_requirements.sh` (rewrite)

**Interfaces:**
- Produces: the requirements/ install convention (global pip in the container image; `python3 -m venv` at `$RE_HARNESS_VENV` on the host). No symbols other tasks consume.

- [ ] **Step 1: Rewrite the test to assert the new convention (failing first)**

Replace the entire contents of `tests/scripts/test_requirements.sh` with:

```sh
#!/usr/bin/env sh
# Validates the requirements/ install artifacts: global pip in the container
# image, a stdlib venv on the host — no uv anywhere.
set -eu
fail() { echo "FAIL: $1" >&2; exit 1; }

# python-tools.txt lists the expected tools
[ -s requirements/python-tools.txt ] || fail "python-tools.txt missing/empty"
grep -qi 'z3'   requirements/python-tools.txt || fail "python-tools.txt missing z3"
grep -qi 'angr' requirements/python-tools.txt || fail "python-tools.txt missing angr"

# setup.sh: valid POSIX sh, uses a stdlib venv + the venv var, and NO uv
sh -n requirements/setup.sh || fail "setup.sh syntax error"
grep -q 'python3 -m venv' requirements/setup.sh || fail "setup.sh missing 'python3 -m venv'"
grep -q 'RE_HARNESS_VENV' requirements/setup.sh || fail "setup.sh missing RE_HARNESS_VENV"
! grep -qw 'uv' requirements/setup.sh || fail "setup.sh still references uv"

# Dockerfile: python trixie base, global pip, build-time import check, NO uv
grep -Eq '^FROM python:3\.12-slim-trixie' requirements/Dockerfile || fail "Dockerfile base not python:3.12-slim-trixie"
grep -q 'pip install' requirements/Dockerfile     || fail "Dockerfile missing 'pip install'"
grep -q 'python-tools.txt' requirements/Dockerfile || fail "Dockerfile missing python-tools.txt"
grep -q 'import angr' requirements/Dockerfile      || fail "Dockerfile missing build-time import check"
! grep -qw 'uv' requirements/Dockerfile || fail "Dockerfile still references uv"

# the harness convention resolves a stdlib venv's python
ROOT="$(mktemp -d)"; V="$ROOT/venv"
if python3 -m venv "$V" >/dev/null 2>&1 && [ -x "$V/bin/python" ]; then
  PY=$(RE_HARNESS_VENV="$V" sh -c 'V="${RE_HARNESS_VENV:-$HOME/.local/share/re-harness/venv}"; if [ -x "$V/bin/python" ]; then echo "$V/bin/python"; else echo python3; fi')
  [ "$PY" = "$V/bin/python" ] || fail "venv-python resolution did not pick the venv"
else
  echo "(python venv unavailable — skipped live venv check)"
fi
rm -rf "$ROOT"

echo "PASS: test_requirements.sh"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `sh tests/scripts/test_requirements.sh`
Expected: FAIL (current `setup.sh`/`Dockerfile` still use `uv`) — e.g. `FAIL: setup.sh missing 'python3 -m venv'` or `FAIL: Dockerfile base not python:3.12-slim-trixie`.

- [ ] **Step 3: Rewrite `requirements/Dockerfile`**

Replace the entire contents with:

```dockerfile
# RE harness — all external tools, containerized.
# Build:  docker build -f requirements/Dockerfile -t re-harness .
# Use:    docker run --rm -it -v "$PWD:/work" re-harness
# Base: python:3.12-slim-trixie (Debian 13 + CPython 3.12). pip installs globally
# (this image's pip is not PEP-668 externally-managed — no venv, no uv).
FROM python:3.12-slim-trixie

# 1) system tools (Debian trixie apt)
RUN apt-get update && apt-get install -y --no-install-recommends \
        file binutils binwalk radare2 gdb ltrace strace upx-ucl xxd \
        ca-certificates curl git \
    && rm -rf /var/lib/apt/lists/*

# 2) python tools, installed GLOBALLY; the build fails if anything is missing
COPY requirements/python-tools.txt /tmp/python-tools.txt
RUN pip install --no-cache-dir -r /tmp/python-tools.txt \
 && python -c 'import angr, z3' \
 && rm -f /tmp/python-tools.txt

# 3) Ghidra (optional — large; uncomment to bake it in)
# RUN apt-get update && apt-get install -y --no-install-recommends openjdk-21-jdk unzip wget \
#     && wget -O /tmp/ghidra.zip <release-url-from-github> \
#     && unzip -q /tmp/ghidra.zip -d /opt && rm /tmp/ghidra.zip
# ENV PATH="/opt/ghidra_VER/support:$PATH"

WORKDIR /work
```

- [ ] **Step 4: Rewrite `requirements/setup.sh`**

Replace the entire contents with:

```sh
#!/usr/bin/env sh
# setup.sh — install every external tool the RE harness uses.
#   * system tools via your OS package manager (apt or brew), best-effort
#   * Python tools (angr, z3, ...) into a stdlib venv at $RE_HARNESS_VENV
# Idempotent; safe to re-run. Review before running — it installs software.
set -eu

DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
VENV="${RE_HARNESS_VENV:-$HOME/.local/share/re-harness/venv}"

echo "==> system tools"
SYS_APT="file binutils binwalk radare2 gdb ltrace strace upx-ucl xxd"
SYS_BREW="binutils binwalk radare2 gdb upx"   # macOS: ltrace/strace/xxd differ or are built-in
if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update && sudo apt-get install -y $SYS_APT
elif command -v brew >/dev/null 2>&1; then
  brew install $SYS_BREW || true
else
  echo "  no apt/brew detected — install these yourself: $SYS_APT" >&2
fi

echo "==> python tools in a venv ($VENV)"
python3 -m venv "$VENV"
"$VENV/bin/pip" install --upgrade pip
"$VENV/bin/pip" install -r "$DIR/python-tools.txt"

echo "==> Ghidra (manual — large; not auto-installed)"
cat <<'GHIDRA'
  1) install a JDK 21:   sudo apt-get install -y openjdk-21-jdk unzip wget
                         (macOS: brew install openjdk@21)
  2) download:           https://github.com/NationalSecurityAgency/ghidra/releases
  3) unzip and add ghidra_*/support to PATH (provides analyzeHeadless)
GHIDRA

cat <<EOF

Done.
  Python tools: $VENV/bin/python  (angr, z3, ...)
  The harness auto-uses this venv. If you chose a custom path, add to your shell rc:
      export RE_HARNESS_VENV="$VENV"
EOF
```

- [ ] **Step 5: Update `requirements/README.md`**

Open `requirements/README.md`. Replace any mention of a "uv-managed venv" with the new convention. Specifically:
- Line ~12: change `**uv-managed venv** at `$RE_HARNESS_VENV` …` to `**stdlib `python3 -m venv`** at `$RE_HARNESS_VENV` (default `~/.local/share/re-harness/venv`); the container image installs the same tools **globally** (no venv).`
- Line ~28: keep the sentence that the harness runs them via `"$RE_HARNESS_VENV/bin/python"`, but drop the `(or `uv run`)` clause.
- Remove any other `uv` references.

Verify no `uv` remains: `! grep -qw uv requirements/README.md && echo clean`

- [ ] **Step 6: Run the test to verify it passes**

Run: `sh tests/scripts/test_requirements.sh`
Expected: `PASS: test_requirements.sh`

- [ ] **Step 7: Commit**

```bash
git add requirements/Dockerfile requirements/setup.sh requirements/README.md tests/scripts/test_requirements.sh
git commit -m "$(printf 'requirements: trixie base + global pip in container, stdlib venv on host\n\nDrop uv from the standalone dev image and the host installer; verify the\nbuild with an import check. Update test_requirements.sh assertions.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

### Task 2: deploy/Dockerfile + build.sh — trixie, apt JDK 21, global pip, vibe user

**Files:**
- Modify: `deploy/Dockerfile`
- Modify: `deploy/build.sh`
- Test: `tests/scripts/test_deploy_image.sh` (create)

**Interfaces:**
- Produces:
  - Image runs as **root** by default (no `USER`); entrypoint is `/opt/vibe-reverse/bin/entrypoint.sh` (rewritten in Task 3).
  - Baked user `vibe` (uid/gid 1000), HOME `/home/vibe`, opencode at `/home/vibe/.opencode/bin/opencode`.
  - ENV: `HOME=/home/vibe`, `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64`, no `RE_HARNESS_VENV`.
  - `build.sh` no longer passes `TEMURIN_URL`/`TEMURIN_SHA256` build args.

- [ ] **Step 1: Create the static guard test (failing first)**

Create `tests/scripts/test_deploy_image.sh`:

```sh
#!/usr/bin/env sh
# Static checks on the deploy/ image build artifacts (no docker required).
set -eu
fail() { echo "FAIL: $1" >&2; exit 1; }
D=deploy/Dockerfile

# base image is the python trixie image
grep -Eq '^FROM python:3\.12-slim-trixie' "$D" || fail "Dockerfile base is not python:3.12-slim-trixie"
# Java from apt (full JDK 21), not a staged Temurin tarball
grep -q 'openjdk-21-jdk' "$D" || fail "Dockerfile does not apt-install openjdk-21-jdk"
! grep -qi 'temurin' "$D" || fail "Dockerfile still references Temurin"
! grep -q  'jdk21'   "$D" || fail "Dockerfile still references staged jdk21"
# python installed globally, no uv / no venv, verified by an import
grep -q 'pip install' "$D" || fail "Dockerfile missing global pip install"
! grep -qw 'uv' "$D" || fail "Dockerfile still references uv"
grep -q 'import angr' "$D" || fail "Dockerfile missing build-time import check"
# the baked vibe user; no world-writable passwd hack
grep -q 'useradd' "$D" || fail "Dockerfile does not create the vibe user"
! grep -q '0666 /etc/passwd' "$D" || fail "Dockerfile still chmods /etc/passwd world-writable"
# privilege-drop + identity tooling installed
grep -q 'setpriv\|util-linux' "$D" || fail "Dockerfile does not ensure setpriv/util-linux"

# build.sh no longer passes Temurin build args
! grep -qi 'temurin' deploy/build.sh || fail "build.sh still references Temurin"

echo "PASS: test_deploy_image.sh"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `sh tests/scripts/test_deploy_image.sh`
Expected: FAIL `Dockerfile base is not python:3.12-slim-trixie` (current base is bookworm).

- [ ] **Step 3: Rewrite `deploy/Dockerfile`**

Replace the entire contents with:

```dockerfile
# syntax=docker/dockerfile:1
# vibe-reverse — air-gapped RE / malware-analysis image.
# Base: python:3.12-slim-trixie (Debian 13 + CPython 3.12, validated for angr).
# Java for Ghidra is Debian trixie's apt openjdk-21-jdk (full JDK, has javac for
# Ghidra's .java GhidraScripts). Python tools install globally (this image's pip
# is not PEP-668 externally-managed). A baked 'vibe' user is remapped to the host
# uid at runtime by the entrypoint (setpriv), so reports in /work stay owned by you.
# ----------------------------- builder -----------------------------
FROM python:3.12-slim-trixie AS builder
ARG OPENCODE_VERSION
ARG GHIDRA_URL
ARG GHIDRA_SHA256
ARG RADARE2_DEB_URL
ARG UPX_URL
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl ca-certificates unzip xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Ghidra (URL + sha pinned via build args; see build.sh)
RUN curl -fsSL "$GHIDRA_URL" -o /tmp/ghidra.zip \
 && echo "${GHIDRA_SHA256}  /tmp/ghidra.zip" | sha256sum -c - \
 && unzip -q /tmp/ghidra.zip -d /opt \
 && mv /opt/ghidra_* /opt/ghidra \
 && rm /tmp/ghidra.zip

# radare2 (.deb) + upx (static binary) — newer than Debian's; staged for runtime.
RUN mkdir -p /opt/dl \
 && curl -fsSL "$RADARE2_DEB_URL" -o /opt/dl/radare2.deb \
 && curl -fsSL "$UPX_URL" -o /tmp/upx.tar.xz \
 && tar -C /tmp -xf /tmp/upx.tar.xz \
 && cp /tmp/upx-*-amd64_linux/upx /opt/dl/upx \
 && chmod +x /opt/dl/upx \
 && rm -rf /tmp/upx.tar.xz /tmp/upx-*

# opencode (pinned standalone binary) installed into a HOME we copy to the vibe
# user. NOT executed at build time (it opens a TUI and hangs).
ENV OPENCODE_DISABLE_MODELS_FETCH=1 OPENCODE_DISABLE_AUTOUPDATE=1
RUN mkdir -p /opt/opencode-home \
 && HOME=/opt/opencode-home sh -c 'curl -fsSL https://opencode.ai/install | VERSION="'"${OPENCODE_VERSION}"'" bash' \
 && test -x /opt/opencode-home/.opencode/bin/opencode

# ---- Linux detonation guest (kernel + initrd + rootfs.ext4) ----
RUN apt-get update && apt-get install -y --no-install-recommends \
      mmdebstrap fakechroot fakeroot e2fsprogs linux-image-amd64 \
    && rm -rf /var/lib/apt/lists/*
COPY deploy/guest/linux/detonate /tmp/detonate
COPY deploy/guest/linux/build-rootfs.sh /tmp/build-rootfs.sh
RUN set -eu; \
    KVER=$(basename /lib/modules/*); \
    mkdir -p /opt/vibe-reverse/guest; \
    cp /boot/vmlinuz-"$KVER"    /opt/vibe-reverse/guest/vmlinuz; \
    cp /boot/initrd.img-"$KVER" /opt/vibe-reverse/guest/initrd.img; \
    sh /tmp/build-rootfs.sh "$KVER" /opt/vibe-reverse/guest/rootfs.ext4

# ----------------------------- runtime -----------------------------
FROM python:3.12-slim-trixie AS runtime
# RE tools + Java (openjdk-21-jdk = full JDK with javac, for Ghidra's .java
# GhidraScripts) + the entrypoint's identity tools (passwd: usermod/groupmod/
# groupadd; util-linux: setpriv). radare2/upx are staged from the builder.
COPY --from=builder /opt/dl /opt/dl
RUN apt-get update && apt-get install -y --no-install-recommends \
      file binutils binwalk gdb ltrace strace xxd \
      qemu-system-x86 qemu-utils xorriso dosfstools mtools \
      ca-certificates openjdk-21-jdk passwd util-linux \
      /opt/dl/radare2.deb \
 && install -Dm755 /opt/dl/upx /usr/local/bin/upx \
 && test -x /usr/lib/jvm/java-21-openjdk-amd64/bin/java \
 && rm -rf /var/lib/apt/lists/* /opt/dl

# python tools, installed GLOBALLY (no venv, no uv). Verified at build time.
COPY requirements/python-tools.txt /tmp/python-tools.txt
RUN pip install --no-cache-dir -r /tmp/python-tools.txt \
 && python -c 'import angr, z3' \
 && rm -f /tmp/python-tools.txt

# the vibe user: a real identity (HOME + passwd entry). The entrypoint remaps its
# uid/gid to the host user's at runtime, then drops to it via setpriv.
RUN useradd --create-home --uid 1000 --user-group --shell /bin/sh vibe

# opencode "for the vibe user": staged from the builder into vibe's HOME.
COPY --from=builder --chown=vibe:vibe /opt/opencode-home/.opencode /home/vibe/.opencode

# baked artifacts
COPY --from=builder /opt/ghidra             /opt/ghidra
COPY --from=builder /opt/vibe-reverse/guest /opt/vibe-reverse/guest
COPY deploy/vmrun.sh                        /opt/vibe-reverse/bin/vmrun.sh

# the 10 skills + scripts
COPY skills/                /opt/vibe-reverse/skills/
COPY deploy/entrypoint.sh   /opt/vibe-reverse/bin/entrypoint.sh
COPY deploy/smoke.sh        /opt/vibe-reverse/bin/smoke.sh
RUN chmod +x /opt/vibe-reverse/bin/*.sh

# internal CA (placeholder-safe: register only if non-empty)
COPY deploy/ca.pem /tmp/ca.pem
RUN if [ -s /tmp/ca.pem ]; then \
      cp /tmp/ca.pem /usr/local/share/ca-certificates/internal-ca.crt && update-ca-certificates ; \
    fi ; rm -f /tmp/ca.pem

ENV HOME=/home/vibe \
    JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 \
    PATH="/opt/vibe-reverse/bin:/home/vibe/.opencode/bin:/opt/ghidra/support:/usr/lib/jvm/java-21-openjdk-amd64/bin:${PATH}" \
    OPENCODE_DISABLE_MODELS_FETCH=1 OPENCODE_DISABLE_AUTOUPDATE=1 \
    NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt \
    SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

WORKDIR /work
ENTRYPOINT ["/opt/vibe-reverse/bin/entrypoint.sh"]
```

> Note: the entrypoint it references is rewritten in Task 3. The build will still
> succeed here because the *current* entrypoint exists; the new identity model is
> wired in Task 3.

- [ ] **Step 4: Update `deploy/build.sh` — drop the Temurin block + build args**

In `deploy/build.sh`:
1. Delete the Temurin comment + the two assignments (the block beginning `# Temurin JDK 21 …` through the `TEMURIN_SHA256="${TEMURIN_SHA256:-…}"` line — currently lines ~21-25).
2. In the `docker build` invocation, delete these two lines:
   ```
     --build-arg TEMURIN_URL="$TEMURIN_URL" \
     --build-arg TEMURIN_SHA256="$TEMURIN_SHA256" \
   ```
3. Leave `OPENCODE_VERSION`, `GHIDRA_*`, `RADARE2_DEB_URL`, `UPX_URL` untouched.

Verify syntax: `sh -n deploy/build.sh && echo ok`

- [ ] **Step 5: Run the static guard test to verify it passes**

Run: `sh tests/scripts/test_deploy_image.sh`
Expected: `PASS: test_deploy_image.sh`

- [ ] **Step 6: Commit**

```bash
git add deploy/Dockerfile deploy/build.sh tests/scripts/test_deploy_image.sh
git commit -m "$(printf 'deploy/Dockerfile: trixie base, apt JDK 21, global pip, baked vibe user\n\nDrop the staged Temurin tarball (use apt openjdk-21-jdk), the uv venv\n(install globally + import check), and prepare a vibe user for the\nsetpriv remap entrypoint. Add test_deploy_image.sh static guard.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

### Task 3: entrypoint remap + delete ensure-user.sh + smoke update

**Files:**
- Modify: `deploy/entrypoint.sh` (rewrite)
- Delete: `deploy/ensure-user.sh`
- Modify: `deploy/smoke.sh`
- Test: `tests/scripts/test_deploy_image.sh` (extend)

**Interfaces:**
- Consumes (from launcher, Task 4): env `HOST_UID`, `HOST_GID` (default 1000 each if unset). Optional device `/dev/kvm`. Optional read-only `/cfg/auth.json`.
- Produces: process runs as the remapped `vibe` (host uid/gid) with `HOME=/home/vibe`; opencode launched via `setpriv` with `"$@"` forwarded.

- [ ] **Step 1: Extend the guard test (failing first)**

In `tests/scripts/test_deploy_image.sh`, insert the following block immediately **before** the final `echo "PASS: test_deploy_image.sh"` line:

```sh
# entrypoint: starts root, remaps vibe, drops via setpriv; ensure-user.sh is gone
E=deploy/entrypoint.sh
sh -n "$E" || fail "entrypoint.sh syntax error"
grep -q 'setpriv'  "$E" || fail "entrypoint.sh does not drop privileges via setpriv"
grep -q 'usermod'  "$E" || fail "entrypoint.sh does not remap the vibe uid"
grep -q 'HOST_UID' "$E" || fail "entrypoint.sh does not read HOST_UID"
[ ! -e deploy/ensure-user.sh ] || fail "deploy/ensure-user.sh should be deleted"
! grep -rq 'ensure-user' deploy/entrypoint.sh deploy/smoke.sh || fail "ensure-user still referenced"

# smoke: global python import (no venv path), checks vibe user + setpriv
S=deploy/smoke.sh
sh -n "$S" || fail "smoke.sh syntax error"
grep -q 'python3 -c' "$S"   || fail "smoke.sh not using global python3"
grep -q 'import z3, angr' "$S" || fail "smoke.sh missing angr/z3 import"
! grep -q '/opt/vibe-reverse/venv' "$S" || fail "smoke.sh still references the venv path"
```

Run: `sh tests/scripts/test_deploy_image.sh`
Expected: FAIL `entrypoint.sh does not drop privileges via setpriv` (current entrypoint still sources ensure-user.sh).

- [ ] **Step 2: Rewrite `deploy/entrypoint.sh`**

Replace the entire contents with:

```sh
#!/usr/bin/env sh
# entrypoint.sh — starts as root (the launcher does NOT pass --user). Remaps the
# baked 'vibe' user onto the host user (HOST_UID/HOST_GID), seeds opencode auth,
# then drops privileges to vibe via setpriv and launches opencode. Reports in
# /work end up owned by the host user; no world-writable /etc/passwd is needed.
set -eu

U="${HOST_UID:-1000}"
G="${HOST_GID:-1000}"

# remap vibe -> host uid/gid (-o: tolerate collisions with existing system ids)
[ "$(id -g vibe)" = "$G" ] || groupmod -o -g "$G" vibe
[ "$(id -u vibe)" = "$U" ] || usermod  -o -u "$U" vibe

# kvm: let the dropped user reach /dev/kvm (microVM). The host kvm GID is whatever
# owns the device; ensure a group with that GID exists and add vibe to it, so
# setpriv --init-groups picks it up after the drop.
if [ -e /dev/kvm ]; then
  KG=$(stat -c %g /dev/kvm)
  getent group "$KG" >/dev/null 2>&1 || groupadd -g "$KG" hostkvm
  usermod -aG "$KG" vibe
fi

# auth.json is mounted read-only at /cfg/auth.json; opencode needs it in its data
# dir (data resolves under $HOME=/home/vibe — see `opencode debug paths`).
DATA=/home/vibe/.local/share/opencode
mkdir -p "$DATA" /home/vibe/.cache/opencode /home/vibe/.config/opencode
if [ -f /cfg/auth.json ]; then
  cp /cfg/auth.json "$DATA/auth.json"
  chmod 600 "$DATA/auth.json" 2>/dev/null || true
fi

chown -R vibe:vibe /home/vibe

exec setpriv --reuid vibe --regid vibe --init-groups opencode "$@"
```

- [ ] **Step 3: Delete `deploy/ensure-user.sh`**

```bash
git rm deploy/ensure-user.sh
```

- [ ] **Step 4: Rewrite `deploy/smoke.sh`**

Replace the entire contents with:

```sh
#!/usr/bin/env sh
# smoke.sh — in-image checks. Run under network isolation, as root (the
# --entrypoint sh below bypasses the remap entrypoint; root already has a passwd
# entry, so the uid-sensitive checks pass):
#   docker run --rm --network none --entrypoint sh vibe-reverse:latest /opt/vibe-reverse/bin/smoke.sh
set -eu
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

# offline opencode env hardening present
[ "${OPENCODE_DISABLE_MODELS_FETCH:-}" = "1" ] || fail "OPENCODE_DISABLE_MODELS_FETCH not set"
[ "${OPENCODE_DISABLE_AUTOUPDATE:-}" = "1" ]  || fail "OPENCODE_DISABLE_AUTOUPDATE not set"
ok "offline env vars"

# opencode runs OFFLINE without hanging (this script runs with --network none).
# A hang on models.dev would trip the timeout (exit 124).
timeout 30 opencode --version >/dev/null 2>&1 || fail "opencode --version failed/hung offline (exit $?)"
ok "opencode --version offline"

# Ghidra headless on PATH, backed by a runnable JDK 21
command -v analyzeHeadless >/dev/null 2>&1 || fail "analyzeHeadless not on PATH"
"$JAVA_HOME/bin/java" -version >/dev/null 2>&1 || fail "JDK at JAVA_HOME not runnable"
ok "ghidra analyzeHeadless + JDK 21"

# python tools installed GLOBALLY (no venv): import angr + z3
python3 -c 'import z3, angr' 2>/dev/null || fail "global python cannot import z3/angr"
ok "global python z3+angr"

# QEMU present
command -v qemu-system-x86_64 >/dev/null 2>&1 || fail "qemu-system-x86_64 missing"
ok "qemu"

# baked identity: the vibe user + the privilege-drop tool
getent passwd vibe >/dev/null 2>&1 || fail "vibe user missing"
command -v setpriv >/dev/null 2>&1 || fail "setpriv missing"
ok "vibe user + setpriv"

# all 10 skills baked
n=$(ls -1d /opt/vibe-reverse/skills/*/ 2>/dev/null | wc -l)
[ "$n" -eq 10 ] || fail "expected 10 skills, found $n"
[ -f /opt/vibe-reverse/skills/reverse-engineering/SKILL.md ] || fail "orchestrator skill missing"
ok "10 skills baked"

# CA: if a real cert was baked, it must be in the trust store
if [ -s /usr/local/share/ca-certificates/internal-ca.crt ]; then
  grep -rqs . /etc/ssl/certs/ca-certificates.crt || fail "CA bundle empty"
  ok "internal CA registered"
else
  ok "no internal CA (placeholder) — skipped"
fi

# microVM guest + driver
for f in vmlinuz initrd.img rootfs.ext4; do
  [ -s "/opt/vibe-reverse/guest/$f" ] || fail "guest $f missing"
done
[ -x /opt/vibe-reverse/bin/vmrun.sh ] || fail "vmrun.sh missing"
ok "microVM guest + vmrun.sh"

for t in xorriso mkfs.vfat mcopy; do command -v "$t" >/dev/null 2>&1 || fail "windows-path tool missing: $t"; done
ok "windows-path tools (iso/fat/mtools)"

echo "PASS: smoke.sh"
```

- [ ] **Step 5: Run the guard test to verify it passes**

Run: `sh tests/scripts/test_deploy_image.sh`
Expected: `PASS: test_deploy_image.sh`

- [ ] **Step 6: Commit**

```bash
git add deploy/entrypoint.sh deploy/smoke.sh tests/scripts/test_deploy_image.sh
git commit -m "$(printf 'deploy: setpriv remap entrypoint; delete ensure-user.sh\n\nEntrypoint starts as root, remaps the vibe user onto HOST_UID/HOST_GID,\nadds it to the kvm device group, seeds auth, then drops via setpriv.\nRemoves the world-writable /etc/passwd shim. Smoke now imports angr/z3\nfrom the global python and checks the vibe user + setpriv.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

### Task 4: launcher — pass HOST_UID/HOST_GID, drop --user/--tmpfs

**Files:**
- Modify: `deploy/vibe-reverse`
- Test: `tests/scripts/test_launcher_print.sh`

**Interfaces:**
- Consumes: nothing new.
- Produces (to entrypoint, Task 3): env `HOST_UID=$(id -u)`, `HOST_GID=$(id -g)`; `--device /dev/kvm` when present; `tui.json` mounted at `/home/vibe/.config/opencode/tui.json`.

- [ ] **Step 1: Update the launcher test (failing first)**

In `tests/scripts/test_launcher_print.sh`, replace the required-substring loop (the `for s in …` line and its body) and the tui assertion. The new file body becomes:

```sh
#!/usr/bin/env sh
set -eu
L="deploy/vibe-reverse"
fail() { echo "FAIL: $1" >&2; exit 1; }
OUT=$(VIBE_CONFIG=/tmp/none sh "$L" --print) || fail "--print exited non-zero"
for s in "docker run" "--rm" "HOST_UID" "HOST_GID" "/work" "OPENCODE_CONFIG=/cfg/opencode.json" "vibe-reverse:latest"; do
  printf '%s' "$OUT" | grep -q -- "$s" || fail "missing: $s"
done
# the remap model replaces --user and the /state tmpfs
printf '%s' "$OUT" | grep -q -- "--user"     && fail "launcher still passes --user"
printf '%s' "$OUT" | grep -q -- "--tmpfs"     && fail "launcher still mounts a tmpfs"

# tui.json is mapped into opencode's config dir only when present in the config dir
if printf '%s' "$OUT" | grep -q "tui.json"; then fail "tui.json mapped when absent"; fi
TCFG="$(mktemp -d)"; trap 'rm -rf "$TCFG"' EXIT
echo '{}' > "$TCFG/tui.json"
OUT2=$(VIBE_CONFIG="$TCFG" sh "$L" --print) || fail "--print (tui.json) exited non-zero"
printf '%s' "$OUT2" | grep -q -- "$TCFG/tui.json:/home/vibe/.config/opencode/tui.json:ro" \
  || fail "tui.json not mapped to /home/vibe config dir"

echo "PASS: test_launcher_print.sh"
```

> Note: `grep -q -- "$s" && fail` is set -e safe — the grep is the left operand of `&&`, so a non-match (the pass case) does not trip `set -e`.

Run: `sh tests/scripts/test_launcher_print.sh`
Expected: FAIL `missing: HOST_UID` (current launcher passes `--user`, not HOST_UID).

- [ ] **Step 2: Rewrite `deploy/vibe-reverse`**

Replace the entire contents with:

```sh
#!/usr/bin/env sh
# vibe-reverse — launch the RE harness in the current folder (opencode TUI).
# Reports/plans are written here, owned by you: the container's entrypoint remaps
# its baked 'vibe' user onto your uid/gid (HOST_UID/HOST_GID) and drops to it.
# `vibe-reverse --print` shows the docker command without running it.
set -eu
IMAGE="${VIBE_IMAGE:-vibe-reverse:latest}"
CFG="${VIBE_CONFIG:-$HOME/.config/vibe-reverse}"
PRINT=0; [ "${1:-}" = --print ] && { PRINT=1; shift; }

set -- docker run --rm -it \
  -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
  -v "$PWD":/work -w /work \
  -v "$CFG":/cfg:ro \
  -e OPENCODE_CONFIG=/cfg/opencode.json
# microVM needs /dev/kvm; the entrypoint adds the dropped user to the device's group
[ -e /dev/kvm ] && set -- "$@" --device /dev/kvm
# optional guest images (e.g. windows.qcow2)
[ -d "$CFG/guests" ] && set -- "$@" -v "$CFG/guests":/guests:ro
# opencode TUI keybinds: map tui.json into opencode's config dir (HOME=/home/vibe,
# so config resolves to /home/vibe/.config/opencode).
[ -f "$CFG/tui.json" ] && set -- "$@" -v "$CFG/tui.json":/home/vibe/.config/opencode/tui.json:ro
set -- "$@" "$IMAGE"

if [ "$PRINT" = 1 ]; then printf '%s ' "$@"; echo; exit 0; fi
[ -f "$CFG/opencode.json" ] || { echo "no config at $CFG/opencode.json — run install.sh and edit it" >&2; exit 1; }
exec "$@"
```

- [ ] **Step 3: Run the launcher test to verify it passes**

Run: `sh tests/scripts/test_launcher_print.sh`
Expected: `PASS: test_launcher_print.sh`

- [ ] **Step 4: Confirm the install test still passes (launcher is installed verbatim)**

Run: `sh tests/scripts/test_install.sh`
Expected: `PASS: test_install.sh`

- [ ] **Step 5: Commit**

```bash
git add deploy/vibe-reverse tests/scripts/test_launcher_print.sh
git commit -m "$(printf 'deploy/vibe-reverse: pass HOST_UID/HOST_GID, drop --user and /state tmpfs\n\nThe entrypoint remap owns identity now, so the launcher just forwards the\nhost uid/gid and maps tui.json into /home/vibe config. Update the\n--print test for the new model.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

### Task 5: docs + preflight hints — pip, not uv

**Files:**
- Modify: `skills/re-preflight/preflight.sh`
- Modify: `AGENTS.md`

**Interfaces:** none (text/hints only).

- [ ] **Step 1: Update the install hints in `skills/re-preflight/preflight.sh`**

Find the line that emits the host install hint (contains `uv venv` and `uv pip install`) and replace it with:

```sh
  [ -n "$(echo "$MISS_PIP" | tr -d ' ')" ] && { echo '# python tools (venv — see requirements/setup.sh):'; echo "python3 -m venv \"$VENV\""; echo "\"$VENV/bin/pip\" install $MISS_PIP"; }
```

Find the line that emits the Dockerfile RUN hint (contains `uv pip install --python "$RE_HARNESS_VENV/bin/python"`) and replace it with:

```sh
  [ -n "$(echo "$MISS_PIP" | tr -d ' ')" ] && echo "RUN pip install $MISS_PIP   # see requirements/Dockerfile (global install)"
```

Verify no `uv` remains and syntax is valid:
```bash
sh -n skills/re-preflight/preflight.sh && ! grep -qw uv skills/re-preflight/preflight.sh && echo clean
```

- [ ] **Step 2: Run the preflight test to verify it still passes**

Run: `sh tests/scripts/test_preflight.sh`
Expected: `PASS: test_preflight.sh` (the generated `pip install` lines stay well-formed — a space follows `install`).

- [ ] **Step 3: Update the "Deployment notes" in `AGENTS.md`**

Replace the bullet list under `## Deployment notes (hard-won — don't regress)` with:

```markdown
- Base image is **`python:3.12-slim-trixie`** (Debian 13 + CPython 3.12; angr is
  validated on 3.12, so we pin 3.12 rather than trixie's system 3.13).
- `radare2` + `upx` are **not** in Debian → installed from pinned GitHub
  releases. Pin **`angr==9.2.221`** (z3 arrives via angr).
- Python tools install **globally** (`pip install`, no venv/uv — the python
  image's pip is not PEP-668 managed). `RE_HARNESS_VENV` is left **unset**, so the
  skills' `${RE_HARNESS_VENV:-…}/bin/python` fallback resolves to global `python3`.
  The build runs `python -c 'import angr, z3'` so a broken install fails the build.
- **Never run `opencode` at build time** (it opens a TUI and hangs). The env vars
  `OPENCODE_DISABLE_MODELS_FETCH=1` + `OPENCODE_DISABLE_AUTOUPDATE=1` stop phone-home.
- **Ghidra 12.x** needs **JDK 21** — now Debian trixie's apt `openjdk-21-jdk` (a
  *full* JDK; it compiles `.java` scripts), **not** a staged Temurin tarball. The
  decompiler is the Java GhidraScript `skills/re-static/DecompileExport.java`.
- The image bakes a **`vibe` user**; the entrypoint runs as root, remaps `vibe`
  onto the host uid/gid (`HOST_UID`/`HOST_GID` from the launcher), then drops to it
  with **`setpriv`**. This replaces the old world-writable `/etc/passwd` +
  `ensure-user.sh` shim. Locate opencode's dirs with `opencode debug paths`.
```

- [ ] **Step 4: Update the smoke-test command in `AGENTS.md`**

Replace the smoke block (the paragraph "Smoke-test the image offline, as a mapped uid …" plus its ```sh fenced command) with:

````markdown
Smoke-test the image offline (smoke runs as root via `--entrypoint sh`, which
bypasses the remap entrypoint — root already has a passwd entry):

```sh
docker run --rm --network none \
  --entrypoint sh vibe-reverse:latest /opt/vibe-reverse/bin/smoke.sh
```
````

- [ ] **Step 5: Commit**

```bash
git add skills/re-preflight/preflight.sh AGENTS.md
git commit -m "$(printf 'docs+preflight: global pip install (drop uv), trixie/JDK21/vibe notes\n\nUpdate preflight install hints to pip and refresh AGENTS deployment notes\nand the offline smoke command for the new base, Java, and user model.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

### Task 6: Integration — full suite + real build + offline smoke

**Files:** none (verification only).

> This task needs **docker + an internet-connected host** (the build fetches
> Ghidra/radare2/upx/opencode and trixie apt). Run it on the build host.

- [ ] **Step 1: Run the full deterministic suite**

Run:
```bash
for t in tests/scripts/test_*.sh; do sh "$t" || echo "FAILED: $t"; done
python3 -m pytest tests/scripts/ -q
```
Expected: every script prints `PASS: …`; no `FAILED:` lines; pytest green.

- [ ] **Step 2: Grep for stragglers (old artifacts fully removed)**

Run:
```bash
grep -rn 'ensure-user\|/opt/vibe-reverse/venv\|uv venv\|[Tt]emurin\|jdk21\|slim-bookworm' \
  deploy/ skills/ requirements/ tests/ AGENTS.md ARCHITECTURE.md INSTALL.md README.md 2>/dev/null || echo "clean"
```
Expected: `clean` (no matches). If `ARCHITECTURE.md`/`INSTALL.md` reference the venv path or Temurin, update those lines to match (global pip / apt JDK 21) and amend the Task 5 commit.

- [ ] **Step 3: Build the image**

Run: `sh deploy/build.sh`
Expected: builds `vibe-reverse:latest`; prints a size line. The build itself runs `python -c 'import angr, z3'` and `test -x …/java`, so a broken Python or JDK path fails here.

- [ ] **Step 4: Offline smoke as root (mirrors AGENTS.md)**

Run:
```bash
docker run --rm --network none \
  --entrypoint sh vibe-reverse:latest /opt/vibe-reverse/bin/smoke.sh
```
Expected: a series of `ok: …` lines ending in `PASS: smoke.sh`.

- [ ] **Step 5: Verify host-uid file ownership end-to-end (uid ≠ 1000 if possible)**

Run from a scratch case folder, faking a non-1000 host uid to prove the remap:
```bash
mkdir -p /tmp/case && cd /tmp/case
docker run --rm -e HOST_UID=4242 -e HOST_GID=4242 \
  -v "$PWD":/work -w /work --network none \
  --entrypoint sh vibe-reverse:latest -c 'umask 022; id; touch /work/owned-by-host; ls -n /work'
```
Expected: `id` shows `uid=4242 gid=4242`; `owned-by-host` is listed with numeric owner `4242 4242` — i.e. reports land owned by the host user, not uid 1000, with no world-writable `/etc/passwd` involved.

- [ ] **Step 6: Final commit (only if Step 2 required ARCHITECTURE/INSTALL edits)**

```bash
git add -A && git commit -m "$(printf 'docs: scrub remaining venv/Temurin references for trixie+global-pip\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>')"
```

---

## Self-Review

**Spec coverage:**
- Ask 1 (recent Debian + Java): Task 1 (requirements) + Task 2 (deploy) — `python:3.12-slim-trixie` + apt `openjdk-21-jdk`, Temurin removed. ✅
- Ask 2 (remove uv, global install): Task 1 + Task 2 — global `pip install`, uv/venv removed; host keeps a stdlib venv (spec decision). ✅
- Ask 3 (packages properly installed): build-time `python -c 'import angr, z3'` in both Dockerfiles (Tasks 1, 2); smoke import (Task 3); Step 3/4 of Task 6 run it for real. ✅
- Ask 4 (proper user, opencode for user, host mapping): Task 2 (vibe user + opencode in `/home/vibe/.opencode`), Task 3 (setpriv remap entrypoint, delete ensure-user.sh), Task 4 (launcher HOST_UID/HOST_GID). ✅
- Ripple updates (smoke, preflight, requirements docs, tests, AGENTS): Tasks 1, 3, 4, 5. ✅
- kvm-group-after-drop nuance (spec): Task 3 entrypoint derives the device GID and adds vibe before the `--init-groups` drop. ✅
- passwd/util-linux presence (spec): Task 2 apt-installs `passwd util-linux` + the test asserts setpriv/util-linux. ✅

**Placeholder scan:** No TBD/TODO; every code step shows full file or exact replacement text; no "add error handling" hand-waves. ✅

**Type/name consistency:** `HOST_UID`/`HOST_GID` (launcher → entrypoint), `vibe` user, `/home/vibe/.opencode/bin`, `/home/vibe/.config/opencode/tui.json`, `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64`, and `setpriv --reuid vibe --regid vibe --init-groups` are used identically across Tasks 2–5 and the tests. ✅
```
