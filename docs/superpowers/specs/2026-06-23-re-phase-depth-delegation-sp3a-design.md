# RE harness overhaul — SP3a: Phase depth + delegation (foundation + core phases)

> **Status:** design approved (brainstorming), ready for implementation plan.
> **Scope of this spec:** sub-project **SP3a** of the RE-skills overhaul.
> **Depends on:** SP1 (evidence & honesty spine) and SP2 (reporting) — both merged to `main`.
> **Followed by:** SP3b (apply the same machinery to the 6 advanced phases).
> **Audience:** an engineer/agent implementing the change to the `skills/` tree.

## 1. Why

The phase skills tell you *what step to run* but rarely *how to do the analysis well*
or *what failure modes betray a wrong turn* — the gap vs. the `systematic-debugging`
quality bar. And the piloting agent reads heavy artifacts (decompiled C, long traces)
itself, polluting its context on real binaries. SP3a closes both for the three
**core** phases — `re-triage`, `re-static`, `re-dynamic` — and builds the reusable
machinery SP3b will reuse for the advanced phases.

It honors two existing constraints:
- the family's **lean SKILL.md** rule (`references/agent-tools.md`: SKILL.md < 500 lines,
  push detail into `references/`) — so depth lives in per-phase **playbooks**, not inline;
- SP1's **delegation boundary** (`evidence-and-findings.md`: mechanical-only subagents,
  return results + evidence, never write findings, judgment stays piloted) — SP3a adds
  the *mechanics* on top of that *boundary*.

## 2. Roadmap recap

| # | Sub-project | Delivers |
|---|---|---|
| **SP3a** *(this spec)* | Foundation + core phases | The depth-playbook convention + a shared delegation reference & dispatch template; applied to `re-triage`/`re-static`/`re-dynamic`. |
| SP3b | Advanced phases | The same machinery applied to `re-deobfuscate`/`re-devirtualize`/`re-antianalysis`/`re-crypto`/`re-config`/`re-solve`. |

## 3. Design

### 3.1 The depth-playbook structure (the convention SP3b also follows)
Each phase gets `skills/<phase>/references/<phase>-playbook.md`, right-sized per phase
(~80–150 lines, well under 500), with these five sections in order:

1. **Method** — numbered steps for doing the phase *well* (beyond "run the script"):
   where to start, what to look at, how to interpret the signals, and how to record
   findings (cite `../../reverse-engineering/references/evidence-and-findings.md`).
2. **Failure modes / wrong-track signals** — what betrays a wrong turn.
3. **Red flags — STOP** — phase-specific rationalizations, as a table.
4. **Have I understood enough?** — explicit exit criteria, so the agent neither bails
   early nor rabbit-holes.
5. **Worked example** — one concrete walk-through (teaching-oriented).

The SKILL.md is **not** deepened inline; it gains only short pointers (3.4).

### 3.2 The delegation reference + template
New `skills/reverse-engineering/references/delegating-to-subagents.md` (spine), built on
SP1's boundary (which it cross-references). Contents:

- **When to delegate:** a large/verbose artifact must be read to extract a *specific*
  thing (decompiled C, a long trace, a capa/FLOSS dump), a deterministic transform, or a
  tested script run.
- **The dispatch contract:** focused scope (one artifact, one question) · self-contained
  context (the file path + exactly what to extract — *not* the investigation history) ·
  specific output (raw results + **evidence pointers** `artifacts/<file>:<line>` or
  addresses) · **never writes `findings.md` or makes routing decisions**.
- **A tool-neutral dispatch-prompt template**, e.g.:
  ```
  Delegate (mechanical, read-only):
  - Artifact: artifacts/<file>
  - Extract: <exactly what — e.g. "the full body of function check_license + any constants it uses">
  - Return: the extracted content + an evidence pointer (artifacts/<file>:<line> or 0x… address).
    Do NOT interpret intent, do NOT write findings, do NOT decide next steps.
  ```
- **Budget:** delegated mechanical work still carries the cost-tag + soft budget +
  **ask-before-kill** rule (cross-ref `long-running-ops.md`). *If a task would need the
  subagent to "try many things," that is the signal NOT to delegate — keep it piloted.*
- **Integrate:** the piloting agent turns the returned results into findings with
  confidence tags (per the evidence contract).
- **Red flags — STOP** table: e.g. *"send a subagent to crack this"* → no, that's
  judgment; *"let it figure out the approach"* → no; *"paste the whole investigation so
  it has context"* → no, give it only the artifact + the extraction ask.

### 3.3 Per-phase application (what each playbook covers)

**`re-triage` → `references/triage-playbook.md`** (lighter — triage is mostly mechanical):
- *Method:* run `triage.sh`; interpret type/arch/size/entropy/packer/protections/strings;
  map family → route; record a triage finding.
- *Interpretation:* entropy > 7 ≈ packed **or** encrypted resources **or** compression
  (confirm with DIE, don't assume UPX); imports/strings hints (`strcmp`, crypto, usage
  text); protections as later-phase context.
- *Failure modes:* high entropy but not packed; family misdetected (e.g. a .NET PE reads
  as native to `file`); treating triage as deep analysis.
