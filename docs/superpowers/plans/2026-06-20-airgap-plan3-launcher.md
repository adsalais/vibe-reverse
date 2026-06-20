# Air-gap Deployment — Plan 3: Launcher + install + export bundle — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** The daily-driver UX: a `vibe-reverse` launcher (run in a case folder → opencode TUI, files owned by you), an `install.sh` for the air-gapped host, sample opencode config/auth, and an `export.sh` that produces one sneakernet bundle.

**Architecture:** All POSIX shell around the existing image. The launcher `docker run`s with host-UID mapping, `/dev/kvm` (+ kvm group) for the microVM, the case folder as `/work`, and the config read-only at `/cfg` (opencode pinned via `OPENCODE_CONFIG`; the entrypoint seeds `auth.json` into the writable tmpfs). Everything is testable on the host (install skips `docker load` if the image tar is absent; export skips `docker save` under a test flag).

**Tech Stack:** POSIX sh, docker, gzip/tar, sha256sum.

**Implements (spec §):** §6 (launcher, install, config/auth), §7 (export bundle).
**Depends on:** Plan 1 image + Plan 2 entrypoint/microVM on `main`.
**Deferred:** Windows runbook `windows-guest.md` (Plan 4) — `export.sh` includes it only if present.

---

## File Structure

| Path | Responsibility |
|---|---|
| `deploy/vibe-reverse` | The launcher (→ `~/.local/bin`). `--print` echoes the docker command. |
| `deploy/config/opencode.json` | Sample OpenAI-compatible provider config + skills.paths. |
| `deploy/config/auth.json.sample` | Sample credential (`{"internal":{"type":"api","key":"…"}}`). |
| `deploy/install.sh` | Air-gapped host installer (load image, seed config/auth, install launcher). |
| `deploy/export.sh` | Build `dist/vibe-reverse-bundle.tgz`. |
| `deploy/README.md` | Deploy overview (build → export → install → run). |
| `tests/scripts/test_launcher_print.sh` | Launcher `--print` produces the right docker invocation. |
| `tests/scripts/test_install.sh` | `install.sh` seeds config/auth idempotently + installs the launcher (HOME overridden). |
| `tests/scripts/test_export.sh` | `export.sh` (save skipped) builds a bundle with the expected contents + SHA256SUMS. |

---

## Task 1: The launcher + its test

**Files:** Create `tests/scripts/test_launcher_print.sh`, `deploy/vibe-reverse`

- [ ] **Step 1: Write the failing test `tests/scripts/test_launcher_print.sh`**

```sh
#!/usr/bin/env sh
set -eu
L="deploy/vibe-reverse"
fail() { echo "FAIL: $1" >&2; exit 1; }
OUT=$(VIBE_CONFIG=/tmp/none sh "$L" --print) || fail "--print exited non-zero"
for s in "docker run" "--rm" "--user" "/work" "OPENCODE_CONFIG=/cfg/opencode.json" "--tmpfs /state" "vibe-reverse:latest"; do
  printf '%s' "$OUT" | grep -q -- "$s" || fail "missing: $s"
done
echo "PASS: test_launcher_print.sh"
```

- [ ] **Step 2: Run it — verify it FAILS** (launcher missing).

- [ ] **Step 3: Write `deploy/vibe-reverse`**

```sh
#!/usr/bin/env sh
# vibe-reverse — launch the RE harness in the current folder (opencode TUI).
# Reports/plans are written here, owned by you. `vibe-reverse --print` shows the
# docker command without running it.
set -eu
IMAGE="${VIBE_IMAGE:-vibe-reverse:latest}"
CFG="${VIBE_CONFIG:-$HOME/.config/vibe-reverse}"
PRINT=0; [ "${1:-}" = --print ] && { PRINT=1; shift; }

set -- docker run --rm -it \
  --user "$(id -u):$(id -g)" \
  -v "$PWD":/work -w /work \
  -v "$CFG":/cfg:ro \
  --tmpfs /state:mode=1777 \
  -e HOME=/state -e XDG_DATA_HOME=/state -e XDG_CACHE_HOME=/state \
  -e OPENCODE_CONFIG=/cfg/opencode.json
# microVM needs /dev/kvm + the kvm group for the mapped (non-root) user
if [ -e /dev/kvm ]; then
  set -- "$@" --device /dev/kvm
  KG=$(getent group kvm 2>/dev/null | cut -d: -f3 || true)
  [ -n "${KG:-}" ] && set -- "$@" --group-add "$KG"
fi
# optional guest images (e.g. windows.qcow2)
[ -d "$CFG/guests" ] && set -- "$@" -v "$CFG/guests":/guests:ro
set -- "$@" "$IMAGE"

if [ "$PRINT" = 1 ]; then printf '%s ' "$@"; echo; exit 0; fi
[ -f "$CFG/opencode.json" ] || { echo "no config at $CFG/opencode.json — run install.sh and edit it" >&2; exit 1; }
exec "$@"
```

- [ ] **Step 4: Run the test — verify it PASSES.** Eyeball: `sh deploy/vibe-reverse --print`.

