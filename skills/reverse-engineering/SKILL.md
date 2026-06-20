---
name: reverse-engineering
description: Use when reverse-engineering or analyzing an unknown binary, executable, firmware image, mobile or managed app, or suspicious file — to start and pilot a structured investigation with reviewed plans. Keywords: reverse engineering, binary analysis, decompile, Ghidra, radare2, CTF, crackme, malware triage, unpack, disassemble, firmware.
---

# reverse-engineering

Pilot an RE investigation as a loop: **analyze → write a plan → human approves →
next phase → … → report.** One phase at a time; the human approves each plan.

## Start an investigation

1. **Record authorization/scope** — only analyze artifacts the user is authorized
   to (CTF / owned / authorized engagement).
2. **Tooling** — every RE tool is pre-installed (air-gapped); never install anything.
3. **Scaffold** — run `new_investigation.sh <slug>` to create
   `docs/reverse/<date>-<slug>/` and record the target in `00-target.md`.

## Route to the phase

| Situation | Go to |
|---|---|
| Just starting | triage (`re-triage`) |
| Native binary, after triage | `re-static` |
| Firmware / managed / wasm target | pack not built yet — see the roadmap in the design spec |
| Defeat packing / obfuscation | `re-deobfuscate` |
| Keygen / constraints / path-finding | `re-solve` |
| Run or trace the target (sandbox only) | `re-dynamic` |
| Wrapping up (solved or dead end) | `re-report` |

## Always

- **Every phase ends with `re-planning`** (write a plan, self-review, STOP for
  approval). REQUIRED.
- Use **`re-scripting`** when a task needs custom code.
- Heavy tool output → `artifacts/`; put only summaries in the plan and chat.

All v1 phase skills are built (triage → static → deobfuscate / solve / dynamic →
report). See `docs/reverse/_example/` for a worked investigation.
