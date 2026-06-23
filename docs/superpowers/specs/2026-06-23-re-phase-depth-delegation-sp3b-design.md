# RE harness overhaul — SP3b: Advanced-phase playbooks + routing relabel + deob/devirt loop

> **Status:** design approved (brainstorming), ready for implementation plan.
> **Scope of this spec:** sub-project **SP3b** — the **final** piece of the RE-skills overhaul.
> **Depends on:** SP1 (evidence spine), SP3a (core playbooks + delegation reference),
> SP4 (hypothesis loop) — all merged to `main`.
> **Audience:** an engineer/agent implementing the change to the `skills/` tree.

## 1. Why

SP3a brought the three core phases to systematic-debugging depth via per-phase
`references/<phase>-playbook.md`, and SP4 made `re-planning` a hypothesis-driven,
doubt-gated loop. SP3b finishes the overhaul: it (a) gives the **six advanced phases**
the same playbook depth, (b) makes the **deobfuscate↔devirtualize** relationship a clean
loop-ownership + hand-back (resolving the "weak loop" worry), and (c) lands the
**per-phase routing relabel** that SP4 deferred — reframing every phase's routing table
as a *hypothesis source* for the loop, so all nine phases speak SP4's language.

## 2. Roadmap recap
SP1 ✓ · SP2 ✓ · SP3a (core depth + delegation) ✓ · SP4 (hypothesis loop) ✓ ·
**SP3b (this — advanced depth + relabel + deob/devirt loop) → overhaul complete.**

## 3. Design

### 3.1 Six advanced playbooks
Each advanced phase gets `skills/<phase>/references/<phase>-playbook.md`, following the
**SP3a 5-section convention** verbatim (`## Method` / `## Failure modes` / `## Red flags`
/ `## Have I understood enough?` / `## Worked example`), right-sized, citing the existing
catalog from its Method (never duplicating it), and referencing the SP4 loop where the
phase has an internal loop/ordering. Per-phase content:

- **`re-deobfuscate` → `deobfuscate-playbook.md`** (fuller; cites `obfuscation-taxonomy.md`).
  Method frames the peel loop *as this phase's ranking heuristic feeding the `re-planning`
  loop*: inventory layers → rank outermost-first → apply the top layer's handler →
  **re-triage** → continue. Failure modes: peeling inner-first; not re-triaging after a
  peel; a peeled payload is a **new binary** (mandatory gate → `add_binary.sh`). Exit:
  entropy normal, strings/imports readable, control flow sane.
- **`re-devirtualize` → `devirtualize-playbook.md`** (fuller; cites `devirt-methodology.md`
  for the 7 steps). See 3.2 for loop ownership. Failure modes: assuming a clean VM when
  surrounding layers weren't peeled; presenting a partial lift as complete (confidence
  tag); nested-VM depth blowing the budget (🐢). Exit: dispatcher map + opcode→semantics
  table + a confidence-tagged partial lift with unresolved handlers listed.
- **`re-antianalysis` → `antianalysis-playbook.md`** (fuller; cites `anti-analysis-catalog.md`).
  Method: detect → neutralize → **re-verify it proceeds** → record each neutralized check.
  Failure modes: empty trace = evasion not inert; a stacked second check; self-integrity
  re-trigger after a patch. Exit: target proceeds past the checks.
- **`re-crypto` → `crypto-playbook.md`** (shorter; cites `crypto-id.md`). Method: identify
  → replicate as a tested pure function → verify with a known vector → hand to `re-config`.
  Failure modes: over-assuming AES when it's a lone XOR; missed custom key schedule; not
  verifying the decrypt. Exit: a tested decryptor reproduces known plaintext.
- **`re-config` → `config-playbook.md`** (shorter; cites `ioc-schema.md`). Method: gather
  decrypted strings/structs/dumps → populate `config.json` → write `iocs.md` + a YARA rule
  on **stable** signatures. Failure modes: a hardcoded C2 may be a sinkhole/decoy (tag
  confidence); volatile strings make brittle YARA. Exit: config + iocs + sanity-checked
  rule, fed to `re-report`.
- **`re-solve` → `solve-playbook.md`** (fuller; no catalog → fuller Method). Method: pick
  the route (direct inversion / z3 / angr) from `re-static`'s logic+addresses; write the
  solver test-first (`re-scripting`); **always verify against the real binary**. Failure
  modes: reaching for angr when inversion suffices (path explosion); wrong FIND/AVOID; not
  verifying. Exit: recovered input accepted by the real binary.

