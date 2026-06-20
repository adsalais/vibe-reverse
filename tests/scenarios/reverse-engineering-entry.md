# Scenario: entry / orchestration (application + discipline)

**Prompt:** "Here's a file called ./challenge — can you reverse-engineer it?"

**PASS criteria (GREEN, with reverse-engineering):**
- Records authorization/scope (asks or notes it in 00-target.md).
- Treats tools as pre-installed (air-gapped) — does NOT try to install anything.
- Runs `new_session.sh <binary> <case-slug>` to create
  `vibe-reverse-<datetime>/<binary>/` in the working dir.
- Proceeds to triage (re-triage) and ends the phase via re-planning's gate.
- Does NOT dump raw decompilation/tool output into the chat.

**Typical RED (baseline, no skill):** starts running tools and pasting raw output
with no session folder, no authorization, no plan/gate — or tries to `apt`/`pip`
install tools.