- [ ] **Step 5: Commit**

```sh
git add deploy/vibe-reverse tests/scripts/test_launcher_print.sh
git commit -m "Airgap P3 T1: vibe-reverse launcher (host-UID, kvm, /work, OPENCODE_CONFIG) + --print test"
```

---

## Task 2: Config samples + install.sh + test

**Files:** Create `deploy/config/opencode.json`, `deploy/config/auth.json.sample`, `deploy/install.sh`, `tests/scripts/test_install.sh`

- [ ] **Step 1: Write `deploy/config/opencode.json`**

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

- [ ] **Step 2: Write `deploy/config/auth.json.sample`**

```json
{ "internal": { "type": "api", "key": "REPLACE-WITH-YOUR-BEARER-TOKEN" } }
```

- [ ] **Step 3: Write the failing test `tests/scripts/test_install.sh`**

```sh
#!/usr/bin/env sh
set -eu
fail() { echo "FAIL: $1" >&2; exit 1; }
H="$(mktemp -d)"; trap 'rm -rf "$H"' EXIT
# install.sh loads the image only if the tar is present; in this test it is not,
# so docker load is skipped and we exercise seeding + launcher install.
HOME="$H" sh deploy/install.sh >/dev/null 2>&1 || fail "install.sh failed"
[ -f "$H/.config/vibe-reverse/opencode.json" ] || fail "opencode.json not seeded"
[ -f "$H/.config/vibe-reverse/auth.json" ]     || fail "auth.json not seeded"
[ -x "$H/.local/bin/vibe-reverse" ]            || fail "launcher not installed"
# idempotent + no-clobber: user edit survives a second run
echo "EDITED" > "$H/.config/vibe-reverse/opencode.json"
HOME="$H" sh deploy/install.sh >/dev/null 2>&1 || fail "second install failed"
grep -q EDITED "$H/.config/vibe-reverse/opencode.json" || fail "config was clobbered"
echo "PASS: test_install.sh"
```

- [ ] **Step 4: Run it — verify it FAILS** (install.sh missing).

- [ ] **Step 5: Write `deploy/install.sh`**

```sh
#!/usr/bin/env sh
# install.sh — install the vibe-reverse harness on this (air-gapped) host.
# Run from the extracted bundle directory.
set -eu
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
CFG="$HOME/.config/vibe-reverse"
BIN="$HOME/.local/bin"
IMG_TAR="$HERE/vibe-reverse-image.tar.gz"

# 1. load the image (if present in the bundle)
if [ -f "$IMG_TAR" ]; then
  echo "loading image (large)..."; gunzip -c "$IMG_TAR" | docker load
else
  echo "note: $IMG_TAR not found — skipping 'docker load' (load the image separately)" >&2
fi

# 2. seed config + auth (NEVER clobber an existing file)
mkdir -p "$CFG/guests"
[ -f "$CFG/opencode.json" ] || cp "$HERE/config/opencode.json" "$CFG/opencode.json"
if [ ! -f "$CFG/auth.json" ]; then cp "$HERE/config/auth.json.sample" "$CFG/auth.json"; chmod 600 "$CFG/auth.json"; fi

# 3. install the launcher
mkdir -p "$BIN"
install -m 0755 "$HERE/vibe-reverse" "$BIN/vibe-reverse"

cat <<EOF

Installed.
  launcher: $BIN/vibe-reverse   (ensure $BIN is on your PATH)
  config:   $CFG/opencode.json  (set your internal LLM baseURL + model id)
  auth:     $CFG/auth.json      (set your bearer token; already chmod 600)
Then:  cd <case-folder> && vibe-reverse
EOF
```

- [ ] **Step 6: Run the test — verify it PASSES.**

- [ ] **Step 7: Commit**

```sh
git add deploy/config deploy/install.sh tests/scripts/test_install.sh
git commit -m "Airgap P3 T2: install.sh + sample opencode config/auth (idempotent, no-clobber)"
```

---

## Task 3: export.sh + test

**Files:** Create `deploy/export.sh`, `tests/scripts/test_export.sh`

- [ ] **Step 1: Write the failing test `tests/scripts/test_export.sh`**

```sh
#!/usr/bin/env sh
set -eu
fail() { echo "FAIL: $1" >&2; exit 1; }
D="$(mktemp -d)"; trap 'rm -rf "$D"' EXIT
# VIBE_SKIP_SAVE makes export write a placeholder instead of a 3GB docker save.
VIBE_SKIP_SAVE=1 sh deploy/export.sh "$D" >/dev/null 2>&1 || fail "export.sh failed"
B="$D/vibe-reverse-bundle.tgz"
[ -f "$B" ] || fail "bundle not produced"
LIST=$(tar tzf "$B")
for f in vibe-reverse-bundle/install.sh vibe-reverse-bundle/vibe-reverse vibe-reverse-bundle/config/opencode.json vibe-reverse-bundle/SHA256SUMS; do
  printf '%s' "$LIST" | grep -q "$f" || fail "bundle missing $f"
done
echo "PASS: test_export.sh"
```

