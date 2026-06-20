# Agent tool map & portability rules

These skills are agent-agnostic. Keep them portable:

| Concept | Claude Code | opencode |
|---|---|---|
| Run a skill | auto by `description`, or `/skill-name` | auto by `description` (no slash for skills) |
| Subagent | `Agent` tool | agent/subagent invocation |
| Shell | `Bash` | `bash` |
| Read/Write files | `Read`/`Write`/`Edit` | `read`/`write`/`edit` |

**Rules for every skill in this repo**

- Reference helper files by **relative path** (`preflight.sh`, `scripts/x.py`),
  never `${CLAUDE_SKILL_DIR}` (Claude-Code-only; inert elsewhere).
- The `description` is the portable discovery contract: third person, "Use
  when…", trigger keywords. ≤ 1024 chars.
- `name` = lowercase-alphanumeric-hyphen, ≤ 64 chars, **equal to the directory
  name**, no `anthropic`/`claude`/XML.
- Don't rely on `allowed-tools` to auto-grant bash; assume the agent must already
  permit it.
- Keep each `SKILL.md` < 500 lines; push detail into `references/`.
- Scripts: POSIX `sh` / `python3`, std-lib-first, non-interactive, `--help`-able.
