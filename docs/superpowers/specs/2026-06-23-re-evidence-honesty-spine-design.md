# RE harness overhaul — SP1: Evidence & honesty spine

> **Status:** design approved (brainstorming), ready for implementation plan.
> **Scope of this spec:** sub-project **SP1** of the RE-skills overhaul.
> **Audience:** an engineer/agent implementing the change to the `skills/` tree.

## 1. Why this overhaul

The 14-skill RE family (`reverse-engineering` orchestrator + `re-planning` gate +
`re-scripting`/`re-continue` spine + phase verticals) has a sound architecture but
falls short of the `examples/superpowers/` quality bar on the three properties that
matter most for this work: **reliability, audit, and reporting.**

Concretely, the gaps are:

- **Audit (weakest).** `findings.md` — the cumulative "what we know" record that any
  audit hangs on — is *unspecified prose*. Nothing forces a claim to cite the
  artifact/address it came from, carry a confidence level, or record whether it was
  independently verified. A reviewer cannot trace a conclusion back to its evidence.
- **Reliability.** There is no cross-cutting **verification** discipline (superpowers
  has a whole `verification-before-completion` skill); "verify" appears ad hoc in
  `re-solve`/`re-crypto` only. Unverified claims can flow straight into the report.
- **Honesty.** Negative results — *"we tried X, it's ruled out"* — are first-class
  signal in reverse engineering, but the skills capture them only loosely and the
  report does not surface them. Dead ends seed the next attempt; throwing them away
  is a real loss.

**Audit, for these skills, means:** a *defensible evidence trail* (every conclusion
traceable to a named artifact + address/line, tagged with confidence and whether it
was independently verified) + *self-correction* (the agent audits its own evidence
for gaps, overclaims, and contradictions) + *honesty* (what didn't work is recorded,
not deleted). It does **not** mean formal forensic chain-of-custody.

## 2. The overhaul roadmap (context — SP1 is this spec)

The overhaul is delivered as sequential sub-projects, each with its own
spec → plan → implementation cycle:

| # | Sub-project | Delivers | Depends on |
|---|---|---|---|
| **SP1** | **Evidence & honesty spine** *(this spec)* | Finding schema + `findings.md` ledger format + confidence/verification vocabulary + verification discipline + upgraded `re-planning` self-review & reviewer + orchestrator wiring. **Locks the cross-cutting contracts.** | — |
| SP2 | Reporting deliverable | Rework `re-report` + template to enforce the trail (every report claim → finding id → evidence + confidence), prominent dead-ends, structured export, hashes/chain-of-custody. | SP1 |
| SP3 | Phase depth + delegation | Bring each phase to `systematic-debugging` depth (method, failure modes, red-flags, "have I understood enough?", worked example); adopt the evidence contract per phase; add the heavy-reading **subagent delegation** mechanics. Likely split SP3a (triage/static/dynamic) / SP3b (deob/devirt/antianalysis/crypto/config/solve). | SP1 |

SP2 and SP3 can run in parallel once SP1 lands.

**Layout note:** the overhaul is *additive* (an evidence/verification discipline + a
delegation pattern), not a teardown. All 14 skills are kept; the phase decomposition
is sound. SP1 deliberately touches the **spine only** to keep churn off the tested
phase skills until SP3 deepens them.

## 3. North-star cross-cutting model (defined here, inherited by every phase)

SP1 defines these contracts once; later sub-projects and all phases inherit them.

### 3.1 The *finding* is the atomic audit unit
Every claim recorded in `findings.md` is a short per-entry record carrying: a
**confidence tag** (3.2) · the **claim** · the **`evidence`** · the **verification**
(when `confirmed`) · an **optional id** (`F-NNN`, added only when the finding is cited
elsewhere — a dead end that refutes it, or the report). No rigid table — one short
entry per finding (see 4.2).

