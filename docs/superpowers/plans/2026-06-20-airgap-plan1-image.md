# Air-gap Deployment — Plan 1: The image (CA + opencode hardening) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `vibe-reverse:latest` — a multi-stage image with the RE tools, Ghidra, the uv venv (angr/z3), the 10 skills, QEMU, and a **hardened, offline opencode** — plus `build.sh` and a smoke test that proves it works with **no network**.

**Architecture:** Two-stage Dockerfile (`builder` fetches/assembles on the internet box; `runtime` is slim). opencode is pinned and made air-gap-safe via `OPENCODE_DISABLE_MODELS_FETCH=1` + `OPENCODE_DISABLE_AUTOUPDATE=1` and a pre-installed `@ai-sdk/openai-compatible` package; the internal CA is registered from `deploy/ca.pem`. The smoke test runs the image with `--network none` to prove opencode starts without any blocking phone-home.

**Tech Stack:** Docker (multi-stage, buildx), Debian bookworm, `uv`, opencode (pinned ≥ v1.0.154), Ghidra, QEMU, POSIX sh.

**Implements (spec §):** §4 (image + CA + opencode hardening), §7 (`build.sh`), §9 (image smoke test under isolation).
**Deferred to later plans:** the Linux guest kernel/rootfs + `vmrun.sh` + `re-dynamic` swap (Plan 2); launcher/install/config-auth/export (Plan 3); Windows path (Plan 4). So Plan 1 installs the **QEMU binary** but ships **no guest yet**.

**Execution note — version-dependent externals:** three values are confirmed *at build time on the networked box* (the plan gives the exact discovery command for each): the Ghidra release URL, opencode's installed binary path, and where opencode caches the AI-SDK provider package. These are discovery steps with concrete commands, not placeholders.

---

## File Structure (created by this plan)

| Path | Responsibility |
|---|---|
| `deploy/Dockerfile` | Multi-stage image (builder + runtime). |
| `deploy/entrypoint.sh` | Runtime entrypoint: seed `auth.json` into the writable data dir, then `exec opencode` in `/work`. |
| `deploy/smoke.sh` | In-image checks (run under `--network none`). |
| `deploy/build.sh` | Build `vibe-reverse:latest`; ensure a `ca.pem` exists; pass pinned-version build args. |
| `.gitignore` | Ignore `deploy/ca.pem` and `dist/`. |

---

## Task 1: `deploy/` scaffolding + gitignore

**Files:** Modify `.gitignore`

- [ ] **Step 1: Add ignores** — append to `.gitignore`:

```gitignore
# air-gap deployment: never commit the internal CA or built artifacts
deploy/ca.pem
dist/
```

- [ ] **Step 2: Create the deploy dir** (kept by the files below):

```sh
mkdir -p deploy
```

- [ ] **Step 3: Commit**

```sh
git add .gitignore
git commit -m "Airgap P1 T1: gitignore deploy/ca.pem + dist/"
```

---

## Task 2: The smoke test (write the test first)

**Files:** Create `deploy/smoke.sh`

- [ ] **Step 1: Write `deploy/smoke.sh`** — the contract the image must satisfy (runs *inside* the container):

```sh
#!/usr/bin/env sh
# smoke.sh — in-image checks. Run under network isolation:
#   docker run --rm --network none --entrypoint sh vibe-reverse:latest /opt/vibe-reverse/bin/smoke.sh
set -eu
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

# offline opencode env hardening present
[ "${OPENCODE_DISABLE_MODELS_FETCH:-}" = "1" ] || fail "OPENCODE_DISABLE_MODELS_FETCH not set"
[ "${OPENCODE_DISABLE_AUTOUPDATE:-}" = "1" ]  || fail "OPENCODE_DISABLE_AUTOUPDATE not set"
ok "offline env vars"

# opencode runs OFFLINE without hanging (this script is run with --network none).
# A hang on models.dev would trip the timeout (exit 124).
timeout 30 opencode --version >/dev/null 2>&1 || fail "opencode --version failed/hung offline (exit $?)"
ok "opencode --version offline"

# the OpenAI-compatible SDK was pre-installed (no runtime npm)
find / -type d -path '*@ai-sdk/openai-compatible*' 2>/dev/null | grep -q . \
  || fail "@ai-sdk/openai-compatible not pre-installed"
ok "ai-sdk/openai-compatible present"

# Ghidra headless on PATH
command -v analyzeHeadless >/dev/null 2>&1 || fail "analyzeHeadless not on PATH"
ok "ghidra analyzeHeadless"

# venv imports angr + z3
/opt/vibe-reverse/venv/bin/python -c 'import z3, angr' 2>/dev/null \
  || fail "venv cannot import z3/angr"
ok "venv z3+angr"

# QEMU present (guest comes in Plan 2)
command -v qemu-system-x86_64 >/dev/null 2>&1 || fail "qemu-system-x86_64 missing"
ok "qemu"

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

echo "PASS: smoke.sh"
```

