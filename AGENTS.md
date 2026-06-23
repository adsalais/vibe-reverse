# AGENTS.md

Operating guide for an agent working **on this repository** (developing and
maintaining the harness). For how the harness *runs* an investigation, read
`ARCHITECTURE.md`. This file is read by both Claude Code and opencode.

## What this repo is

Two things that ship together:

1. **A portable reverse-engineering skill family** (`skills/`) — 14 skills that
   pilot an RE investigation as a reviewed loop (`analyze → plan → human approves
   → execute → report`). Works identically in Claude Code and opencode (both read
   `~/.claude/skills/`). (v2 target: spine `reverse-engineering` / `re-planning` /
   `re-coding` / `re-continue`; phases `re-triage` / `re-static` /
   `re-deobfuscate` / `re-devirtualize` / `re-antianalysis` / `re-crypto` /
   `re-config` / `re-solve` / `re-dynamic` / `re-report`. `re-preflight` was removed.)
2. **`vibe-reverse`** (`deploy/`) — an air-gapped Docker deployment of those
   skills + RE tools + opencode for blue-team malware analysis. Malware detonates
   only inside a no-network microVM.

Authoritative docs: `README.md` (overview), `ARCHITECTURE.md` (full workflow &
design), `INSTALL.md` (install), `deploy/README.md` (deployment), and
`docs/superpowers/specs/` + `docs/superpowers/plans/` (design specs & build plans).

## Repo map

| Path | What |
|------|------|
| `skills/<name>/SKILL.md` | the 14 skills — orchestrator `reverse-engineering` (+ `new_session.sh`/`add_binary.sh`/`session_status.sh`) + `re-*` phases |
| `skills/<name>/*.sh`, `.../references/` | per-skill helper scripts + reference docs |
| `deploy/` | Dockerfile, `build`/`export`/`install` scripts, `vibe-reverse` launcher, microVM guest |
| `tests/scripts/` | deterministic sh + pytest tests (`tests/fixtures/` crackme1, `tests/scenarios/`) |
| `requirements/` | host/Docker install of RE tools; Python tools (angr/z3) via pip (venv on host, global in container) |
| `docs/reverse/` | investigation folders the harness writes (one per run) |
| `docs/superpowers/` | specs + implementation plans |

## Build & test

Run the deterministic suite — all must exit 0 (~15 checks, tool-optional):

```sh
for t in tests/scripts/test_*.sh; do sh "$t" || echo "FAILED: $t"; done
python3 -m pytest tests/scripts/ -q
```

Tests are **tool-optional**: when a tool (Ghidra/angr/z3/upx/ltrace) is absent they
skip or assert the graceful fallback. Don't write a test that *requires* a tool.

Build the air-gapped image (from the repo root; Ghidra/JDK shas are pinned inside
`build.sh`):

```sh
sh deploy/build.sh            # -> vibe-reverse:latest
```

Smoke-test the image offline (smoke runs as root via `--entrypoint sh`, which
bypasses the remap entrypoint — root already has a passwd entry):

```sh
docker run --rm --network none \
  --entrypoint sh vibe-reverse:latest /opt/vibe-reverse/bin/smoke.sh
```

`deploy/`, `install.sh`, and the `vibe-reverse` launcher are host-side — editing
them needs **no image rebuild**. Only `skills/`, `deploy/entrypoint.sh`,
`deploy/smoke.sh`, and the Dockerfile are baked.

## Conventions

**Skills** (`skills/<name>/SKILL.md`):
- Frontmatter `name` **==** the directory name, lowercase-hyphen; `description`
  starts with **"Use when …"** and lists trigger keywords.
- No mention of "claude" or "anthropic" — keep skills tool-neutral and portable
  (they must work in both Claude Code and opencode).
- **Air-gapped:** skills assume every tool is pre-installed; they never install
  anything. A missing tool is a path/usage problem.
- **Numbered choices:** when a skill asks the user to decide, present a numbered
  list ending "Which option?". Slow steps follow
  `skills/reverse-engineering/references/long-running-ops.md` (background + budget +
  ask-before-kill).

