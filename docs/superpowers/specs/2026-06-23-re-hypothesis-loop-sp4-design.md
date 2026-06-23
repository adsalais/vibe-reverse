# RE harness overhaul — SP4: Hypothesis-driven, doubt-gated investigation loop

> **Status:** design approved (brainstorming), ready for implementation plan.
> **Scope of this spec:** sub-project **SP4** of the RE-skills overhaul.
> **Depends on:** SP1 (evidence & honesty spine) — merged. **Precedes:** SP3b (advanced
> playbooks), which will reference this loop.
> **Audience:** an engineer/agent implementing the change to the `skills/` tree.

## 1. Why

The investigation's decision-making is currently scattered and weak: each phase carries
its own routing table, `re-planning` separately "proposes next steps," and the human
gate fires after *every* phase regardless of stakes. That makes routing feel arbitrary
and the gate either heavy (stop for everything) or skippable under pressure.

SP4 replaces that with one explicit **hypothesis-driven loop**, owned by `re-planning`:
analyze the current state → enumerate and rank competing hypotheses → test the most
probable → on failure record a dead end and try the next → repeat. The human gate
becomes **doubt-triggered**: the loop proceeds on confident, reversible steps and stops
only when a step is uncertain or irreversible/costly. This is the scientific method
(cf. `systematic-debugging`) applied to RE routing, and it *consumes* SP1 — hypotheses
are `[hypothesis]`-tagged findings; failed ones become dead ends.

**Design guardrails (decided in brainstorming):**
- **confident AND reversible → proceed; irreversible OR uncertain → STOP.** Plus an
  **objective mandatory-gate list** that always stops regardless of confidence — because
  the agent is an unreliable judge of its own doubt, the high-stakes gates must not
  depend on its self-assessment.
- **Reframe, don't gut, the routing tables** — they stay as domain knowledge, relabeled
  as *hypothesis sources*; the decision moves into the loop.
- **Right-size the ceremony** — ranked-hypothesis writeup when hypotheses genuinely
  compete; a one-liner when the next step is obvious (same lesson as SP1's findings
  format).

## 2. Roadmap recap
SP1 (evidence spine) ✓ · SP2 (reporting) ✓ · SP3a (core-phase depth + delegation) ✓ ·
**SP4 (this — hypothesis loop)** → SP3b (advanced playbooks, reference this loop; the
light per-phase routing relabel rides with SP3b + a small SP3a-core retrofit).

## 3. Design

### 3.1 The loop (the core principle, in `re-planning`)
The investigation is a loop, not a pipeline:
1. **Analyze** the current state — done by the phase you're in (triage/static/…).
2. **Enumerate competing hypotheses** about what is going on / what to do next, and
   write them as `[hypothesis]`-tagged findings with their evidence.
3. **Rank** by probability; choose the most probable to test.
4. **Gate check** (3.2) — proceed or stop.
5. **Test** the chosen hypothesis (the phase action / next phase).
6. **On failure** — record it in `## Dead ends` (SP1) and loop to the next-ranked
   hypothesis.
7. Repeat until solved or dead-ended → `re-report`.

The continuous audit record is `findings.md` (updated every step, per SP1). The
numbered plan (`NN-*-plan.md`) is the **gate artifact** — written when the loop stops
(3.2), not on every iteration; this is what keeps confident runs (e.g. peeling several
obvious layers) from emitting a plan + approval prompt per step.

### 3.2 The gate decision (doubt-triggered + mandatory)
At step 4, decide:
- **Proceed without stopping** when the next step is **confident AND reversible AND not
  on the mandatory-gate list.** Record the hypothesis + result in `findings.md` and
  continue the loop.
- **STOP — write the gate plan and wait for the human** when the next step is
  **uncertain** (low confidence, or two hypotheses are close) **OR irreversible/costly**
  **OR on the mandatory-gate list.**

**Mandatory gates — ALWAYS stop, however confident the agent feels:**
- running / detonating / emulating an untrusted target (this already requires the
  `re-dynamic` consent + sandbox gate — SP4 names it as mandatory);
- registering a new binary (a dropped/unpacked/decrypted payload via `add_binary.sh`);
- destructive or irreversible patching of the target;
- any step tagged **🐢** (long/costly, per `long-running-ops.md`);
- anything crossing the sandbox boundary toward the host.

**Doubt-gated (stop only if uncertain / hypotheses close):** cheap, reversible analysis
choices — which obfuscation layer to peel next, which solver route, which phase next.

**Never skipped, even when proceeding:** recording the hypothesis/finding (the audit
trail) and verifying load-bearing claims (SP1). "Proceed" relaxes the *human stop*, not
the *evidence discipline*.

### 3.3 Plan template change (`re-planning` §1)
The plan's "Proposed next steps" section becomes **Hypotheses (ranked)**:
- the ranked list with each hypothesis's evidence + cost tag (⚡/⏳/🐢),
- which one is being tested now and why it's most probable,
- which are held for the next loop if it fails,
- the gate outcome (proceeding, or stopping + why — uncertain / irreversible / mandatory).
Right-sized: when the next step is obvious and reversible, this collapses to a single
line ("next: <step> — confident, reversible, proceeding"); the full ranked list appears
when hypotheses genuinely compete.