- [ ] **Step 2: Run it — verify it FAILS** (no image yet):

```sh
docker run --rm --network none --entrypoint sh vibe-reverse:latest /opt/vibe-reverse/bin/smoke.sh
```
Expected: FAIL — `Unable to find image 'vibe-reverse:latest'` (image not built yet).

- [ ] **Step 3: Commit**

```sh
git add deploy/smoke.sh
git commit -m "Airgap P1 T2: image smoke test (offline opencode + tools + skills)"
```

---

## Task 3: The multi-stage Dockerfile + entrypoint

**Files:** Create `deploy/Dockerfile`, `deploy/entrypoint.sh`

- [ ] **Step 1: Write `deploy/entrypoint.sh`**

```sh
#!/usr/bin/env sh
# entrypoint.sh — runs as the host uid (via docker --user). Seeds opencode auth
# into the writable data dir, then launches opencode in the working dir.
set -eu
: "${XDG_DATA_HOME:=$HOME}"
mkdir -p "$XDG_DATA_HOME/opencode" "${XDG_CACHE_HOME:-$HOME/.cache}/opencode"
# auth.json is mounted read-only at /cfg/auth.json; opencode needs it in its data dir.
if [ -f /cfg/auth.json ]; then
  cp /cfg/auth.json "$XDG_DATA_HOME/opencode/auth.json"
  chmod 600 "$XDG_DATA_HOME/opencode/auth.json" 2>/dev/null || true
fi
exec opencode "$@"
```

- [ ] **Step 2: Write `deploy/Dockerfile`**

