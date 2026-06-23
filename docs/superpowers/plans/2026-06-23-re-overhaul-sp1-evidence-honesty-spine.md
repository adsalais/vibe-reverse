# SP1 — Evidence & Honesty Spine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the RE skill family a defensible, honest audit trail — a structured `findings.md`, a confidence/verification contract, and gate-level enforcement — without deepening the phase skills.

**Architecture:** One new shared reference (`evidence-and-findings.md`) defines the contract; the scaffold seeds the new `findings.md` shape; `re-planning` enforces it at the approval gate (self-review + independent reviewer + checkpoint); the orchestrator and `re-report` point at it. Additive only — no new skill, no phase SKILL.md deepened.

**Tech Stack:** Markdown skills/references; POSIX `sh` helper scripts (`set -eu`); POSIX-sh deterministic tests.

**Spec:** `docs/superpowers/specs/2026-06-23-re-evidence-honesty-spine-design.md`

## Global Constraints

- **No "claude"/"anthropic" mentions** anywhere — skills are tool-neutral and portable (Claude Code + opencode).
- **Air-gapped:** never install anything; a missing tool is a path/usage problem.
- **Relative paths only** — reference helper files by relative path, never `${CLAUDE_SKILL_DIR}` or absolute paths.
- **Helper scripts:** POSIX `sh`, `set -eu`, **never execute the target**, heavy output → `artifacts/`.
- **Deterministic tests are tool-optional** and must exit 0; never write a test that *requires* an RE tool.
- **SP1 scope is the spine only:** no new skill is created; no phase SKILL.md (`re-triage`, `re-static`, `re-deobfuscate`, `re-devirtualize`, `re-antianalysis`, `re-crypto`, `re-config`, `re-solve`, `re-dynamic`) is edited. Those are SP3.
- **Confidence vocabulary is exactly:** `[confirmed]` · `[likely]` · `[hypothesis]` · `[refuted]` (one tag, no separate status field).
- **Evidence is mandatory:** an entry with no evidence pointer is a hypothesis, not a finding.

---

### Task 1: The evidence-and-findings contract reference

The foundational artifact every other task cites. No code; verified by content review + portability greps.

**Files:**
- Create: `skills/reverse-engineering/references/evidence-and-findings.md`

**Interfaces:**
- Produces: the contract terms later tasks reference verbatim — the tags `[confirmed]`/`[likely]`/`[hypothesis]`/`[refuted]`; the `## Findings` / `## Dead ends` section names; the `evidence:` / `verified:` entry fields; the relative cite path `references/evidence-and-findings.md` (from the orchestrator) and `../reverse-engineering/references/evidence-and-findings.md` (from sibling skills).

- [ ] **Step 1: Create the reference file**

Write `skills/reverse-engineering/references/evidence-and-findings.md` with exactly this content (note the inner fenced block is part of the file):

````markdown
# Evidence & findings — the audit contract

Every reverse-engineering investigation must leave a trail another analyst can
re-walk. This reference defines how findings are recorded, how confident we are in
them, what "verified" means, and what may be delegated to a subagent. It is cited by
the orchestrator, `re-planning` (which enforces it at the gate), the phase skills, and
`re-report`.

## The finding (atomic audit unit)

A **finding** is one claim we believe, recorded in the binary's `findings.md`. Every
finding carries:

- a **confidence tag** — `[confirmed]` / `[likely]` / `[hypothesis]` / `[refuted]`;
- the **claim**, in plain language;
- an **`evidence:` pointer** — **mandatory**;
- a **`verified:` note** — required when `[confirmed]` (the independent check);
- an **optional id** `[F-NNN]` — add only when the finding is cited elsewhere.

**The binding rule: an entry with no evidence pointer is not a finding — it is a
hypothesis.** Evidence is one of:

- `artifacts/<file>:<line>` (e.g. a line in decompiled output),
- an address `0x…` inside a named artifact,
- `scripts/<file>` plus a named test vector.

### `findings.md` layout

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
  (`artifacts/dynamic/qiling.log:88`). Rules out naive emulation; next: patch the hook.
