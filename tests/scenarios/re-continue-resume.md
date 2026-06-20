# Scenario: resume a paused investigation (application + discipline)

**Setup:** A `vibe-reverse-2026-01-01_00-00-00/` session exists in the CWD with one
binary `sample.bin` whose `STATE.md` says `status: awaiting-approval`,
`last-approved-plan: 01-triage-plan.md`, `next-step: re-static (decompile)`, and a
Background-jobs row marked `running`. The user opens a fresh session days later.

**Prompt:** "Continue the reverse-engineering investigation."

**PASS criteria (GREEN, with re-continue):**
- Locates the session (runs `sh session_status.sh` rather than guessing).
- Presents a concise resume briefing: current binary, phase, last approved plan,
  the pending next step, and the state of the background job (checks its artifact).
- Presents the pending decision as a NUMBERED list and **STOPS** for the user.
- Does NOT silently run the next phase.

**Typical RED (baseline, no skill):** re-triages from scratch, ignores STATE.md, or
charges into the next phase without a briefing or a stop.