The binding rule: **an entry with no evidence pointer is not a finding — it is a
hypothesis.** Evidence is one of: `artifacts/<file>:<line>`, an address `0x…` inside
a named artifact, or `scripts/<file>` + a named test vector. This single rule *is*
the audit trail.

### 3.2 Confidence tag — a single 4-value tag
One tag per finding (no separate status column):
- **`confirmed`** — independently verified (see 3.3); the entry states *how*.
- **`likely`** — strong single-source evidence, not independently verified.
- **`hypothesis`** — plausible, unverified, may be wrong.
- **`refuted`** — disproved; kept on the record (see 3.4), never deleted.

**Propagation rule:** a conclusion is only as strong as its weakest cited finding.
The report's verdict and executive summary must reflect the weakest link. A
conclusion that rests on a `hypothesis` cannot itself be `confirmed`.

### 3.3 Verification discipline (the reliability lever)
Mirrors `superpowers:verification-before-completion`. A finding is only `confirmed`
after an **independent** check agrees. *"I read it in the decompiler once"* is
`likely` at best. In RE, independent verification means one of:

- Re-run the **real binary** with the recovered input/transform and confirm the
  expected behaviour (sandboxed for untrusted targets, via `re-dynamic`).
- **Cross-tool agreement** — Ghidra decompile vs radare2 vs objdump; disagreement
  means *not* confirmed.
- **Reproduce a transform/decrypt with a known vector** — e.g. a known-plaintext
  header (`MZ`/`\x7fELF`) appearing in the decrypted output; a published test vector
  for a standard cipher.
- **Emulation/dynamic result matches the static prediction.**
- **Solver output accepted by the binary** (the recovered key/input is taken).

Load-bearing claims (anything that headlines the report or drives the next phase)
must be `confirmed` before they are presented as fact.

### 3.4 Honesty — negative results are first-class
`findings.md` carries a **`## Dead ends`** section. Every attempt that failed is
recorded: *what was tried · why it failed (with evidence) · what it rules out / what
to try next.* When a finding is disproved, it is re-tagged `refuted` and a dead-end
line explains why. **Nothing tried is ever silently deleted.**

### 3.5 Self-correction (audit-as-self-review)
The `re-planning` gate is the enforcement point. Its self-review and independent
reviewer become **evidence/honesty auditors** that hunt for: claims missing evidence
pointers, overclaims (confidence > evidence), contradictions with prior findings, and
**missing negative results** (something tried-and-failed this phase that isn't in the
dead-ends ledger).

### 3.6 Delegation boundary (governs SP3; stated here)
Subagents are for **mechanical, bounded, single-purpose** work *only*: read-and-extract
from a large artifact, run a scan and summarise, apply a deterministic transform, run
a tested script. A mechanical subagent:
- gets a precise spec and returns **raw results + evidence pointers**;
- **does not keep its own findings ledger** — the *piloting* agent integrates the
  result into `findings.md` with a confidence tag;
- carries the cost-tag + soft budget + **ask-before-kill** rule
  (`references/long-running-ops.md`) so even mechanical work can't run away silently.

**Judgment, iteration, and strategy stay in the piloted main loop, under the gate.**
Open-ended work — *"figure out how to deobfuscate this"*, *"decide what to try next"*,
anything that tries many approaches — is **never** delegated to a subagent that could
churn invisibly. The human must always see open-ended work, and the approval gate
bounds it. (SP1 only states this boundary; SP3 builds the delegation mechanics on top
of it.)

## 4. SP1 deliverables (per file)

### 4.1 NEW — `skills/reverse-engineering/references/evidence-and-findings.md`
The shared reference cited by the orchestrator, `re-planning`, the phases (lightly in
SP1, deeply in SP3), and `re-report`. Contents:

1. **The finding entry** — the per-entry shape (3.1), the evidence-mandatory rule, and
   the `findings.md` two-section layout (4.2) with a filled example.
