---
name: reverse-engineering
description: Use when reverse-engineering or analyzing an unknown binary, executable, firmware image, mobile or managed app, or suspicious file — to start and pilot a structured investigation with reviewed plans. Keywords: reverse engineering, binary analysis, decompile, Ghidra, radare2, CTF, crackme, malware triage, unpack, disassemble, firmware.
---

# reverse-engineering

> **You are on an air-gapped network.** Every RE tool is pre-installed. Never install
> anything (`apt`, `pip install`, `curl`-to-fetch-a-tool). A missing tool is a
> path/usage problem, never an install problem.

Pilot an RE investigation as a loop: **analyze → write a plan → human approves →
next phase → … → report.** One phase at a time; the human approves each plan.

## Start (or resume)

1. **Authorization/scope** — only analyze artifacts the user is authorized to
   (CTF / owned / authorized engagement).
2. **Scaffold a session** in the current directory:
   ```sh
   sh new_session.sh <binary> <case-slug>
   ```
   This creates `vibe-reverse-<datetime>/<binary>/` (with `00-target.md`,
   `findings.md`, `STATE.md`, `artifacts/`, `scripts/`) and a session `index.md`.
   **Resuming** a paused case instead? Use **`re-continue`**.
3. **Multi-binary:** when a payload is unpacked/dropped/decrypted, run
   `sh add_binary.sh <session> <payload> <parent>`, re-triage it as a peer, and
   record the dropper→payload chain in `index.md`.

## Route to the phase

| Situation | Go to |
|---|---|
| Just starting | `re-triage` |
| Native binary, after triage | `re-static` |
| Packed / obfuscated (stacked layers) | `re-deobfuscate` (the router) |
| Virtualized (VM dispatcher + handler table) | `re-devirtualize` |
| Anti-debug / anti-VM / anti-disasm present | `re-antianalysis` |
| Crypto / encrypted strings / config | `re-crypto` |
| Harvest C2/IOCs + write a YARA rule | `re-config` |
| Keygen / constraints / path-finding | `re-solve` |
| Run, emulate, or trace (sandbox only) | `re-dynamic` |
| Firmware / managed / wasm target | pack not built yet — roadmap |
| Wrapping up (solved or dead end) | `re-report` |

## Always

- **Every phase ends with `re-planning`** — write a plan, self-review, update the
  binary's `STATE.md`, and STOP for approval. REQUIRED.
- Use **`re-scripting`** when a task needs custom code.
- Heavy tool output → `artifacts/`; put only summaries in the plan and chat.
- **Present user choices as a numbered list** ending "Which option?".
- Slow steps follow `references/long-running-ops.md` (background + budget +
  **ask before killing**). Tool→purpose: `references/tool-cheatsheet.md`.
