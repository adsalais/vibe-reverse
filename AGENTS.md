# AGENTS.md

Operating guide for an agent working **on this repository** (developing and
maintaining the harness). For how the harness *runs* an investigation, read
`ARCHITECTURE.md`. This file is read by both Claude Code and opencode.

## What this repo is

Two things that ship together:

1. **A portable reverse-engineering skill family** (`skills/`) — 10 skills that
   pilot an RE investigation as a reviewed loop (`analyze → plan → human approves
   → execute → report`). Works identically in Claude Code and opencode (both read
   `~/.claude/skills/`).
2. **`vibe-reverse`** (`deploy/`) — an air-gapped Docker deployment of those
   skills + RE tools + opencode for blue-team malware analysis. Malware detonates
   only inside a no-network microVM.

Authoritative docs: `README.md` (overview), `ARCHITECTURE.md` (full workflow &
design), `INSTALL.md` (install), `deploy/README.md` (deployment), and
`docs/superpowers/specs/` + `docs/superpowers/plans/` (design specs & build plans).

## Repo map

| Path | What |
|------|------|
| `skills/<name>/SKILL.md` | the 10 skills — orchestrator `reverse-engineering` + `re-*` phases |
| `skills/<name>/*.sh`, `.../references/` | per-skill helper scripts + reference docs |
| `deploy/` | Dockerfile, `build`/`export`/`install` scripts, `vibe-reverse` launcher, microVM guest |
| `tests/scripts/` | deterministic sh + pytest tests (`tests/fixtures/` crackme1, `tests/scenarios/`) |
| `requirements/` | host/Docker install of RE tools; Python tools (angr/z3) in a uv venv |
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

Smoke-test the image offline, as a mapped uid (mirrors the real launcher):

```sh
docker run --rm --network none --user "$(id -u):$(id -g)" \
  --tmpfs /state:mode=1777 -e HOME=/state \
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

**Helper scripts** (`skills/*/*.sh`, `deploy/*.sh`):
- POSIX `sh` with `set -eu`. **Never execute the target** in a static/triage path.
- Heavy output → the investigation's `artifacts/`; print only a short summary
  (e.g. `engine:` / `output:` lines).
- Degrade gracefully when a tool is missing (e.g. Ghidra → radare2 → objdump).

**The investigation loop** (ARCHITECTURE.md §2/§6):
- Each phase writes a reviewed plan to `docs/reverse/<date>-<slug>/`.
- `re-planning` self-reviews (consistency / relevancy / evidence / scope), then
  escalates to an independent reviewer subagent. **The human approves each plan.**
- `re-report` is mandatory — write the report **even on a complete failure**.

**On-the-fly Python** (`re-scripting`): test-first, with inline `# why` comments
aimed at a learner; runs in the uv venv at `$RE_HARNESS_VENV`.

**Workflow & git**: follow the `superpowers` flow (brainstorm → write plan →
execute → finish). TDD, small frequent commits, DRY / YAGNI. End every commit
message with:

```
Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```

## Deployment notes (hard-won — don't regress)

- Base image is **`python:3.12-slim-bookworm`** (angr needs Python ≥ 3.12).
- `radare2` + `upx` are **not** in Debian bookworm → installed from pinned GitHub
  releases. Pin **`angr==9.2.221`** (z3 arrives via angr).
- **Never run `opencode` at build time** (it opens a TUI and hangs). The env vars
  `OPENCODE_DISABLE_MODELS_FETCH=1` + `OPENCODE_DISABLE_AUTOUPDATE=1` stop phone-home.
- **Ghidra 12.x** needs **JDK 21** (a staged Temurin tarball, not Debian's 17), a
  *full* JDK (it compiles `.java` scripts), and **Java** GhidraScripts — Jython was
  removed, so the decompiler is `skills/re-static/DecompileExport.java`.
- A docker **mapped uid has no `/etc/passwd` entry**, which breaks Ghidra
  (`user.home`) and angr (`getpass`). `deploy/ensure-user.sh` (sourced by the
  entrypoint and smoke) adds one. Locate opencode's dirs with `opencode debug paths`.

## Safety model (non-negotiable)

- Targets are analyzed **statically by default**; nothing runs on the host.
- Only analyze **authorized** artifacts (CTF / owned / authorized engagement); the
  harness records the authorization.
- In `vibe-reverse`, the container reaches the **internal LLM only**, and **malware
  detonates only in the no-network microVM** (`deploy/vmrun.sh`: `-nic none`,
  `-snapshot`) — never in the container. See `re-dynamic` and `deploy/README.md`.
