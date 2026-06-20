# Dockerfile simplification — design

**Date:** 2026-06-20
**Status:** approved (brainstorming → ready for implementation plan)
**Targets:** `deploy/Dockerfile` (primary) + `requirements/Dockerfile` and the
scripts/docs/tests that reference the old uv venv and per-uid passwd hacks.

## Goal

Simplify the container builds while keeping the air-gap deployment model intact
(build on an internet host → ship one bundle → run offline). Four asks:

1. Newer Debian base that provides a recent Java for Ghidra (drop the staged
   Temurin JDK 21 tarball).
2. Remove `uv`; install Python packages globally (no venv).
3. Make sure all required Python packages are actually installed (verified).
4. Bake a proper named user, install opencode for that user, and map the host
   user onto it at runtime.

## Verified facts (research, 2026-06-20)

- Debian **trixie** (13, current stable) ships `openjdk-21-jdk` in apt — a *full*
  JDK with `javac`, which Ghidra needs to compile its `.java` GhidraScripts.
- `python:3.12-slim-trixie` exists (Debian 13 base, CPython 3.12 in `/usr/local`).
  Its `pip` is **not** PEP-668 "externally managed", so global `pip install`
  works with no `--break-system-packages` flag.
- Keeping Python **3.12** (not trixie's system 3.13) preserves the exact
  interpreter `angr==9.2.221` is already validated against. angr supports 3.10+,
  but 3.12 is the low-risk choice and matches the current image.
- `setpriv` (util-linux) is already present in the base image → privilege drop
  needs no extra pinned download (unlike `gosu`).

## Decisions

- **Base image (both Dockerfiles):** `python:3.12-slim-trixie`. One base, one
  mental model. Free global pip; Debian trixie underneath for apt JDK 21 + RE
  tools.
- **Java:** `apt-get install -y --no-install-recommends openjdk-21-jdk`. Delete
  the Temurin URL/SHA build args + staging block (and the 2 args in `build.sh`).
- **Python:** global `pip install -r requirements/python-tools.txt` (no uv, no
  venv, no `--break-system-packages`). Verified by a build-time import check.
- **`RE_HARNESS_VENV` stays unset in the container.** The skills already use
  `${RE_HARNESS_VENV:-…}/bin/python` with a fallback to `python3`; leaving it
  unset makes the fallback resolve to the global `python3`. The skill files need
  **no change**.
- **User model:** bake a `vibe` user (uid/gid 1000, real HOME `/home/vibe`),
  install opencode into `/home/vibe/.opencode/bin`. At runtime the container
  starts as root, remaps `vibe` to the host UID/GID, then drops to `vibe` via
  `setpriv`. (Chosen over a fixed-uid-1000 run because it keeps `/work` reports
  owned by the host user for *any* host UID, and removes the world-writable
  `/etc/passwd` hack.) Trade-off accepted: PID 1 briefly runs as root before
  dropping — malware never runs in the container (only in the no-network
  microVM), so the safety model is unchanged.

Accepted caveat: apt RE tools with a Python dependency (e.g. `gdb`) pull Debian's
apt `python3` (3.13) alongside the image's `/usr/local` 3.12. Cosmetic only — those
tools use their own embedded Python; `python`/`python3` on PATH is 3.12 where
angr/z3 live. This already exists in the deploy image and is not new.

## Changes by file

### `deploy/Dockerfile` (asks 1, 2, 3)

- `FROM python:3.12-slim-bookworm` → `python:3.12-slim-trixie` (both stages).
- **Delete** the Temurin block (builder) and the `COPY --from=builder /opt/jdk21`
  (runtime). Install Java in the runtime stage: `openjdk-21-jdk`.
- **Delete** `COPY --from=ghcr.io/astral-sh/uv:latest /uv …` and the `uv venv` /
  `uv pip install` lines. Replace with global `pip install -r
  /tmp/python-tools.txt`. Build the Python deps in the **runtime** stage (or a
  stage whose `/usr/local` is copied wholesale) so the global site-packages land
  in the final image.
- **Add** verification: `RUN python -c 'import angr, z3'` immediately after the
  install — the build fails loudly if anything is missing/broken (ask 3).
- ENV: `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64`; remove
  `RE_HARNESS_VENV`; PATH includes `/home/vibe/.opencode/bin` and
  `/opt/ghidra/support` and `/usr/lib/jvm/java-21-openjdk-amd64/bin`.
- **Delete** `RUN chmod 0666 /etc/passwd`.
- Create the `vibe` user (uid/gid 1000, HOME `/home/vibe`).
- Ensure the runtime-stage entrypoint's tools are present: `usermod`/`groupmod`/
  `groupadd` (apt `passwd`) and `setpriv` (apt `util-linux`). These are normally
  in the Debian base; the build must `apt-get install` them explicitly if the
  slim image omits any, so the remap entrypoint can't fail at runtime.
- opencode install: run the opencode installer with `HOME=/home/vibe` so the
  binary lands in `/home/vibe/.opencode/bin/opencode` ("for the user"). Keep
  `OPENCODE_DISABLE_MODELS_FETCH=1` / `OPENCODE_DISABLE_AUTOUPDATE=1`; never run
  opencode at build time.
- Multi-stage is **retained** — the microVM guest build (mmdebstrap, kernel) and
  the pinned downloads (Ghidra, radare2, upx) still justify it. It is now far
  leaner: no Temurin, no uv, no venv staging.

### `deploy/entrypoint.sh` (ask 4) — rewrite

Runs as root (no `--user` from the launcher):

1. `usermod -u "$HOST_UID" vibe` ; `groupmod -g "$HOST_GID" vibe`.
2. kvm: if `/dev/kvm` exists, read its GID (`stat -c %g`), ensure a group with
   that GID exists, add `vibe` to it — so the microVM works after the drop and
   the launcher no longer needs `--group-add`.
3. Seed `/cfg/auth.json` → opencode data dir (as today).
4. `chown -R vibe:vibe /home/vibe`.
5. `exec setpriv --reuid vibe --regid vibe --init-groups opencode "$@"`.

### `deploy/ensure-user.sh` — **delete**

No longer needed (real passwd entry + remap replace the runtime append).

### `deploy/vibe-reverse` (launcher, host-side) — ask 4

- Remove `--user "$(id -u):$(id -g)"`.
- Add `-e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)"`.
- Remove `--tmpfs /state` and the `-e HOME=/state -e XDG_DATA_HOME=… -e
  XDG_CACHE_HOME=…` lines (the baked `/home/vibe` HOME replaces `/state`).
- Keep `--device /dev/kvm`; **remove** the `--group-add "$KG"` logic (entrypoint
  derives the kvm group from the device).
- `tui.json` mount target: `/home/vibe/.config/opencode/tui.json` (was
  `/state/.config/opencode/tui.json`).
- Keep `-v "$CFG":/cfg:ro`, `OPENCODE_CONFIG=/cfg/opencode.json`, guests mount.

### `deploy/smoke.sh`

- Remove the `. /opt/vibe-reverse/bin/ensure-user.sh` line (file is deleted).
- Replace `/opt/vibe-reverse/venv/bin/python -c 'import z3, angr'` with
  `python3 -c 'import z3, angr'`.
- Smoke runs via `--entrypoint sh` (bypasses entrypoint) — run it as **root**
  (drop `--user` from the documented command); root has a passwd entry, so the
  uid-sensitive angr/Ghidra checks pass without the old shim.

### `skills/re-preflight/preflight.sh`

- Update the install-hint text: replace the `uv venv` / `uv pip install` hints
  (both the host hint and the `# see requirements/Dockerfile` RUN hint) with
  global `pip install` guidance. The skill's runtime python resolution is
  unchanged (falls back to `python3`).

### `requirements/Dockerfile` (asks 1–3, secondary)

- `FROM debian:stable-slim` → `python:3.12-slim-trixie`.
- Drop the `COPY --from=…/uv` + `uv venv` + `uv pip install`; use global
  `pip install -r /tmp/python-tools.txt` (no `--break-system-packages` needed on
  the python image). Add `RUN python -c 'import angr, z3'`.
- Remove `python3` from the apt list (the image provides Python); keep the RE
  tools (`file binutils binwalk radare2 gdb ltrace strace upx-ucl xxd …`).
- Remove the `RE_HARNESS_VENV` ENV + the venv PATH prepend.
- The optional Ghidra block comment: update the JDK hint to `openjdk-21-jdk`.

### `requirements/setup.sh` (host install, secondary)

- Drop `uv`. Use stdlib `python3 -m venv "$VENV"` then `"$VENV/bin/pip" install
  -r …`. **Host keeps a venv** — global pip on a developer host is undesirable
  (PEP 668 + pollutes system Python). "Global" applies to the container only.
- Update the Ghidra hint: JDK 17 → JDK 21.

### `requirements/README.md`

- Replace "uv-managed venv" wording with: container installs globally; host uses
  a stdlib `python3 -m venv`. Keep the `$RE_HARNESS_VENV` override note for the
  host path.

### `requirements/python-tools.txt`

- Unchanged. `angr==9.2.221` pins the whole stack (archinfo/pyvex/claripy/cle)
  and brings `z3` transitively. The build-time `import angr, z3` check is the
  "properly installed" guarantee (ask 3). Extra packages (capstone/pwntools) are
  **not** added unless requested.

### `tests/scripts/test_requirements.sh`

- Rewrite the assertions that grep for `uv`:
  - `setup.sh` must contain `python3 -m venv` and `RE_HARNESS_VENV` (no `uv`).
  - `requirements/Dockerfile` must be `FROM python:…-trixie`, contain
    `pip install`, the `python-tools.txt` reference, and the import check; must
    **not** contain `uv`.
- Keep the live-venv probe but build it with `python3 -m venv` instead of
  `uv venv` (still skip gracefully when offline / unavailable).

### `AGENTS.md`

- "Deployment notes": base is now `python:3.12-slim-trixie`; Java is apt
  `openjdk-21-jdk` (no staged Temurin); Python deps are global (no uv venv);
  the mapped-uid passwd shim is replaced by the `vibe` user + `setpriv` remap.
- Update the smoke-test command (drop `--user`, drop `/state` tmpfs).

## Out of scope

- No change to the skills' investigation logic, the microVM guest build, the
  Ghidra Java decompiler script, or the opencode offline hardening.
- No new Python packages beyond the current pin.

## Acceptance

- `sh deploy/build.sh` builds `vibe-reverse:latest` with no Temurin/uv build args.
- Offline smoke passes as root: `import z3, angr` via `python3`, `analyzeHeadless`
  on PATH, opencode `--version` offline, 10 skills, microVM guest present.
- `vibe-reverse` in a case folder writes reports owned by the host user (verified
  for a host uid ≠ 1000), with no world-writable `/etc/passwd` in the image.
- `for t in tests/scripts/test_*.sh; do sh "$t"; done` and `pytest tests/scripts/`
  pass with the rewritten `test_requirements.sh`.