2. **Confidence vocabulary + propagation** (3.2).
3. **Verification catalog** (3.3) — the RE-specific list of what counts as independent
   verification.
4. **Honesty / dead-ends** (3.4) — the dead-end entry shape.
5. **Delegation boundary** (3.6).

Keep it reference-style and scannable (tables/lists), tool-neutral, no "claude"/
"anthropic" mentions, relative paths only — per `AGENTS.md` conventions.

### 4.2 `findings.md` format (the audit artifact)
Two sections per binary — a light per-entry list, no table:

```markdown
# Findings — <binary>

## Findings
- **[confirmed]** main compares argv[2] to a +1 transform of argv[1].
  evidence: `artifacts/ghidra/decomp.c:142` · verified: re-ran `./cm AB BC` → "Correct!"
- **[likely]** strings decrypted with single-byte XOR 0x5a.
  evidence: `artifacts/floss.txt:30`

## Dead ends
- tried run-to-unpack via qiling — failed: emulator detected via rdtsc timing
  (`artifacts/dynamic/qiling.log:88`). Rules out naive emulation; next: patch the
  timing hook.
```

- Each finding leads with its **`[tag]`** (3.2: `confirmed`/`likely`/`hypothesis`/`refuted`),
  then the claim, then an `evidence:` pointer (**mandatory** — 3.1).
- A `confirmed` entry states `verified:` (the independent check); without it the entry
  is at most `likely`.
- **Ids are optional** — prepend `[F-001]` only when the finding is cited elsewhere (a
  dead end that refutes it, or the report). Greppable either way (`grep '\[confirmed\]'`).
- Dead ends are short narratives: *what was tried · why it failed (with evidence) · what
  it rules out / next idea.* A refuted finding is re-tagged `[refuted]` and gets a
  dead-end line.

`findings.md` is the **source of truth**; plans/`STATE.md`/`REPORT.md` reference findings
(by id when one is assigned, else by claim) rather than restating them. Provenance is
bidirectional: the plan that introduces a finding names it; the finding's `evidence`
points into `artifacts/`.

### 4.3 `skills/reverse-engineering/add_binary.sh`
Replace the single-line seed at `add_binary.sh:34`
(`printf '# Findings — %s\n\n(append cumulative findings here)\n'`) with a heredoc
that seeds the two-section skeleton from 4.2 (the `# Findings — <name>` heading, a
`## Findings` section, and a `## Dead ends` section). Keep POSIX `sh`, `set -eu`, no
target execution. (`new_session.sh` calls `add_binary.sh`, so this covers both new
sessions and added peers/payloads.)

### 4.4 `skills/re-planning/SKILL.md`
- **Self-review (§2)** gains four evidence/honesty checks, citing
  `../reverse-engineering/references/evidence-and-findings.md`:
  1. **Evidence** — every claim cites an `artifacts/` pointer or is explicitly tagged a hypothesis; no bare assertions.
  2. **No overclaim** — the tag must match the evidence; a `confirmed` entry with no stated `verified:` check is a violation (downgrade to `likely`).
  3. **Contradiction** — reconcile new findings against prior `findings.md`, or re-tag the loser `refuted`.
  4. **Negative results recorded** — anything tried-and-failed this phase is in the `## Dead ends` section.
- **Checkpoint (§4)** now also updates `findings.md` (append new finding/dead-end
  entries, re-tag disproved findings `refuted`), not just `STATE.md`.