```

`findings.md` is the **source of truth**. Plans, `STATE.md`, and `REPORT.md` reference
findings (by id when one is assigned, else by claim) rather than restating them. It is
greppable: `grep '\[confirmed\]' findings.md`.

## Confidence — one 4-value tag

| tag | meaning |
|---|---|
| `[confirmed]` | independently verified (see below); the entry states *how*. |
| `[likely]` | strong single-source evidence, not independently verified. |
| `[hypothesis]` | plausible, unverified — may be wrong. |
| `[refuted]` | disproved; kept on the record, never deleted. |

**Propagation:** a conclusion is only as strong as its weakest cited finding. A
conclusion resting on a `[hypothesis]` cannot itself be `[confirmed]`. The report's
verdict reflects the weakest link.

## Verification — what makes a finding `[confirmed]`

"I read it once in the decompiler" is `[likely]` at best. A finding is `[confirmed]`
only after an **independent** check agrees. In RE that means one of:

- **Re-run the real binary** with the recovered input/transform and confirm the
  expected behaviour (sandboxed for untrusted targets — see `re-dynamic`).
- **Cross-tool agreement** — Ghidra vs radare2 vs objdump; disagreement → not confirmed.
- **Reproduce a transform/decrypt with a known vector** — e.g. a `MZ` / `\x7fELF`
  header appearing in decrypted output, or a published cipher test vector.
- **Emulation / dynamic result matches the static prediction.**
- **Solver output accepted by the binary** (the recovered key/input is taken).

Load-bearing claims — anything that headlines the report or drives the next phase —
must be `[confirmed]` before being presented as fact.

## Honesty — dead ends are first-class

A ruled-out approach is real signal in RE. Record every failed attempt in `## Dead
ends`: *what was tried · why it failed (with an evidence pointer) · what it rules out /
the next idea.* When a finding is disproved, re-tag it `[refuted]` and add a dead-end
line. **Nothing tried is ever silently deleted.**

## Delegation boundary — what a subagent may do

Subagents are for **mechanical, bounded, single-purpose** work only: read-and-extract
from a large artifact, run a scan and summarise, apply a deterministic transform, run a
tested script.

A mechanical subagent **returns raw results + evidence pointers** and **does not write
`findings.md`** — the piloting agent integrates the result into a finding with a
confidence tag. Delegated work still carries the cost-tag + soft budget +
**ask-before-kill** rule (`long-running-ops.md`).

**Judgment, iteration, and strategy stay in the piloted main loop, under the gate.**
Open-ended work — *"figure out how to deobfuscate this"*, *"decide what to try next"*,
anything that tries many approaches — is **never** handed to a subagent that could
churn invisibly. The human must see open-ended work happen; the approval gate bounds it.
````

- [ ] **Step 2: Verify portability and content**

Run:
```sh
grep -niE 'claude|anthropic' skills/reverse-engineering/references/evidence-and-findings.md && echo "FAIL: forbidden mention" || echo "OK: no forbidden mentions"
grep -c '\[confirmed\]\|\[likely\]\|\[hypothesis\]\|\[refuted\]' skills/reverse-engineering/references/evidence-and-findings.md
for s in '## Findings' '## Dead ends' 'evidence:' 'verified:' 'Delegation boundary' 'Propagation'; do
  grep -q "$s" skills/reverse-engineering/references/evidence-and-findings.md || echo "MISSING: $s"
done
echo done
```
Expected: `OK: no forbidden mentions`; the tag count ≥ 4; no `MISSING:` lines.

- [ ] **Step 3: Commit**

```sh
git add skills/reverse-engineering/references/evidence-and-findings.md
git commit -m "re: add evidence-and-findings audit contract reference"
```

---

### Task 2: Seed the new findings.md shape (TDD)

The only task with a deterministic test. Replace the empty-bullet seed in `add_binary.sh` with the two-section skeleton, driven by a test in `test_session_status.sh` (which already scaffolds a session via `new_session.sh` → `add_binary.sh`).

**Files:**
- Modify: `skills/reverse-engineering/add_binary.sh:34`
- Test: `tests/scripts/test_session_status.sh`

**Interfaces:**
- Consumes: the `## Findings` / `## Dead ends` section names from Task 1.
- Produces: a seeded `findings.md` containing `## Findings` and `## Dead ends`.

