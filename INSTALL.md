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
`reverse-engineering`, `re-preflight`, `re-planning`, `re-scripting`.

> Note: opencode's bundled helper-file support (scripts/ inside a skill) is
> confirmed in source but undocumented — pin a known opencode version if relied on.

## External tools (radare2, Ghidra, angr, z3, …)

The skills are instructions; the RE tools install separately. See **`requirements/`**:

- `sh requirements/setup.sh` — install on your host. Python tools (angr, z3) go
  into a **venv** at `$RE_HARNESS_VENV` (default `~/.local/share/re-harness/venv`).
- or `requirements/Dockerfile` — a container with everything preinstalled.

`re-preflight` detects what's missing at runtime and writes per-investigation
`install.sh` / `Dockerfile.snippet`.
