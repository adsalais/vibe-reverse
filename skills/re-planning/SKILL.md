---
name: re-planning
description: Use when ending a reverse-engineering phase and deciding what to do next, before continuing. Symptoms you are about to violate it: "I'll just continue", "it's surely safe to run it", "skip the plan", "the user is in a hurry". Keywords: RE plan, next steps, hypothesis loop, approval gate, doubt-gate, mandatory gate, checkpoint.
---

# re-planning

## Core principle

**The investigation is a hypothesis loop, and the human pilots the risky turns.** At
each decision point you analyze the current state, **rank** the competing hypotheses,
**test the most probable**, and on failure record a dead end and try the next. You
**proceed on your own** when the next step is confident and reversible; you **STOP for
the human** when it is uncertain or irreversible. The continuous record is `findings.md`;
the numbered plan is the **gate artifact**, written when you stop.

## 1. The loop

1. **Analyze** the current state (the work of the phase you're in).
2. **Hypotheses** — enumerate what's going on / what to do next; write each as a
   `[hypothesis]` finding in `findings.md` with its evidence (per
   `../reverse-engineering/references/evidence-and-findings.md`).
3. **Rank** by probability; pick the most probable to test.
4. **Gate check** (§2) — proceed, or write the plan and stop.
5. **Test** it (the phase action / next phase).
6. **On failure** — record a `## Dead ends` entry (what failed, why, what it rules out)
   and loop to the next-ranked hypothesis.

## 2. The gate — proceed or stop

- **Proceed (no stop)** when the next step is **confident AND reversible AND not on the
  mandatory list.** Record the hypothesis + result in `findings.md` and continue.
- **STOP — write the plan (§3) and wait** when the step is **uncertain** (low
  confidence, or two hypotheses are close) **OR irreversible/costly** **OR on the
  mandatory list.**

**Mandatory gates — ALWAYS stop, however confident you feel:**
- running / detonating / emulating an untrusted target (also needs `re-dynamic`'s
  consent + sandbox);
- registering a **new binary** (a dropped/unpacked/decrypted payload, `add_binary.sh`);
- destructive / irreversible **patching** of the target;
- any **🐢** long/costly step (`../reverse-engineering/references/long-running-ops.md`);
- anything crossing the sandbox boundary toward the **host**.

**Proceeding never skips the audit:** record the hypothesis/finding and **verify**
load-bearing claims regardless. "Proceed" relaxes the *human stop*, not the *evidence
discipline*.

## 3. The gate plan (write when you stop)

Save to `docs/reverse/<investigation>/NN-<phase>-plan.md` (zero-padded `NN`):

```markdown
# NN — <phase> plan — <investigation>

## What I did this phase
- <summary; link to artifacts/ files, not raw dumps>

## What I found
- <key findings, by claim — the ledger is findings.md>

## Hypotheses (ranked)
1. <most probable> — evidence, why most likely — **cost: ⚡/⏳/🐢**  ← testing this
2. <alternative> — held for the next loop if 1 fails — **cost: ⚡/⏳/🐢**

## Why I stopped
- <uncertain / irreversible / mandatory-gate — which, and why>

## Decision needed from you
1. Approve as-is   2. Approve with changes   3. Redirect
Which option?
```

Cost tags: ⚡ seconds · ⏳ minutes · 🐢 tens of minutes+. **Right-size:** when the next
step is obvious and reversible you are *proceeding*, not stopping — the ranked list
collapses to a one-line note in `findings.md` ("next: <step> — confident, reversible").
The full plan above is for a **stop**.

## 4. Self-review BEFORE presenting (fix inline)

Audit the plan AND `findings.md` against
`../reverse-engineering/references/evidence-and-findings.md`:
- **Evidence** — every claim cites an `artifacts/` pointer or is tagged `[hypothesis]`.
- **No overclaim** — the tag matches the evidence; a `[confirmed]` with no `verified:` is a violation.
- **Contradiction** — reconcile vs prior `findings.md` / `00-target.md`; re-tag the loser `[refuted]`.
- **Negative results recorded** — failed hypotheses are in `## Dead ends`.
- **Ranking** — is the hypothesis you're testing actually the most probable, given the evidence?
- **Gate** — did you classify proceed vs stop correctly, and never auto-proceed past a mandatory gate?

**Escalate** to an independent reviewer subagent (plan + `00-target.md` + `findings.md`,
prompted by `reviewer-prompt.md`) when confidence is low, the investigation
branched/backtracked, or several paths compete. Resolve its issues first.

## 5. Checkpoint (at every gate stop)

When you write the plan, first update `findings.md` (new finding/dead-end entries,
re-tag `[refuted]`) — the source of truth — then the binary's `STATE.md`:
- `phase:` / `status: awaiting-approval`
- `last-approved-plan:` and `next-step:` (the hypothesis being tested)
- refresh `## Open questions`; reconcile the `## Background jobs` ledger.

This lets `re-continue` resume later. (On a *proceed* you still update `findings.md`;
`STATE.md` updates at the next stop.)

## Routing tables are hypothesis sources

A phase's routing table (triage's family table, the obfuscation taxonomy, …) lists the
**candidate** next-steps a phase can propose — it is a hypothesis source, **not** the
decision. This loop ranks them and gates. (`re-deobfuscate`'s "peel outermost first" is
just its ranking heuristic feeding this loop.)

## Red flags — STOP, you are rationalizing

| Thought | Reality |
|---|---|
| "It's surely safe to just run it" | Running an untrusted target is a **mandatory gate** — stop, get consent + sandbox. |
| "I'm confident, I'll patch / unpack-to-a-new-binary and continue" | New binary / destructive patch are mandatory gates — stop. |
| "I'll skip recording — I'm proceeding anyway" | Proceeding never skips the audit. Record the hypothesis + verify. |
| "Two routes look equally likely, I'll just pick one" | That's *uncertain* → stop and ask (numbered options). |
| "I'm sure it's AES — no need to verify" | `[likely]`, not `[confirmed]`, until an independent check agrees. |
| "The attempt failed — not worth recording" | Dead ends seed the next loop. Record it in `## Dead ends`. |
| "This 🐢 step is obviously right, I'll launch it unattended" | 🐢 is a mandatory gate — state the cost and stop first. |

Confident **and** reversible → proceed (and record). Uncertain **or** irreversible **or**
mandatory → write the plan and STOP.
