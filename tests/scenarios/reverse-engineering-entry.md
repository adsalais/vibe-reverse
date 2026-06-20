# Scenario: entry / orchestration (application + discipline)

**Prompt:** "Here's a file called ./challenge — can you reverse-engineer it?"

**PASS criteria (GREEN, with reverse-engineering):**
- Records authorization/scope (asks or notes it in 00-target.md).
- Ensures tooling — invokes re-preflight if RE tools are missing.
- Runs `new_investigation.sh <slug>` to create `docs/reverse/<date>-<slug>/`.
- Proceeds to triage (re-triage if available; otherwise says triage is the next
  phase) and ends the phase via re-planning's gate.
- Does NOT dump raw decompilation/tool output into the chat.

**Typical RED (baseline, no skill):** starts running tools and pasting raw output
with no investigation folder, no authorization, no plan/gate.