- [ ] **Step 2: Run it — verify it FAILS** (export.sh missing).

- [ ] **Step 3: Write `deploy/export.sh`**

```sh
#!/usr/bin/env sh
# export.sh [DIST_DIR] — build one sneakernet bundle for the air-gapped network.
# Set VIBE_SKIP_SAVE=1 to skip the (large) docker save (used by tests).
set -eu
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
IMAGE="${VIBE_IMAGE:-vibe-reverse:latest}"
DIST="${1:-dist}"
STAGE="$DIST/vibe-reverse-bundle"
rm -rf "$STAGE"; mkdir -p "$STAGE/config"

if [ "${VIBE_SKIP_SAVE:-0}" = 1 ]; then
  echo "(VIBE_SKIP_SAVE) placeholder image tar" > "$STAGE/vibe-reverse-image.tar.gz"
else
  echo "saving image (large; minutes)..."; docker save "$IMAGE" | gzip > "$STAGE/vibe-reverse-image.tar.gz"
fi

cp "$HERE/install.sh" "$HERE/vibe-reverse" "$STAGE/"
cp "$HERE/config/opencode.json" "$HERE/config/auth.json.sample" "$STAGE/config/"
[ -f "$HERE/README.md" ] && cp "$HERE/README.md" "$STAGE/"
[ -f "$HERE/windows-guest.md" ] && cp "$HERE/windows-guest.md" "$STAGE/"   # Plan 4
( cd "$STAGE" && find . -type f ! -name SHA256SUMS | sort | xargs sha256sum > SHA256SUMS )
( cd "$DIST" && tar czf vibe-reverse-bundle.tgz vibe-reverse-bundle )
echo "bundle: $DIST/vibe-reverse-bundle.tgz"
</dev/null</dev/null>
```

(Note: drop the stray trailing redirect — the script ends at the `echo`. See T3 step 4.)

- [ ] **Step 4: Run the test — verify it PASSES.** Confirm `deploy/export.sh` ends cleanly at the final `echo` (no stray characters).

- [ ] **Step 5: Commit**

```sh
git add deploy/export.sh tests/scripts/test_export.sh
git commit -m "Airgap P3 T3: export.sh (single sneakernet bundle + SHA256SUMS)"
```

---

## Task 4: Deploy README + real launch sanity + merge

**Files:** Create `deploy/README.md`

- [ ] **Step 1: Write `deploy/README.md`** — build → export → install → run, in a few lines (point at the spec for detail).

- [ ] **Step 2: Full host suite**

```sh
for t in tests/scripts/*.sh; do sh "$t" >/dev/null 2>&1 && echo "ok $(basename $t)" || echo "FAIL $(basename $t)"; done
```
Expected: all `ok`, including the three new ones.

- [ ] **Step 3: Real launch sanity (container actually starts with the launcher's mounts)**

Seed a temp config and verify the entrypoint seeds auth + opencode runs, using the launcher's exact mounts but a non-interactive entrypoint:
```sh
T="$(mktemp -d)"; mkdir -p "$T/cfg"; cp deploy/config/opencode.json "$T/cfg/"; cp deploy/config/auth.json.sample "$T/cfg/auth.json"
docker run --rm --network none -v "$T/cfg":/cfg:ro --tmpfs /state:mode=1777 \
  -e HOME=/state -e XDG_DATA_HOME=/state -e XDG_CACHE_HOME=/state -e OPENCODE_CONFIG=/cfg/opencode.json \
  --entrypoint sh vibe-reverse:latest -c '/opt/vibe-reverse/bin/entrypoint.sh --version >/dev/null 2>&1; [ -f /state/opencode/auth.json ] && echo AUTH_SEEDED; opencode --version'
rm -rf "$T"
```
Expected: `AUTH_SEEDED` + an opencode version (entrypoint copied auth into the data dir; opencode runs offline).

- [ ] **Step 4: Commit, then merge** (finishing-a-development-branch): verify suite → `git checkout main && git merge <branch>` → re-verify → delete branch.

---

## Self-Review (author's check against the spec)

- **Spec coverage (Plan 3):** launcher §6 ✓ (T1, host-UID + kvm + `/work` + `OPENCODE_CONFIG` + tmpfs); install + config/auth §6 ✓ (T2, idempotent no-clobber); export bundle §7 ✓ (T3, single `.tgz` + SHA256SUMS). Windows runbook deferred to Plan 4 (export includes it if present).
- **Placeholders:** none — full launcher/install/export + config samples + three deterministic host tests + a real container launch sanity. (`export.sh` T3 step 3 has a deliberate "remove the stray trailing redirect" note — fix it when writing the file.)
- **Consistency:** `OPENCODE_CONFIG=/cfg/opencode.json` + `-v $CFG:/cfg:ro` + entrypoint copying `/cfg/auth.json` all align with Plan 1's entrypoint; provider id `internal` matches across config + auth; bundle paths in `export.sh` match what `install.sh` reads (`config/opencode.json`, `config/auth.json.sample`, `vibe-reverse`, `vibe-reverse-image.tar.gz`).