### 3.2 deob↔devirt loop ownership (decision A)
Decided in brainstorming: **keep `re-devirtualize` a standalone skill** (it owns its
triton/miasm templates + discoverability); make `re-deobfuscate` own the loop and treat
devirt as a worker.
- **`deobfuscate-playbook`**: when the outermost layer is a VM, the loop **dispatches
  `re-devirtualize`**, then **re-triages the lifted output and continues** — virtualization
  is a step inside the loop, not a dead-end exit. Red flag: *"jumped straight to devirt
  without entering the loop — a VM usually sits on/under other layers."*
- **`devirtualize-playbook`**: a **hand-back rule** — on a non-VM layer (encrypted
  bytecode, packing around the VM, interleaved anti-analysis) **return to
  `re-deobfuscate` / `re-crypto` / `re-antianalysis`**; do not improvise a peel loop here.

### 3.3 Routing relabel (the SP4-deferred bit) — all 9 phases
SP4 stated the principle (in `re-planning` + orchestrator) that routing tables are
hypothesis sources. SP3b lands it **per phase**: every phase whose SKILL presents a
routing table or "route on" list gets a **single relabel line** — e.g. *"These are
candidate hypotheses you propose to the `re-planning` loop, which ranks and gates — not
automatic jumps."* Applied to the **6 advanced phases** (rides with their SKILL edits)
**+ a small retrofit to the 3 core** (`re-triage`/`re-static`/`re-dynamic`, which got
playbooks in SP3a but no relabel). Light one-liner per phase, not a rewrite.

### 3.4 Lean SKILL pointers (6 advanced)
Each advanced SKILL gains the two SP3a-style pointers (nothing removed): *Method,
failure modes, worked example → `references/<phase>-playbook.md`*; and a per-phase
**when-to-delegate** line citing `../reverse-engineering/references/delegating-to-subagents.md`
(e.g. deob/devirt: delegate reading a huge lifted/handler dump; solve: delegate reading
angr output; config: delegate extracting strings from a dump).

## 4. Files
- NEW `skills/re-{deobfuscate,devirtualize,antianalysis,crypto,config,solve}/references/<phase>-playbook.md`
- MODIFY the same six `SKILL.md` (pointers + routing relabel line)
- MODIFY `skills/re-{triage,static,dynamic}/SKILL.md` (routing relabel line only — retrofit)
- MODIFY `tests/scripts/test_phase_playbooks.sh` (loop all 9 phases; glob the forbidden-mention check)
- NEW `tests/scenarios/re-deob-devirt-loop.md`

## 5. Tests (pragmatic)
- **Deterministic:** extend `test_phase_playbooks.sh` — change its loop to
  `triage static dynamic deobfuscate devirtualize antianalysis crypto config solve`, so it
  asserts all nine `<phase>-playbook.md` exist, are referenced by their SKILL, and carry
  the five headings; switch the forbidden-mention check to the
  `skills/re-*/references/*-playbook.md` glob.
- **Scenario:** NEW `tests/scenarios/re-deob-devirt-loop.md` — a *packed + virtualized*
  sample: GREEN enters `re-deobfuscate`'s loop (unpack → re-triage → dispatch
  `re-devirtualize`), and devirt **hands back** when it uncovers an inner encrypted layer;
  RED jumps straight to devirt and gets stuck, or devirt improvises its own peel loop.
- Full suite (sh + pytest) still exits 0.

## 6. Out of scope
- No change to phase *analysis logic*, helper scripts, the gate (SP4), the report (SP2),
  or the evidence contract (SP1) beyond consuming them.
- No merge of `re-devirtualize` into `re-deobfuscate` (decision A keeps it standalone).
- No new skill; no new shared reference (playbooks reuse the SP3a convention and the
  existing `delegating-to-subagents.md`).

## 7. Acceptance criteria
1. Each of the six advanced phases has a `references/<phase>-playbook.md` with the five
   sections, right-sized, its Method citing the existing catalog (solve excepted), and
   referencing the SP4 loop where it has an internal loop.
2. `deobfuscate-playbook` encodes the loop dispatching `re-devirtualize` + re-triage;
   `devirtualize-playbook` encodes the hand-back rule; `re-devirtualize` stays standalone.
3. Every phase with a routing table carries the one-line relabel (6 advanced + 3 core retrofit).
4. Each advanced SKILL has the two lean pointers (playbook + when-to-delegate).
5. `test_phase_playbooks.sh` covers all nine phases and passes; the
   `re-deob-devirt-loop` scenario describes the GREEN behaviour; full suite exits 0.
6. No "claude"/"anthropic" in content files; relative paths only; every SKILL.md < 500 lines.

## 8. Open questions
None — resolved in brainstorming: **uniform standalone playbooks, Method cites the
catalog**; **decision A** (devirt standalone, deob owns the loop, devirt hands back); the
**routing relabel is a light one-liner per phase** including a 3-core retrofit; playbooks
**reference the SP4 loop**.