- *Exit criteria:* format, arch, packing status, and family known → route. Do **not**
  decompile here.
- *Worked example:* crackme1 (native ELF, low entropy, `strcmp` → route to static).

**`re-static` → `references/static-playbook.md`** (fuller):
- *Method:* get the decompile/disasm (Ghidra → r2 → objdump); locate the entry/`main`/the
  relevant function (skip CRT/libc); read the target's logic; run capa/FLOSS; form
  findings with evidence (`artifact:line`); assess routing (packed? crypto? solver-
  friendly? dynamic needed?).
- *Delegation:* a large decompiled artifact → delegate the *read* to extract a specific
  function (mechanical); big capa/FLOSS dumps → delegate the *summarize*. Integrate as
  findings.
- *Failure modes:* reading library/CRT code instead of the target; trusting a single
  decompiler (cross-check → otherwise `[likely]`, not `[confirmed]`); missing packing
  (high entropy in `.text`); assuming a value is constant without checking.
- *Exit criteria:* the target's relevant logic is understood well enough to route or
  solve; key functions are findings with evidence.
- *Worked example:* crackme1 (found the `+1` transform in `main`; routed to solve).

**`re-dynamic` → `references/dynamic-playbook.md`** (fuller; safety-critical):
- *Method:* **sandbox only** (cross-ref the SKILL's core rule); pick trace vs gdb vs
  emulate; run; read the trace for the comparison / syscalls / network; capture runtime
  values; record findings with evidence (`trace:line`).
- *Delegation:* a long trace artifact → delegate the *read* to extract the relevant
  calls; **never** delegate the decision to run or the strategy.
- *Failure modes:* an empty/short trace usually means **sandbox detected** (→
  `re-antianalysis`), not "nothing happens"; wrong args/input; emulation rootfs/hooks
  wrong; mistaking emulator artifacts for real behavior.
- *Exit criteria:* observed the behaviour you needed (the comparison, the dropped file,
  the C2 callback) with evidence; or confirmed evasion → route to `re-antianalysis`.
- *Worked example:* detonate in the microVM, read `strace` for the comparison.

### 3.4 Lean SKILL.md changes (per core phase)
Each of `re-triage`/`re-static`/`re-dynamic` SKILL.md gains two short pointers; nothing
is removed and the terse workflow stays:
- *Method, failure modes, and a worked example: `references/<phase>-playbook.md`.*
- A per-phase **when-to-delegate** line citing
  `../reverse-engineering/references/delegating-to-subagents.md` (e.g. re-static:
  "reading a large decompiled artifact to extract specific functions is mechanical —
  delegate it; you integrate the findings").

## 4. Files
- NEW `skills/reverse-engineering/references/delegating-to-subagents.md`
- NEW `skills/re-triage/references/triage-playbook.md` + MODIFY `skills/re-triage/SKILL.md`
- NEW `skills/re-static/references/static-playbook.md` + MODIFY `skills/re-static/SKILL.md`
- NEW `skills/re-dynamic/references/dynamic-playbook.md` + MODIFY `skills/re-dynamic/SKILL.md`
- NEW test + scenario (§5)

## 5. Tests (pragmatic)
- **Deterministic (sh, tool-optional, exit 0):** a check that each core phase SKILL.md
  references its `<phase>-playbook.md`, each playbook file exists and contains the five
  section headings, and no edited file mentions "claude"/"anthropic". Catches drift.
- **Scenario (one):** NEW `tests/scenarios/re-delegation-discipline.md` — GREEN delegates
  a *mechanical* huge-artifact read (subagent returns the extracted content + evidence
  pointers, writes no findings) and keeps the *judgment*/strategy in the piloted loop;
  RED either hand-reads the whole artifact into its own context or hands an open-ended
  "solve this" to a subagent.
- The full deterministic suite (sh + pytest) still exits 0.

## 6. Out of scope (deferred to SP3b)
- The 6 advanced phases (`re-deobfuscate`/`re-devirtualize`/`re-antianalysis`/`re-crypto`/
  `re-config`/`re-solve`) — no playbooks, no SKILL.md changes for them in SP3a.
- No change to the helper scripts, the gate, or the report.

## 7. Acceptance criteria
1. `delegating-to-subagents.md` exists: when-to-delegate, the dispatch contract, the
   tool-neutral template, the budget/ask-before-kill rule, the integrate step, and a
   red-flags table — cross-referencing the SP1 boundary.
2. Each core phase has a `references/<phase>-playbook.md` with the five sections (Method,
   Failure modes, Red flags, Have-I-understood-enough, Worked example), right-sized.
3. Each core phase SKILL.md carries the two lean pointers (playbook + when-to-delegate)
   and removes nothing.
4. The deterministic test asserts the SKILL→playbook references and the five headings;
   the delegation scenario describes the GREEN behaviour; the full suite exits 0.
5. No "claude"/"anthropic" mentions; relative paths only; every SKILL.md stays < 500
   lines; no advanced phase is touched.

## 8. Open questions
None — resolved during brainstorming: decompose **SP3a (foundation + core) → SP3b
(advanced)**; depth lives in **per-phase `references/` playbooks** (lean SKILL.md);
**delegation mechanics are included in SP3a**.