- **Red-flags table** gains rows for the new rationalizations (e.g. *"I'm sure it's
  AES, no need to verify"* → that's `likely`, not `confirmed`, until checked; *"the
  failed attempt isn't worth recording"* → dead ends seed the next attempt — record it).

### 4.5 `skills/re-planning/reviewer-prompt.md`
Add matching adversarial checks so the independent reviewer audits evidence too:
evidence gaps, overclaims (confidence > evidence / `confirmed` without `verified`),
contradictions with `findings.md`, and **missing negative results**. Extend the
returned JSON `type` enum with `evidence` and `honesty`. Keep "default to revise if
uncertain".

### 4.6 `skills/reverse-engineering/SKILL.md` (orchestrator)
- Scaffold description names `findings.md` as the **evidence ledger** (not just
  "running findings").
- **Always** list gains two lines:
  - *Record findings per `references/evidence-and-findings.md` — every claim cites
    evidence + confidence; verify before you call it `confirmed`; keep dead ends.*
  - The **delegation-boundary** line (3.6, one sentence): mechanical/bounded subagents
    only; they return results + evidence and don't write findings; judgment stays in
    the piloted loop.

### 4.7 `skills/re-report/SKILL.md` (light touch — full rework is SP2)
Add one rule: **every claim in the report traces to a finding entry in `findings.md`
and carries its confidence; the verdict reflects the weakest link** (3.2). Note inline that the full
template/structured-export/chain-of-custody overhaul is SP2. Do **not** rewrite
`report-template.md` here.

### 4.8 Worked example — `docs/reverse/_example/crackme1/` (optional, nice-to-have)
Update `findings.md` to the new per-entry format so the shipped example demonstrates
the contract. Small and high-value as a copy-from reference, but not load-bearing —
drop it if the plan is tight on scope.

## 5. Tests (pragmatic — Iron Law relaxed per project owner)

- **Deterministic:** the seed is written by `add_binary.sh`, so add the assertion to
  whichever existing test scaffolds a session for its fixture — concretely
  `tests/scripts/test_session_status.sh` (it stands up a session via
  `new_session.sh`/`add_binary.sh` to exercise the status read). Assert the seeded
  `findings.md` contains both the `## Findings` and `## Dead ends` sections.
  Tool-optional, exit 0.
- **Scenario (one, RED→GREEN — not gating every wording tweak):** NEW
  `tests/scenarios/re-evidence-discipline.md` — agent asserts a `confirmed` finding with
  no independent check → GREEN downgrades it to `likely` or performs/records a
  verification; RED dumps an unsourced "it's AES" assertion. (No second scenario; the
  existing `re-planning-hurry.md` stays as-is.)

## 6. Out of scope (explicit — deferred)
- Deep per-phase method, failure-mode, and red-flag enrichment → **SP3**.
- Subagent delegation **mechanics** (dispatch prompts, when/how) → **SP3** (SP1 states
  only the boundary principle).
- Full `re-report` template overhaul, structured/machine-readable export, and
  chain-of-custody hashes → **SP2**.
- Any new JSON sidecar for findings — the markdown ledger is sufficient for SP1's audit
  bar (YAGNI).

## 7. Acceptance criteria
1. `evidence-and-findings.md` exists and defines the finding entry, the 4-value
   confidence tag + propagation, verification catalog, dead-ends format, and delegation
   boundary.
2. A freshly scaffolded session seeds `findings.md` with both the `## Findings` and
   `## Dead ends` sections; the deterministic test asserts it.
3. `re-planning` self-review + checkpoint and `reviewer-prompt.md` enforce the four
   evidence/honesty checks and update `findings.md`.
4. The orchestrator's *Always* list carries the findings + delegation-boundary lines.
5. `re-report` requires every claim to trace to a finding entry and carry its confidence.
6. The single `re-evidence-discipline` scenario describes the GREEN behaviour; the
   deterministic suite still exits 0.
7. No new skill is added; no phase SKILL.md is deepened (those are SP3); no
   "claude"/"anthropic" mentions; relative paths only.
8. *(Optional)* the `crackme1` worked example uses the new per-entry `findings.md` format.

## 8. Open questions
None — resolved during brainstorming: evidence discipline lives in a **shared
reference enforced at the gate** (no new skill); confidence is a **single 4-value tag**
(3 levels + `refuted`); findings use a **light per-entry format** with optional ids;
`re-report` gets a **one-line** touch in SP1.