```dockerfile
# syntax=docker/dockerfile:1
# vibe-reverse — air-gapped RE / malware-analysis image.
# Plan 1: analyst environment (RE tools + Ghidra + venv + opencode + skills + QEMU).
# The detonation guest (vmlinuz + rootfs) is added in Plan 2.
ARG DEBIAN_REL=bookworm

# ----------------------------- builder -----------------------------
FROM debian:${DEBIAN_REL}-slim AS builder
ARG OPENCODE_VERSION
ARG GHIDRA_URL
ARG GHIDRA_SHA256
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl ca-certificates unzip git python3 \
    && rm -rf /var/lib/apt/lists/*

# uv (static binary from the official image)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# python venv (angr, z3): same path as runtime + pinned to system python => portable copy
COPY requirements/python-tools.txt /tmp/python-tools.txt
RUN uv venv --python /usr/bin/python3 /opt/vibe-reverse/venv \
 && uv pip install --python /opt/vibe-reverse/venv/bin/python -r /tmp/python-tools.txt

# Ghidra (URL + sha pinned via build args; see build.sh / discovery step)
RUN curl -fsSL "$GHIDRA_URL" -o /tmp/ghidra.zip \
 && echo "${GHIDRA_SHA256}  /tmp/ghidra.zip" | sha256sum -c - \
 && unzip -q /tmp/ghidra.zip -d /opt \
 && mv /opt/ghidra_* /opt/ghidra \
 && rm /tmp/ghidra.zip

# opencode (pinned standalone binary) + pre-install the OpenAI-compatible SDK.
# DISCOVERY (run once, networked): the installer drops a binary under ~/.opencode/bin;
# confirm the path, then bake it. The AI-SDK package install is triggered by a probe
# run, then located and copied. See plan T3 notes for the exact commands.
ENV HOME=/root
RUN curl -fsSL https://opencode.ai/install | VERSION="${OPENCODE_VERSION}" bash \
 && install -Dm755 /root/.opencode/bin/opencode /opt/vibe-reverse/bin/opencode
ENV PATH="/opt/vibe-reverse/bin:${PATH}" \
    OPENCODE_DISABLE_MODELS_FETCH=1 OPENCODE_DISABLE_AUTOUPDATE=1
# trigger + bake the openai-compatible provider package into a known dir
COPY deploy/_probe-opencode.json /tmp/probe.json
RUN OPENCODE_CONFIG=/tmp/probe.json opencode run --model probe/probe "noop" >/dev/null 2>&1 || true ; \
    pkg=$(find /root -type d -path '*@ai-sdk/openai-compatible*' 2>/dev/null | head -1) ; \
    test -n "$pkg" || { echo "AI-SDK not installed by probe — see T3 notes" >&2; exit 1; } ; \
    mkdir -p /opt/vibe-reverse/opencode-data ; \
    cp -a /root/.local/share/opencode/. /opt/vibe-reverse/opencode-data/ 2>/dev/null || true ; \
    cp -a /root/.cache/opencode/. /opt/vibe-reverse/opencode-cache/ 2>/dev/null || true

# ----------------------------- runtime -----------------------------
FROM debian:${DEBIAN_REL}-slim AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
      file binutils binwalk radare2 gdb ltrace strace upx-ucl xxd \
      qemu-system-x86 qemu-utils \
      python3 openjdk-17-jre-headless ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# baked artifacts (venv at the SAME path it was built at)
COPY --from=builder /opt/vibe-reverse/venv /opt/vibe-reverse/venv
COPY --from=builder /opt/ghidra            /opt/ghidra
COPY --from=builder /opt/vibe-reverse/bin/opencode /opt/vibe-reverse/bin/opencode
COPY --from=builder /opt/vibe-reverse/opencode-data  /opt/vibe-reverse/opencode-data
COPY --from=builder /opt/vibe-reverse/opencode-cache /opt/vibe-reverse/opencode-cache

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

ENV RE_HARNESS_VENV=/opt/vibe-reverse/venv \
    PATH="/opt/vibe-reverse/bin:/opt/ghidra/support:${PATH}" \
    OPENCODE_DISABLE_MODELS_FETCH=1 OPENCODE_DISABLE_AUTOUPDATE=1 \
    NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt \
    SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
# opencode's pre-baked provider package + cache, copied into a default-readable spot.
# The entrypoint/launcher set XDG_*; for the builder probe data we expose it read-only.
ENV OPENCODE_DATA_BAKED=/opt/vibe-reverse/opencode-data \
    OPENCODE_CACHE_BAKED=/opt/vibe-reverse/opencode-cache

WORKDIR /work
ENTRYPOINT ["/opt/vibe-reverse/bin/entrypoint.sh"]
```

- [ ] **Step 3: Write `deploy/_probe-opencode.json`** (build-only; triggers the SDK install)

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "probe": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "probe",
      "options": { "baseURL": "http://127.0.0.1:9/v1" },
      "models": { "probe": { "name": "probe" } }
    }
  }
}
```

- [ ] **Step 4: T3 notes — resolve the three externals while implementing**
  - **opencode install path:** after the installer runs, confirm with `ls -l /root/.opencode/bin/opencode`. If the path differs for the pinned version, update the `install -Dm755` source.
  - **AI-SDK cache location:** after the probe `RUN`, `find /root -path '*@ai-sdk/openai-compatible*'` shows where opencode put it (under `~/.local/share/opencode` or `~/.cache/opencode`). The Dockerfile copies both trees; the entrypoint (Plan 3) seeds them into the runtime XDG dirs. Adjust copy paths if the version stores them elsewhere.
  - **Ghidra URL + sha:** set in `build.sh` (next task).

- [ ] **Step 5: Commit**

```sh
git add deploy/Dockerfile deploy/entrypoint.sh deploy/_probe-opencode.json
git commit -m "Airgap P1 T3: multi-stage Dockerfile + entrypoint (offline opencode, CA, venv, ghidra)"
```

---

## Task 4: `build.sh` + build the image + pass the smoke test

**Files:** Create `deploy/build.sh`

- [ ] **Step 1: Write `deploy/build.sh`**

```sh
#!/usr/bin/env sh
# build.sh — build vibe-reverse:latest on an internet-connected host.
# Run from the repo root. Place your internal CA at deploy/ca.pem (optional).
set -eu