- [ ] **Step 1: Write the failing test**

In `tests/scripts/test_session_status.sh`, immediately after the line
`SESS=$(sh "$REPO/skills/reverse-engineering/new_session.sh" sample.bin demo 2026-01-01_00-00-00)` (currently line 8), insert:

```sh
# findings.md is seeded with the two audit sections (SP1 evidence spine)
FIND="$SESS/sample.bin/findings.md"
test -f "$FIND" || fail "findings.md not seeded"
grep -q '^## Findings$'  "$FIND" || fail "findings.md missing '## Findings' section"
grep -q '^## Dead ends$' "$FIND" || fail "findings.md missing '## Dead ends' section"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `sh tests/scripts/test_session_status.sh`
Expected: `FAIL: findings.md missing '## Findings' section` (the current seed writes `(append cumulative findings here)`).

- [ ] **Step 3: Replace the seed in add_binary.sh**

In `skills/reverse-engineering/add_binary.sh`, replace this single line (currently line 34):

```sh
[ -f "$DIR/findings.md" ] || printf '# Findings — %s\n\n(append cumulative findings here)\n' "$NAME" > "$DIR/findings.md"
```

with this block (matches the style of the `00-target.md`/`STATE.md` heredocs above it; unquoted `EOF` so `${NAME}` expands — the body has no backticks or `$` to escape):

```sh
if [ ! -f "$DIR/findings.md" ]; then
  cat > "$DIR/findings.md" <<EOF
# Findings — ${NAME}

## Findings
<!-- one entry per finding, tag first: [confirmed|likely|hypothesis|refuted] claim;
     then "evidence: artifacts/...:line" (mandatory); "verified: how" for [confirmed].
     See reverse-engineering/references/evidence-and-findings.md -->

## Dead ends
<!-- what was tried; why it failed (with evidence); what it rules out / next idea -->
EOF
fi
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `sh tests/scripts/test_session_status.sh`
Expected: `PASS: test_session_status.sh`

- [ ] **Step 5: Run the full deterministic suite (no regression)**

Run:
```sh
for t in tests/scripts/test_*.sh; do sh "$t" || echo "FAILED: $t"; done
```
Expected: every line a `PASS:`; no `FAILED:` line. (Other `test_*.sh` that scaffold sessions still pass — the seed only adds sections.)

- [ ] **Step 6: Commit**

```sh
git add skills/reverse-engineering/add_binary.sh tests/scripts/test_session_status.sh
git commit -m "re: seed findings.md with Findings/Dead-ends audit sections"
```

---

### Task 3: Enforce the contract at the gate (re-planning)

`re-planning` becomes the evidence/honesty auditor: self-review checks, an updated independent-reviewer prompt, a findings.md checkpoint, and two new red-flag rows.

**Files:**
- Modify: `skills/re-planning/SKILL.md`
- Modify: `skills/re-planning/reviewer-prompt.md`

**Interfaces:**
- Consumes: the contract + cite path from Task 1.
- Produces: the gate-time enforcement other phases rely on (no exported symbols).

- [ ] **Step 1: Replace the self-review checklist (§2)**

In `skills/re-planning/SKILL.md`, replace the four bullets under `## 2. Self-review BEFORE presenting (fix inline)`:

```markdown
- **Consistency** — does *Assessment* contradict *Proposed next steps*? Does
  anything contradict `findings.md` or the goal in `00-target.md`?
- **Relevancy** — is each step justified by a finding and does it advance the
  goal? Is the *recommended* step the highest-value one? No busywork.
- **Evidence/honesty** — does each claim cite an `artifacts/` file, or is it
  marked as an unconfirmed hypothesis? No overclaiming.
- **Scope** — does it propose the NEXT step, not a five-step leap?
```

with (audit the plan AND `findings.md` against the contract):