**Helper scripts** (`skills/*/*.sh`, `deploy/*.sh`):
- POSIX `sh` with `set -eu`. **Never execute the target** in a static/triage path.
- Heavy output → the investigation's `artifacts/`; print only a short summary
  (e.g. `engine:` / `output:` lines).
- Degrade gracefully when a tool is missing (e.g. Ghidra → radare2 → objdump).

**The investigation loop** (ARCHITECTURE.md §2/§6):
- Each session lives in the working dir as `vibe-reverse-<datetime>/<binary>/`
  (multiple binaries per session; a `STATE.md` cursor per binary; a session `index.md`).
  Each phase writes a reviewed plan there.
- `re-planning` runs a hypothesis loop and self-reviews (evidence / honesty / ranking /
  gate), escalating to an independent reviewer subagent when uncertain. **The human
  approves at each gate** — the loop proceeds on confident, reversible steps and stops on
  uncertain / irreversible / mandatory ones (running the target, a new binary, 🐢 steps).
- `re-report` is mandatory — write the report **even on a complete failure**.

**On-the-fly Python** (`re-coding`): test-first, with inline `# why` comments
aimed at a learner; runs in the global `python3` (the air-gapped image installs all
Python tools globally — no venv).

**Workflow & git**: follow the `superpowers` flow (brainstorm → write plan →
execute → finish). TDD, small frequent commits, DRY / YAGNI.necer reference claude as the co-author

## Deployment notes (hard-won — don't regress)

- Base image is **`python:3.12-slim-trixie`** (Debian 13 + CPython 3.12; angr is
  validated on 3.12, so we pin 3.12 rather than trixie's system 3.13).
- `radare2` + `upx` are **not** in Debian → installed from pinned GitHub
  releases. Pin **`angr==9.2.221`** (z3 arrives via angr).
- **capa + FLOSS** are baked as **standalone Linux binaries** (staged in the builder,
  `install`-ed to `/usr/local/bin`) — never pip, to keep vivisect out of angr's
  resolution. **Detect-It-Easy** ships as a Debian `.deb` (`diec` CLI), installed
  like `radare2.deb`. **`yara`** is from apt. The rest (capstone/keystone/unicorn/
  lief/pefile/pyelftools/miasm/qiling/pwntools/triton) install globally
  via `python-tools.txt`. **Triton** is the integration risk: prefer the
  `triton-library` wheel; fall back to a builder-stage source build if no wheel
  resolves. The build's `python -c 'import …'` check is the gate.
- Python tools install **globally** (`pip install`, no venv/uv — the python
  image's pip is not PEP-668 managed). The skills call `python3` directly (the v2
  refactor dropped the old `RE_HARNESS_VENV` fallback). The build runs
  `python -c 'import angr, z3, …'` so a broken install fails the build.
- **Never run `opencode` at build time** (it opens a TUI and hangs). The env vars
  `OPENCODE_DISABLE_MODELS_FETCH=1` + `OPENCODE_DISABLE_AUTOUPDATE=1` stop phone-home.
- **Ghidra 12.x** needs **JDK 21** — now Debian trixie's apt `openjdk-21-jdk` (a
  *full* JDK; it compiles `.java` scripts), **not** a staged JDK tarball. The
  decompiler is the Java GhidraScript `skills/re-static/DecompileExport.java`.
- The image bakes a **`vibe` user**; the entrypoint runs as root, remaps `vibe`
  onto the host uid/gid (`HOST_UID`/`HOST_GID` from the launcher), then drops to it
  with **`setpriv`**. This replaces the old world-writable `/etc/passwd` +
  `ensure-user.sh` shim. Locate opencode's dirs with `opencode debug paths`.

## Safety model (non-negotiable)

- Targets are analyzed **statically by default**; nothing runs on the host.
- Only analyze **authorized** artifacts (CTF / owned / authorized engagement); the
  harness records the authorization.
- In `vibe-reverse`, the container reaches the **internal LLM only**, and **malware
  detonates only in the no-network microVM** (`deploy/vmrun.sh`: `-nic none`,
  `-snapshot`) — never in the container. See `re-dynamic` and `deploy/README.md`.
