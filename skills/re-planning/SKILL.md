---
name: re-planning
description: Use when ending a reverse-engineering phase and proposing next steps, before continuing — writes a numbered investigation plan, self-reviews it for consistency and relevancy, then stops for human approval. Symptoms you are about to violate it: "I'll just continue", "skip the plan", "the user is in a hurry". Keywords: RE plan, next steps, approval gate, checkpoint.
---

# re-planning

## Core principle

**The plan is the gate artifact, and the human pilots.** Every phase ends by
writing a plan, self-reviewing it, and STOPPING for approval before any next-phase
work. **Violating the letter of the gate is violating the spirit of the gate.**

## 1. Write the plan

Save to `docs/reverse/<investigation>/NN-<phase>-plan.md` (zero-padded `NN`):

```markdown
# NN — <phase> plan — <investigation>

## What I did this phase
- <summary; link to artifacts/ files, not raw dumps>

## What I found
- <key findings, in plain language>

## Assessment
- <phase-specific judgement: packed? obfuscated? solver needed? etc.>

## Open questions / uncertainties
- <what is NOT yet confirmed>

## Proposed next steps
1. <next action> — why, which skill/tool, expected output — **cost: ⚡/⏳/🐢**
2. <alternative branch if applicable> — **cost: ⚡/⏳/🐢**

## Decision needed from you
1. Approve as-is
2. Approve with changes
3. Redirect
Which option?
```

Cost tags: ⚡ fast (seconds) · ⏳ minutes · 🐢 long (tens of minutes+) — so the human
approves with runtime in view.

## 2. Self-review BEFORE presenting (fix inline)

- **Consistency** — does *Assessment* contradict *Proposed next steps*? Does
  anything contradict `findings.md` or the goal in `00-target.md`?
- **Relevancy** — is each step justified by a finding and does it advance the
  goal? Is the *recommended* step the highest-value one? No busywork.
- **Evidence/honesty** — does each claim cite an `artifacts/` file, or is it
  marked as an unconfirmed hypothesis? No overclaiming.
- **Scope** — does it propose the NEXT step, not a five-step leap?

**Escalate** to an independent reviewer subagent (give it the plan +
`00-target.md` + `findings.md`, prompted by `reviewer-prompt.md`) when the plan is
complex or high-uncertainty: the next step is high-cost/irreversible (e.g. running
the target), confidence is low / many open questions remain, the investigation
branched or backtracked, or it proposes multiple competing paths. Resolve its
issues first.

## 3. STOP for approval

Present a ≤3-line summary + the plan's path, then **WAIT**. Do not start the next
phase until the human responds. They approve in chat ("approved" / "do 1, skip 2"
/ "redirect"), or edit the plan file and say "go".

## 4. Checkpoint (update STATE.md at every gate)

Each plan is a checkpoint. When you write the plan, update the current binary's
`STATE.md`:
- `phase:` / `status: awaiting-approval`
- `last-approved-plan:` (the previous one) and `next-step:` (the recommended step)
- refresh `## Open questions`
- reconcile the `## Background jobs` ledger (mark finished jobs `done`).

This is what lets `re-continue` resume the investigation in a future session. For
slow steps follow `../reverse-engineering/references/long-running-ops.md`
(background + budget + **ask before killing**).

## Red flags — STOP, you are rationalizing

| Thought | Reality |
|---|---|
| "The next step is obviously fine, I'll just do it" | Write the plan and wait. |
| "I'll save a round-trip by continuing" | The round-trip is the point — the human pilots. |
| "The user is in a hurry, skip the ceremony" | The gate is fastest overall; it prevents wrong turns. |
| "The plan is trivial" | Trivial plans are approved in seconds — still write it. |
| "I already know what they'll say" | Then approval costs nothing. Wait for it. |
| "This is taking too long, I'll kill it and move on" | A budget-hit is a question for the user, not your call. Ask (numbered options). |

All of these mean: write the plan, self-review, and STOP.