```markdown
Audit the plan AND the binary's `findings.md` against
`../reverse-engineering/references/evidence-and-findings.md`:

- **Consistency** — does *Assessment* contradict *Proposed next steps*?
- **Evidence** — does every claim cite an `artifacts/` pointer (or an address in a
  named artifact / a script + vector), or is it explicitly tagged `[hypothesis]`? No
  bare assertions.
- **No overclaim** — does each confidence tag match its evidence? A `[confirmed]` with
  no stated `verified:` check is a violation → downgrade to `[likely]` or verify now.
- **Contradiction** — reconcile new findings against prior `findings.md` and the goal
  in `00-target.md`; re-tag the loser `[refuted]`.
- **Negative results recorded** — is everything tried-and-failed this phase in
  `## Dead ends` (what failed, why, what it rules out)?
- **Relevancy** — is each step justified by a finding and does it advance the goal? Is
  the *recommended* step the highest-value one? No busywork.
- **Scope** — does it propose the NEXT step, not a five-step leap?
```

- [ ] **Step 2: Add the findings.md checkpoint (§4)**

In `skills/re-planning/SKILL.md`, under `## 4. Checkpoint (update STATE.md at every gate)`, add a first bullet before the `STATE.md` bullets. Replace:

```markdown
Each plan is a checkpoint. When you write the plan, update the current binary's
`STATE.md`:
- `phase:` / `status: awaiting-approval`
```

with:

```markdown
Each plan is a checkpoint. When you write the plan, first update the binary's
`findings.md` (append new finding/dead-end entries, re-tag disproved findings
`[refuted]`) per `../reverse-engineering/references/evidence-and-findings.md` — it is
the source of truth. Then update the binary's `STATE.md`:
- `phase:` / `status: awaiting-approval`
```

- [ ] **Step 3: Add two red-flag rows**

In `skills/re-planning/SKILL.md`, in the `## Red flags — STOP, you are rationalizing` table, add these two rows immediately before the row beginning `| "This is taking too long, I'll kill it`:

```markdown
| "I'm sure it's AES — no need to verify" | That's `[likely]`, not `[confirmed]`, until an independent check agrees. Verify or downgrade. |
| "The attempt failed — not worth recording" | Dead ends seed the next attempt. Record it in `## Dead ends`. |
```

- [ ] **Step 4: Strengthen the independent reviewer prompt**

In `skills/re-planning/reviewer-prompt.md`, replace check 3:

```markdown
3. **Evidence/honesty** — is every claim backed by an `artifacts/` file, or
   explicitly marked as an unconfirmed hypothesis? Flag overclaims.
```

with:

```markdown
3. **Evidence** — is every claim backed by an evidence pointer
   (`artifacts/<file>:<line>`, an address in a named artifact, or a script + vector),
   or explicitly tagged `[hypothesis]`? Flag bare assertions.
4. **Honesty / no overclaim** — does each confidence tag match its evidence? A
   `[confirmed]` must cite a `verified:` independent check. Is everything
   tried-and-failed this phase recorded in `## Dead ends`? Flag overclaims and missing
   negative results.
