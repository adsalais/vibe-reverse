# Installing the RE harness

opencode (≥ v1.0.190) reads the **same `~/.claude/skills/` tree** as Claude Code,
so one install serves both. No manifest, no config — skills auto-load by their
`description`.

## Global (both agents)

From the cloned repo root, symlink (recommended for dev) each skill:

```sh
for d in skills/*/; do
  ln -s "$PWD/$d" "$HOME/.claude/skills/$(basename "$d")"
done
```

Or copy them instead: `cp -r skills/* ~/.claude/skills/`

## Per-project (committed to a repo)

Place skills under the repo's `.claude/skills/` (both agents read it) or the
tool-neutral `.agents/skills/`.

## opencode-native (optional)

`~/.config/opencode/skills/<name>/` (global) or `.opencode/skills/<name>/`
(project); or point opencode at any folder via `opencode.json`:

```json
{ "skills": { "paths": ["/abs/path/to/skills"] } }
```

## Verify

Ask your agent: *"list your reverse-engineering skills"* — you should see
`reverse-engineering`, `re-planning`, `re-coding`, `re-continue`, and the
`re-*` phase skills.

> Note: opencode's bundled helper-file support (scripts/ inside a skill) is
> confirmed in source but undocumented — pin a known opencode version if relied on.

## External tools (radare2, Ghidra, angr, z3, capa, FLOSS, …)

The skills are instructions; the RE tools install separately. The skills **assume
the tools are already present** (the air-gapped `vibe-reverse` image bakes them and
the agent never installs anything). To provide them yourself, see **`requirements/`**:

- `sh requirements/setup.sh` — install on your host (system tools + a Python venv).
- or `requirements/Dockerfile` — a container with everything preinstalled.
- the air-gapped appliance is `deploy/` (`sh deploy/build.sh`), which bakes every
  tool the skills call.

`rustc` is baked in for `re-coding`'s Rust path (std-only; no `cargo`/crates needed on
the air-gapped image).