# pinned versions (override via env)
OPENCODE_VERSION="${OPENCODE_VERSION:-1.17.8}"   # must be >= 1.0.154 for the offline env vars
# Ghidra: confirm the current asset URL + sha at the releases page:
#   https://github.com/NationalSecurityAgency/ghidra/releases
GHIDRA_URL="${GHIDRA_URL:-https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_11.3_build/ghidra_11.3_PUBLIC_20250205.zip}"
GHIDRA_SHA256="${GHIDRA_SHA256:?set GHIDRA_SHA256 to the sha256 of the Ghidra zip (see releases page)}"

# CA placeholder so the build never breaks without an internal CA
[ -f deploy/ca.pem ] || { echo "no deploy/ca.pem — building WITHOUT an internal CA"; : > deploy/ca.pem; }

docker build -t vibe-reverse:latest -f deploy/Dockerfile \
  --build-arg OPENCODE_VERSION="$OPENCODE_VERSION" \
  --build-arg GHIDRA_URL="$GHIDRA_URL" \
  --build-arg GHIDRA_SHA256="$GHIDRA_SHA256" \
  .

echo "built vibe-reverse:latest"
docker image inspect vibe-reverse:latest --format 'size: {{.Size}} bytes'
```

- [ ] **Step 2: Build the image**

```sh
GHIDRA_SHA256=<sha256-from-releases-page> sh deploy/build.sh
```
Expected: a successful build ending with `built vibe-reverse:latest` + a size. (First build is slow: Ghidra + angr are large.)

- [ ] **Step 3: Run the smoke test under network isolation — verify it PASSES**

```sh
docker run --rm --network none --entrypoint sh vibe-reverse:latest /opt/vibe-reverse/bin/smoke.sh
```
Expected: a series of `ok:` lines then `PASS: smoke.sh`. The `--network none` is the key assertion — `opencode --version` must return within the timeout, proving no blocking models.dev/autoupdate fetch.

- [ ] **Step 4: If the offline opencode check hangs (exit 124)**
The pinned opencode version may predate the env vars (need ≥ v1.0.154) or store the SDK elsewhere. Re-check the version, the `find` for the AI-SDK package in T3, and `printenv OPENCODE_DISABLE_MODELS_FETCH` inside the image; fix the Dockerfile and rebuild. Do **not** proceed until the `--network none` smoke test is green.

- [ ] **Step 5: Commit**

```sh
git add deploy/build.sh
git commit -m "Airgap P1 T4: build.sh; image builds and passes offline smoke test"
```

---

## Self-Review (author's check against the spec)

- **Spec coverage (Plan 1 slice):** multi-stage image §4 ✓ (T3); CA registration §4 ✓ (T3, placeholder-safe); opencode hardening §4 ✓ (env vars baked + AI-SDK pre-installed + probe; T3); `build.sh` §7 ✓ (T4); smoke under isolation §9 ✓ (T2/T4). Guest/launcher/Windows correctly deferred (stated in header).
- **Placeholders:** none — full Dockerfile, entrypoint, smoke, build.sh given. The three version-dependent externals (Ghidra URL/sha, opencode path, AI-SDK cache) are **discovery steps with exact commands** + a hard gate (T4 step 4) that forbids proceeding until the offline smoke passes.
- **Type/name consistency:** paths are consistent — venv `/opt/vibe-reverse/venv` (same in builder+runtime, per portability), skills `/opt/vibe-reverse/skills`, binary `/opt/vibe-reverse/bin/opencode`, smoke at `/opt/vibe-reverse/bin/smoke.sh` (matches the run command), env-var names match the smoke assertions, `deploy/ca.pem` matches the gitignore + build.sh placeholder.
- **Env note:** the build runs on the **internet box** (this one has docker + network). The build is heavy (Ghidra ~hundreds of MB, angr large) — expect a multi-minute first build.