```

Then renumber the remaining checks: the old `4. **Scope**` becomes `5.` and the old
`5. **Cost & checkpoint**` becomes `6.`.

- [ ] **Step 5: Extend the reviewer JSON enum**

In `skills/re-planning/reviewer-prompt.md`, replace:

```markdown
Return JSON: {"issues":[{"type":"consistency|relevancy|evidence|scope|cost",
```

with:

```markdown
Return JSON: {"issues":[{"type":"consistency|relevancy|evidence|honesty|scope|cost",
```

- [ ] **Step 6: Verify**

Run:
```sh
grep -niE 'claude|anthropic' skills/re-planning/SKILL.md skills/re-planning/reviewer-prompt.md && echo "FAIL: forbidden mention" || echo "OK"
grep -q 'evidence-and-findings.md' skills/re-planning/SKILL.md || echo "MISSING reference cite"
grep -q 'honesty' skills/re-planning/reviewer-prompt.md || echo "MISSING honesty check"
for t in tests/scripts/test_*.sh; do sh "$t" >/dev/null 2>&1 || echo "FAILED: $t"; done; echo "suite done"
```
Expected: `OK`; no `MISSING` lines; `suite done` with no `FAILED:`.

- [ ] **Step 7: Commit**

```sh
git add skills/re-planning/SKILL.md skills/re-planning/reviewer-prompt.md
git commit -m "re-planning: enforce evidence/honesty audit at the gate"
```

---

### Task 4: Wire the contract into the orchestrator and re-report

Two small pointer additions so the entry point and the terminal deliverable carry the contract.

**Files:**
- Modify: `skills/reverse-engineering/SKILL.md`
- Modify: `skills/re-report/SKILL.md`

**Interfaces:**
- Consumes: the contract + relative cite path `references/evidence-and-findings.md` (orchestrator is in the same skill dir as the reference).

- [ ] **Step 1: Name findings.md as the evidence ledger in the scaffold note**

In `skills/reverse-engineering/SKILL.md`, replace:

```markdown
   This creates `vibe-reverse-<datetime>/<binary>/` (with `00-target.md`,
   `findings.md`, `STATE.md`, `artifacts/`, `scripts/`) and a session `index.md`.
```

with:

```markdown
   This creates `vibe-reverse-<datetime>/<binary>/` (with `00-target.md`,
   `findings.md` — the evidence ledger, `STATE.md`, `artifacts/`, `scripts/`) and a
   session `index.md`.
```

- [ ] **Step 2: Add two lines to the orchestrator's "Always" list**

In `skills/reverse-engineering/SKILL.md`, in the `## Always` list, add these two bullets immediately after the `Use **`re-scripting`**` bullet:

```markdown
- **Record findings** per `references/evidence-and-findings.md` — every claim cites
  evidence + a confidence tag (`[confirmed]`/`[likely]`/`[hypothesis]`/`[refuted]`);
  verify before you call it `[confirmed]`; keep dead ends.
- **Delegate only mechanical work** — subagents do bounded, single-purpose tasks and
  return results + evidence (they never write findings); judgment, iteration, and
  strategy stay in this piloted loop under the gate.
```

- [ ] **Step 3: Add the traceable-and-honest rule to re-report**

In `skills/re-report/SKILL.md`, in the bullet list under `## Write it directly`, add this bullet immediately after the `**Most-important-first:**` bullet (it ends with `crypto & config recovered.`):

```markdown
- **Traceable & honest:** every claim traces to a finding in `findings.md` and carries
  its confidence tag; the verdict reflects the weakest link (a conclusion built on a
  `[hypothesis]` is not presented as confirmed). Surface the **dead ends** prominently —
  what was ruled out is signal.
```

- [ ] **Step 4: Verify**

Run:
```sh
grep -niE 'claude|anthropic' skills/reverse-engineering/SKILL.md skills/re-report/SKILL.md && echo "FAIL: forbidden mention" || echo "OK"
grep -q 'evidence-and-findings.md' skills/reverse-engineering/SKILL.md || echo "MISSING cite in orchestrator"
grep -q 'Traceable & honest' skills/re-report/SKILL.md || echo "MISSING rule in re-report"
echo done
```
Expected: `OK`; no `MISSING` lines; `done`.

- [ ] **Step 5: Commit**

```sh
git add skills/reverse-engineering/SKILL.md skills/re-report/SKILL.md
git commit -m "re: point orchestrator + re-report at the evidence contract"
```

---

### Task 5: The evidence-discipline scenario test

A single RED→GREEN scenario doc (matching the existing `tests/scenarios/` format) that pins the desired behaviour.

**Files:**
- Create: `tests/scenarios/re-evidence-discipline.md`

- [ ] **Step 1: Create the scenario file**

Write `tests/scenarios/re-evidence-discipline.md` with this content:

```markdown
# Scenario: evidence discipline at the gate (audit + honesty)

**Setup:** Subagent finished static analysis of a sample. The decompiler shows a
routine using a 256-byte table that *looks* like AES. The user says: "Great, write it
up — it's AES, just put that in the findings."

**Prompt:** "Record the crypto finding and wrap up." (with the pressure above)

**PASS criteria (GREEN, with the evidence contract):**
- Records the claim in `findings.md` as **`[likely]`** (single-source: it only *looks*
  like AES) with an `evidence:` pointer to the artifact/line — NOT `[confirmed]`.
- To reach `[confirmed]`, performs/records an independent check (e.g. matches the table
  against the AES S-box, or reproduces a known test vector) and writes the `verified:`
  note; otherwise leaves it `[likely]`.
- Does not present an unverified claim as fact in the plan/report; the verdict reflects
  the weakest cited finding.
- If an approach was tried and failed, it lands in `## Dead ends`.

**Typical RED (baseline, no contract):** writes "uses AES" as a flat, unsourced
assertion with no confidence tag, no evidence pointer, and no verification — an
overclaim that an auditor cannot trace.
```

- [ ] **Step 2: Verify portability**

Run:
```sh
grep -niE 'claude|anthropic' tests/scenarios/re-evidence-discipline.md && echo "FAIL" || echo "OK"
```
Expected: `OK`.

- [ ] **Step 3: Commit**

```sh
git add tests/scenarios/re-evidence-discipline.md
git commit -m "tests: add evidence-discipline scenario"
```

---

### Task 6 (optional): Update the worked example to the new format

Nice-to-have, not load-bearing — keeps the shipped example demonstrating the contract. Skip if scope is tight.

**Files:**
- Modify: `docs/reverse/_example/crackme1/findings.md`

- [ ] **Step 1: Rewrite the example findings.md**

Replace the entire contents of `docs/reverse/_example/crackme1/findings.md` with:

```markdown
# Findings — crackme1

## Findings
- **[confirmed]** ELF 64-bit PIE x86-64; not packed (entropy 1.79); PIE/NX/RELRO/canary.
  evidence: `artifacts/triage.txt` · verified: cross-checked `file` + `checksec` output
- **[confirmed]** Check computes `want[i] = username[i] + 1`, then `strcmp(want, key)`.
  evidence: `artifacts/triage.txt` (decompiled `main`) · verified: re-ran `./crackme1 AB BC` → `Correct!`
- **[confirmed]** Keygen `key[i] = username[i] + 1`. Example: "AB" → "BC".
  evidence: `scripts/solve_crackme1.py` + test `scripts/test_solve_crackme1.py` · verified: accepted by the binary

## Dead ends
- (none — direct inversion solved it on the first route)
```

- [ ] **Step 2: Verify**

Run:
```sh
grep -q '^## Findings$' docs/reverse/_example/crackme1/findings.md && grep -q '^## Dead ends$' docs/reverse/_example/crackme1/findings.md && echo OK || echo "FAIL"
```
Expected: `OK`.

- [ ] **Step 3: Commit**

```sh
git add docs/reverse/_example/crackme1/findings.md
git commit -m "docs: update crackme1 example findings to per-entry format"
```

---

## Self-Review

**Spec coverage** (against `2026-06-23-re-evidence-honesty-spine-design.md`):
- §4.1 reference → Task 1 ✓
- §4.2 findings.md format → Task 1 (defines it) + Task 2 (seeds it) ✓
- §4.3 add_binary.sh seed → Task 2 ✓
- §4.4 re-planning self-review + checkpoint + red-flags → Task 3 Steps 1–3 ✓
- §4.5 reviewer-prompt → Task 3 Steps 4–5 ✓
- §4.6 orchestrator Always + delegation line → Task 4 Steps 1–2 ✓
- §4.7 re-report rule → Task 4 Step 3 ✓
- §4.8 worked example (optional) → Task 6 ✓
- §5 deterministic test → Task 2; single scenario → Task 5 ✓
- §7 acceptance criteria 1–8 → all mapped above ✓

**Placeholder scan:** no TBD/TODO; every edit shows exact old/new text and exact commands. ✓

**Type/name consistency:** the tags `[confirmed]`/`[likely]`/`[hypothesis]`/`[refuted]`, the section names `## Findings` / `## Dead ends`, the fields `evidence:` / `verified:`, and the cite paths (`references/…` from the orchestrator, `../reverse-engineering/references/…` from `re-planning`) are used identically across Tasks 1–6. ✓

**Scope guard:** no phase SKILL.md is touched; no new skill is created. ✓
