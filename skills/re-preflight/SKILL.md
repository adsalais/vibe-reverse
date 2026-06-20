---
name: re-preflight
description: Use when setting up reverse-engineering tooling or when an RE tool (Ghidra, radare2, binwalk, angr, z3, gdb) is missing or "command not found" — detects what is installed and writes copy-paste install.sh and a Dockerfile snippet without installing anything. Keywords: install RE tools, missing tool, environment setup, ghidra not found.
---

# re-preflight

## Core rule

**Detect and report only — never install anything.** The user stays in control of
their machine; you produce copy-paste artifacts and they decide what to run.

## Use it

From the investigation directory, run:

```sh
sh preflight.sh <investigation-dir>
```

It prints a `TOOL / FOUND / PURPOSE` table and writes two files into that dir:

- **`install.sh`** — OS-aware, commented install commands for the *missing* tools.
  Tell the user to review and run it themselves.
- **`Dockerfile.snippet`** — `RUN` lines to paste into a Dockerfile.

## Notes

- **Ghidra is manual** (not an apt package): it needs a JDK plus a download/unzip;
  the generated files include that recipe as comments.
- **Python tools** (angr, z3) install into a **uv venv** at `$RE_HARNESS_VENV`; the
  generated `install.sh` targets it. For a one-shot full install of everything, see
  `requirements/setup.sh` (host) or `requirements/Dockerfile` (container).
- **Graceful degradation:** if a tool is absent, the relevant phase skill falls
  back (e.g. no Ghidra → radare2 → objdump) and says so in its plan — don't block.
- Tool → purpose details: see `references/tool-cheatsheet.md`.