### 3.4 Reframe routing tables as hypothesis sources (principle only in SP4)
`re-planning` and the orchestrator state the principle: **a phase's routing table is a
hypothesis source — the candidate next-steps the phase can propose — not the decision.**
The loop ranks and gates. `re-deobfuscate`'s peel-loop is, in this framing, its
*ranking heuristic* ("order layer-hypotheses outermost-first") feeding the one loop. The
**actual per-phase relabel of the tables is deferred** to SP3b (advanced phases) + a
small SP3a-core retrofit — SP4 only establishes the principle and the loop that consumes
them.

### 3.5 Where it lives
- **`skills/re-planning/SKILL.md`** — the loop (3.1), the gate decision + mandatory list
  (3.2), the plan-template change (3.3), and the routing-as-hypothesis-source principle
  (3.4), all **inline** (no new reference file). The existing SP1 self-review and
  findings/STATE checkpoint stay; the red-flags table is revised (3.6).
- **`skills/reverse-engineering/SKILL.md`** — the core-loop description updated from
  "one phase at a time; human approves each plan" to the hypothesis loop with
  doubt-triggered gating; one `Always` line.

### 3.6 Red-flags revision (`re-planning`)
The current table assumes an unconditional stop ("user in a hurry, skip the ceremony" →
"the gate is fastest"). Under doubt-gating that framing is wrong. Revise to:
- keep the flags against skipping the **audit/verification** ("proceed" never means skip
  recording or verifying);
- replace "always stop" framing with "stop when the gate triggers" — and add flags for
  the *new* failure mode: **proceeding on an irreversible/mandatory step because it felt
  confident** ("I'm sure it's safe to run it" → running is a mandatory gate; stop).

## 4. Files
- Modify: `skills/re-planning/SKILL.md` (the loop, gate, mandatory list, template, red flags)
- Modify: `skills/reverse-engineering/SKILL.md` (core-loop description + Always line)
- Modify: `ARCHITECTURE.md` (§2 core loop / §6 the gate — reflect doubt-gating + mandatory list)
- Modify: `AGENTS.md` (the one-line "human approves each plan" → "approves at each gate (doubt-triggered)")
- Modify: `tests/scenarios/re-planning-hurry.md` (align with doubt-gating — see §5)
- Create: `tests/scenarios/re-hypothesis-loop.md`, `tests/scenarios/re-doubt-gate.md`

## 5. Tests (pragmatic — behavioral change, so scenarios lead)
- **`re-doubt-gate.md` (RED→GREEN):** GREEN proceeds without stopping on a confident,
  reversible step (peel an obvious UPX layer → re-triage → continue) **and** STOPS on a
  mandatory-gate step (detonating the target) *even when "confident"*; RED either stops
  for approval on every trivial peel, or runs the target without a gate.
- **`re-hypothesis-loop.md` (RED→GREEN):** GREEN, in an ambiguous state, writes ranked
  hypotheses, tests the top, and on failure records a dead end and tries the next; RED
  fixates on one guess, retries it, and never records the failure.
- **Update `re-planning-hurry.md`:** the lesson shifts from "always STOP" to "you may
  proceed on a confident, reversible step under time pressure — but never skip recording
  the hypothesis or verifying the result." GREEN proceeds *and* audits; RED skips the
  audit / ships an unverified key.
- **Deterministic (sh, tool-optional):** assert `re-planning/SKILL.md` contains the
  mandatory-gate list (e.g. greps for "running", "new binary", "🐢"/"long", "host") and
  the confident/reversible vs irreversible/uncertain rule. Catches drift.
- Full suite still exits 0.

## 6. Out of scope (deferred / not done here)
- The per-phase **routing-table relabel** → rides with SP3b + a small SP3a-core retrofit
  (SP4 states only the principle + the loop).
- No new skill; no new reference file (loop is inline in `re-planning`).
- No change to phase analysis content, helper scripts, the report, or the evidence
  contract (SP1) beyond consuming them.

## 7. Acceptance criteria
1. `re-planning/SKILL.md` describes the hypothesis loop (analyze → rank → test → dead-end
   → loop), inline.
2. It states the gate rule (**confident+reversible → proceed; irreversible/uncertain →
   stop**) and the **objective mandatory-gate list**, and that proceeding never skips
   recording or verification.
3. The plan template's next-steps section is the **ranked-hypotheses** form, right-sized
   (one line when obvious, ranked list when competing).
4. `re-planning` states the **routing-tables-are-hypothesis-sources** principle; the
   orchestrator's core-loop description and `Always` line reflect the loop + doubt-gating.
5. The red-flags table is revised for doubt-gating (audit/verify never skipped; new flag
   = proceeding on an irreversible/mandatory step because it "felt confident").
6. `ARCHITECTURE.md` and `AGENTS.md` reflect the doubt-gated loop.
7. The two new scenarios + the updated hurry scenario describe the GREEN behaviour; the
   deterministic mandatory-gate check passes; full suite exits 0.
8. No new skill/reference; no phase SKILL.md routing relabel (that is SP3b); no
   "claude"/"anthropic" mentions; relative paths only; `re-planning/SKILL.md` < 500 lines.

## 8. Open questions
None — resolved in brainstorming: the loop lives **inline in `re-planning`**; SP4 is
**spine only** (per-phase relabel deferred to SP3b + a small core retrofit); the gate is
**confident+reversible → proceed, irreversible/uncertain/mandatory → stop**; routing
tables are **reframed, not gutted**; ceremony is **right-sized**.
