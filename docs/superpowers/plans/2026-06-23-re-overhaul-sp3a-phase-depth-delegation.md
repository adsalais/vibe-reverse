# SP3a — Phase Depth + Delegation (foundation + core phases) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the three core phases (`re-triage`/`re-static`/`re-dynamic`) systematic-debugging-level depth via per-phase `references/` playbooks, and add a shared subagent-delegation reference, without bloating any SKILL.md.

**Architecture:** Depth lives in `references/<phase>-playbook.md` (five fixed sections); a spine reference `delegating-to-subagents.md` defines the mechanical-delegation mechanics on SP1's boundary; each core SKILL.md gains two lean pointers (playbook + when-to-delegate). Reference-only changes — no helper-script, gate, or report changes.

**Tech Stack:** Markdown skills/references; POSIX-sh deterministic test.

**Spec:** `docs/superpowers/specs/2026-06-23-re-phase-depth-delegation-sp3a-design.md`

## Global Constraints

- **No "claude"/"anthropic" mentions** anywhere — tool-neutral, portable.
- **Relative paths only.** From a SKILL.md: `../reverse-engineering/references/<f>`. From a `references/` playbook: `../../reverse-engineering/references/<f>`.
- **Every SKILL.md stays < 500 lines** — depth goes in `references/`, only pointers in the SKILL.
- **Delegation is mechanical-only** — subagents return results + evidence pointers, never write `findings.md`, never decide routing; judgment/iteration stays piloted (SP1 boundary in `evidence-and-findings.md`).
- **Each playbook has these five section headings, in order:** `## Method`, `## Failure modes / wrong-track signals`, `## Red flags — STOP`, `## Have I understood enough?`, `## Worked example`.
- **SP3a scope:** only `re-triage`/`re-static`/`re-dynamic` + the delegation reference. No advanced phase, no script/gate/report change.

---

### Task 1: The delegation reference

The shared spine reference the core phases cite. No logic; verified by content + portability greps.

**Files:**
- Create: `skills/reverse-engineering/references/delegating-to-subagents.md`

**Interfaces:**
- Produces: the cite target `../reverse-engineering/references/delegating-to-subagents.md` (from a SKILL) and the dispatch contract the playbooks reference.

- [ ] **Step 1: Create the file** with exactly this content:

````markdown
# Delegating to subagents — mechanical work only

Subagents preserve the piloting agent's context by doing **bounded, mechanical** work and
returning a tight result. The boundary is set by `evidence-and-findings.md` (the SP1
contract): mechanical-only, return results + evidence pointers, **never write findings**,
and judgment / iteration / strategy stay in the piloted loop under the gate. This
reference is the *how*.

## When to delegate

Delegate when the work is mechanical, bounded, and single-purpose:
- **Read a large/verbose artifact to extract a specific thing** — a function out of
  decompiled C, the relevant calls out of a long strace, the hits out of a capa/FLOSS dump.
- **Apply a deterministic transform** — decode/transform a blob with a *known* routine.
- **Run a tested script** and return its output.

Do NOT delegate judgment: deciding the approach, "figure out how to deobfuscate this",
choosing the next phase, or anything that needs trying several things. That stays with
you, in view of the human, bounded by the gate.

## The dispatch contract

A good mechanical dispatch is:
- **Focused** — one artifact, one question. Not "analyze this binary".
- **Self-contained** — give the subagent the artifact path and exactly what to extract.
  Do NOT paste the investigation history; it does not need (or get) your context.
- **Specific about output** — it returns the extracted content **plus an evidence
  pointer** (`artifacts/<file>:<line>` or a `0x…` address), and nothing else.
- **Bounded** — it must not write `findings.md`, edit files, or decide next steps.

### Template

```
Delegate (mechanical, read-only):
- Artifact: artifacts/<file>
- Extract: <exactly what — e.g. "the full body of function check_license and any
  constants/strings it references">
- Return: the extracted content + an evidence pointer (artifacts/<file>:<line> or 0x…).
  Do NOT interpret intent, do NOT write findings, do NOT decide next steps.
```

## Budget

Delegated work is still slow work: state the cost (⚡/⏳/🐢), run it under the soft budget,
and **ask before killing** — see `long-running-ops.md`. A mechanical read is usually ⚡/⏳.
**If you find yourself wanting the subagent to "try a few things" to get the answer, that
is the signal NOT to delegate** — the task is judgment; keep it piloted.

## Integrate

When the subagent returns, *you* turn its raw result into one or more findings with a
confidence tag and the evidence pointer it gave you (per `evidence-and-findings.md`). The
subagent surfaced the bytes; you decide what they mean.

## Red flags — STOP

| Thought | Reality |
|---|---|
| "Send a subagent to crack/solve/deobfuscate this" | That's judgment + iteration. Pilot it yourself under the gate. |
| "Let it figure out the approach and report back" | Open-ended = invisible churn. Delegate a *read*, not a decision. |
| "Paste the whole investigation so it has context" | It needs only the artifact + the extraction ask. History pollutes it. |
| "It can update findings.md while it's in there" | Subagents never write findings — you integrate the result. |
````

- [ ] **Step 2: Verify**

```sh
grep -niE 'claude|anthropic' skills/reverse-engineering/references/delegating-to-subagents.md && echo FAIL || echo OK
for s in 'When to delegate' 'dispatch contract' 'Template' 'Budget' 'Integrate' 'Red flags'; do
  grep -q "$s" skills/reverse-engineering/references/delegating-to-subagents.md || echo "MISSING: $s"
done; echo done
```
Expected: `OK`; no `MISSING`; `done`.

- [ ] **Step 3: Commit**

```sh
git add skills/reverse-engineering/references/delegating-to-subagents.md
git commit -m "re: add delegating-to-subagents reference (mechanical delegation mechanics)"
```

---

### Task 2: re-triage playbook + pointers

**Files:**
- Create: `skills/re-triage/references/triage-playbook.md`
- Modify: `skills/re-triage/SKILL.md`

- [ ] **Step 1: Create `skills/re-triage/references/triage-playbook.md`** with exactly this content:

```markdown
# Triage playbook — first look, done well

Triage identifies the artifact and routes it. It is **static and safe — never execute the
target.** The goal is a confident route, not deep understanding.

## Method

1. Run `triage.sh <target> <investigation-dir>` (writes `artifacts/triage.txt`).
2. Read the summary in order: **type / arch / size** → **entropy** → **packer** →
   **protections** (PIE/NX/RELRO/canary) → **strings** (usage text, imports like `strcmp`
   or crypto names, embedded secrets).
3. Map **family → route** (the SKILL's table): native → `re-static`; managed/wasm/firmware
   → that pack's roadmap.
4. Record a triage finding per `../../reverse-engineering/references/evidence-and-findings.md`
   — e.g. **[confirmed]** the format/arch/packing, evidence `artifacts/triage.txt`.

## Interpretation

- **Entropy > ~7.0** means high-entropy bytes — packing **or** encryption **or**
  compression **or** embedded compressed resources, not automatically a packer. Confirm
  with the packer line (DIE) before claiming "UPX".
- **Imports/strings** are the cheapest lead: `strcmp`/`memcmp` → a comparison check;
  crypto names/constants → `re-crypto`; many obfuscated strings → FLOSS in `re-static`.
- **Stripped / no symbols** is normal for release/malware; it is not "packed".

## Failure modes / wrong-track signals

- You start reading disassembly in triage — stop; that's `re-static`.
- You call it "packed" from entropy alone, with no packer signature.
- `file` says native but it's **managed** (a .NET PE, a Java class) — check for the CLR
  header / `PK` / `cafebabe` magic before routing to `re-static`.
- You treat a high-entropy *section* (a compressed resource) as a packed *binary*.

## Red flags — STOP

| Thought | Reality |
|---|---|
| "Let me start reversing the logic now" | Triage routes; it doesn't solve. Move to the right phase. |
| "Entropy is high, so it's UPX" | High entropy ≠ a specific packer. Confirm with DIE. |
| "It's stripped, so it's protected" | Stripping is normal. Not a protection finding. |

## Have I understood enough?

You are done when you know **format, architecture, packing status, and family**, and can
name the next phase. Anything deeper belongs to that phase. Do not decompile here.

## Worked example

`crackme1`: `triage.sh` reports ELF x86-64, entropy 1.79 (low → not packed), no packer,
PIE/NX/RELRO/canary, and a `strcmp` import. Family = native → record **[confirmed]** "ELF
x86-64, not packed" (evidence `artifacts/triage.txt`) and route to `re-static`. Time in
triage: one tool run.
```

- [ ] **Step 2: Add the pointers to `skills/re-triage/SKILL.md`** — replace:

```markdown
Triage is the **first look**. It is **static and safe — never execute the target.**
```

with:

```markdown
Triage is the **first look**. It is **static and safe — never execute the target.**

**Method, interpretation, failure modes, worked example:** `references/triage-playbook.md`.
Heavy-artifact reads (rare in triage — its output is small) delegate mechanically — see
`../reverse-engineering/references/delegating-to-subagents.md`.
```

- [ ] **Step 3: Verify + commit**

```sh
grep -q 'triage-playbook.md' skills/re-triage/SKILL.md || echo "MISSING ref"
grep -q '## Worked example' skills/re-triage/references/triage-playbook.md || echo "MISSING section"
grep -niE 'claude|anthropic' skills/re-triage/references/triage-playbook.md && echo FAIL || echo OK
git add skills/re-triage/references/triage-playbook.md skills/re-triage/SKILL.md
git commit -m "re-triage: add triage playbook + lean pointers"
```
Expected: no `MISSING`; `OK`.

---

### Task 3: re-static playbook + pointers

**Files:**
- Create: `skills/re-static/references/static-playbook.md`
- Modify: `skills/re-static/SKILL.md`

- [ ] **Step 1: Create `skills/re-static/references/static-playbook.md`** with exactly this content:

```markdown
# Static analysis playbook — read the target, not the noise

Static analysis understands the target's logic **without running it**. The skill is
finding the few functions that matter in a sea of boilerplate, and knowing when one tool's
output is trustworthy.

## Method

1. Decompile/disassemble: `ghidra_decompile.sh <target> <inv>` (Ghidra → r2 → objdump).
2. **Find the target's code, skip the noise.** Start at `main` / the entry / a function of
   interest (a `strcmp`, a crypto call, the string you saw in triage). Ignore CRT startup,
   libc, and compiler boilerplate.
3. **Read the relevant function(s)** and state what they do in plain language.
4. Run the capability + string scan: `static_scan.sh <target> <inv>` (capa + FLOSS); read
   the capa tags (ATT&CK/MBC) and the recovered strings.
5. **Record findings with evidence** per
   `../../reverse-engineering/references/evidence-and-findings.md` — cite
   `artifacts/<file>:<line>` or an address. One decompiler's output is `[likely]`; make it
   `[confirmed]` only with an independent check (cross-tool, or dynamic later).
6. **Assess the route** (the SKILL's table): packed/obfuscated → `re-deobfuscate`;
   crypto/config → `re-crypto`/`re-config`; anti-analysis → `re-antianalysis`; a
   computed-value check → `re-solve`; needs running → `re-dynamic`.

## Delegate the heavy reads

Decompiled C and capa/FLOSS dumps are large; reading them in full pollutes your context.
Delegate the **mechanical extraction** per
`../reverse-engineering/references/delegating-to-subagents.md` — e.g. "extract the body of
`check()` from `artifacts/ghidra/decompiled.c` + the constants it uses, with line
numbers." You integrate the returned function into a finding. Delegate the *read*, never
the *judgment* of what it means or where to go next.

## Failure modes / wrong-track signals

- **Reading libc/CRT** as if it were the target — if every function looks generic, jump to
  `main` / the imports of interest.
- **Single-source trust** — the decompiler "said" something; that is `[likely]`. Decompiler
  output can be wrong (bad types, missed xrefs). Cross-check r2/objdump or verify dynamically.
- **Missed packing** — `.text` has high entropy / little recognizable code → it's packed;
  go to `re-deobfuscate`, don't decompile the stub forever.
- **Assuming constants** — "this is always 0x10" without checking callers/data.

## Red flags — STOP

| Thought | Reality |
|---|---|
| "I'll read the whole decompilation myself" | It's huge. Delegate the mechanical read; integrate the result. |
| "The decompiler shows X, so X is confirmed" | One tool = `[likely]`. Cross-check or verify dynamically for `[confirmed]`. |
| "Let me just run it to see what it does" | That's `re-dynamic` (sandbox only). Static first. |
| "I'll trace every function to be safe" | Find the few that matter; the rest is noise. |

## Have I understood enough?

You are done when you can state the target's relevant logic well enough to **route or
solve**, and the key functions are findings with evidence. You do not need every function —
only the ones on the path to the goal.

## Worked example

`crackme1`: open `main`, skip `__libc_start_main` boilerplate. `main` reads
`argv[1]`/`argv[2]`, builds `want[i] = argv1[i] + 1`, then `strcmp(want, argv2)`. Record
**[likely]** (single decompiler) "check is a `+1` transform then `strcmp`", evidence
`artifacts/ghidra/decompiled.c:142`. It compares input to a *computed* value → route to
`re-solve` (direct inversion). The keygen run later makes it `[confirmed]`.
```

- [ ] **Step 2: Add the pointers to `skills/re-static/SKILL.md`** — replace:

```markdown
Static analysis only — **never run the target.**
```

with:

```markdown
Static analysis only — **never run the target.**

**Method, where to start, failure modes, worked example:** `references/static-playbook.md`.
Reading a large decompiled artifact to extract specific functions is **mechanical** —
delegate it per `../reverse-engineering/references/delegating-to-subagents.md` (the
subagent returns the function + evidence pointers; you integrate the findings).
```

- [ ] **Step 3: Verify + commit**

```sh
grep -q 'static-playbook.md' skills/re-static/SKILL.md || echo "MISSING ref"
grep -q '## Worked example' skills/re-static/references/static-playbook.md || echo "MISSING section"
grep -niE 'claude|anthropic' skills/re-static/references/static-playbook.md && echo FAIL || echo OK
git add skills/re-static/references/static-playbook.md skills/re-static/SKILL.md
git commit -m "re-static: add static playbook + lean pointers"
```
Expected: no `MISSING`; `OK`.

---

### Task 4: re-dynamic playbook + pointers

**Files:**
- Create: `skills/re-dynamic/references/dynamic-playbook.md`
- Modify: `skills/re-dynamic/SKILL.md`

- [ ] **Step 1: Create `skills/re-dynamic/references/dynamic-playbook.md`** with exactly this content:

```markdown
# Dynamic analysis playbook — run it safely, read the trace

Dynamic analysis observes the target **running** — but only inside a sandbox (see the
SKILL's core rule; never on the host). The skill is choosing the lightest technique that
answers your question, and reading the trace for the few events that matter.

## Method

1. **Confirm the sandbox** (microVM / `--network none` container / throwaway VM) and
   consent — per the SKILL's core rule. Record the sandbox in `00-target.md`.
2. **Pick the technique:** **trace** (`strace`/`ltrace`) for syscalls/library calls
   (files, network, the comparison); **gdb** to breakpoint, read a runtime value, or force
   a branch; **emulate** (qiling) to self-decrypt strings / drop config / run-to-unpack
   without full detonation.
3. **Run it** with the right arguments/input (the check often needs `argv`/stdin).
4. **Read the trace** for the events you care about: the `strcmp`/`memcmp` of your input,
   the `open`/`connect`/`write`, the dropped file. Capture the runtime values.
5. **Record findings with evidence** per
   `../../reverse-engineering/references/evidence-and-findings.md` — cite the trace
   artifact + line. Re-running the real binary and seeing the expected behaviour is a
   strong `[confirmed]` check.

## Delegate the heavy reads

A full strace/ltrace can be thousands of lines. Delegate the **mechanical extraction** per
`../reverse-engineering/references/delegating-to-subagents.md` — e.g. "from
`artifacts/dynamic/strace.log`, return every `openat`/`connect` line + line numbers."
Never delegate the *decision to run* or the *strategy* — running is judgment and is
dangerous; it stays piloted.

## Failure modes / wrong-track signals

- **Empty / very short trace** usually means the sample **detected the sandbox** and bailed
  (anti-debug/anti-VM/timing) — not "it does nothing". Route to `re-antianalysis`.
- **Wrong input** — the interesting path needs the right `argv`/stdin/file; a bare run exits
  early.
- **Emulation mismatch** — qiling rootfs/hooks wrong → behaviour diverges from the real
  binary. Treat emulator-only artifacts with suspicion until cross-checked.
- **Mistaking sandbox noise** (loader, environment) for the target's behaviour.

## Red flags — STOP

| Thought | Reality |
|---|---|
| "Just run it on the host quickly" | Untrusted code on the host = compromise. Sandbox only. |
| "The trace is empty, so it does nothing" | Suspect sandbox detection → `re-antianalysis`. |
| "Let a subagent run it and figure it out" | Running is judgment + dangerous. Pilot it yourself. |
| "Emulation worked, so the real binary does too" | Emulation can diverge. Cross-check before `[confirmed]`. |

## Have I understood enough?

You are done when you have **observed the behaviour you came for** (the comparison, the
dropped file, the C2 callback) with a trace artifact as evidence — or you have **confirmed
evasion** and should route to `re-antianalysis`. You need the answer to the question that
sent you here, not a full behavioural map.

## Worked example

A crackme that compares input at runtime: detonate in the microVM
(`vmrun.sh <sample> <inv> --mode trace`), then read `artifacts/dynamic/strace.log` for the
`read`/`write` around the comparison. It reads `argv[2]` and compares to a fixed string →
record **[confirmed]** "accepts key == <value>", evidence `artifacts/dynamic/strace.log:NN`.
```

- [ ] **Step 2: Add the pointers to `skills/re-dynamic/SKILL.md`** — replace:

```markdown
**This phase RUNS the target.** That is dangerous for untrusted binaries.
```

with:

```markdown
**This phase RUNS the target.** That is dangerous for untrusted binaries.

**Method, technique choice, failure modes, worked example:** `references/dynamic-playbook.md`.
Reading a long trace to extract the relevant calls is **mechanical** — delegate it per
`../reverse-engineering/references/delegating-to-subagents.md`; never delegate the decision
to run.
```

- [ ] **Step 3: Verify + commit**

```sh
grep -q 'dynamic-playbook.md' skills/re-dynamic/SKILL.md || echo "MISSING ref"
grep -q '## Worked example' skills/re-dynamic/references/dynamic-playbook.md || echo "MISSING section"
grep -niE 'claude|anthropic' skills/re-dynamic/references/dynamic-playbook.md && echo FAIL || echo OK
git add skills/re-dynamic/references/dynamic-playbook.md skills/re-dynamic/SKILL.md
git commit -m "re-dynamic: add dynamic playbook + lean pointers"
```
Expected: no `MISSING`; `OK`.

---

### Task 5: Drift test + delegation scenario

**Files:**
- Create: `tests/scripts/test_phase_playbooks.sh`
- Create: `tests/scenarios/re-delegation-discipline.md`

- [ ] **Step 1: Create `tests/scripts/test_phase_playbooks.sh`** with exactly this content:

```sh
#!/usr/bin/env sh
# test_phase_playbooks.sh — SP3a: each core-phase playbook exists, is referenced by its
# SKILL.md, and carries the five sections; the delegation reference exists. Static checks
# only (no RE tool needed).
set -eu
fail() { echo "FAIL: $1" >&2; exit 1; }

DELEG=skills/reverse-engineering/references/delegating-to-subagents.md
[ -f "$DELEG" ] || fail "missing $DELEG"

for phase in triage static dynamic; do
  pb="skills/re-$phase/references/$phase-playbook.md"
  skill="skills/re-$phase/SKILL.md"
  [ -f "$pb" ] || fail "missing $pb"
  grep -q "$phase-playbook.md" "$skill" || fail "$skill does not reference $phase-playbook.md"
  for h in "## Method" "## Failure modes" "## Red flags" "## Have I understood enough" "## Worked example"; do
    grep -q "$h" "$pb" || fail "$pb missing section: $h"
  done
done

if grep -riE 'claude|anthropic' "$DELEG" skills/re-triage/references/triage-playbook.md \
     skills/re-static/references/static-playbook.md \
     skills/re-dynamic/references/dynamic-playbook.md >/dev/null 2>&1; then
  fail "forbidden mention (claude/anthropic) in an SP3a reference"
fi

echo "PASS: test_phase_playbooks.sh"
```

- [ ] **Step 2: Run it to verify it passes**

Run: `sh tests/scripts/test_phase_playbooks.sh`
Expected: `PASS: test_phase_playbooks.sh` (Tasks 1–4 created the referenced files).

- [ ] **Step 3: Create `tests/scenarios/re-delegation-discipline.md`** with exactly this content:

```markdown
# Scenario: delegate mechanically, pilot the judgment

**Setup:** Mid-`re-static` on a real binary, the Ghidra output is ~6000 lines. The agent
needs the body of one function, `validate_license`, to understand the check.

**Prompt:** "Figure out the license check." (the large decompiled artifact is in `artifacts/`)

**PASS criteria (GREEN, with `delegating-to-subagents.md`):**
- Delegates a **mechanical** read: a subagent gets the artifact path + "extract the body of
  `validate_license` and the constants it uses, with line numbers", and returns the content
  + an evidence pointer — it writes no findings and makes no routing decision.
- The piloting agent **keeps the judgment**: it interprets the returned function, decides
  what the check does, and records the finding with a confidence tag itself.
- Does NOT hand the subagent an open-ended "solve / deobfuscate / figure it out" task.

**Typical RED (baseline, no reference):** either reads all ~6000 lines into its own context
(pollution), or dispatches a subagent to "figure out the license check and report the
answer" — open-ended judgment that can churn invisibly.
```

- [ ] **Step 4: Verify portability + full suite, then commit**

```sh
grep -niE 'claude|anthropic' tests/scenarios/re-delegation-discipline.md && echo FAIL || echo OK
for t in tests/scripts/test_*.sh; do sh "$t" >/dev/null 2>&1 && echo "PASS: $(basename $t)" || echo "FAILED: $t"; done
python3 -m pytest tests/scripts/ -q 2>&1 | tail -1
git add tests/scripts/test_phase_playbooks.sh tests/scenarios/re-delegation-discipline.md
git commit -m "tests: SP3a playbook drift check + delegation-discipline scenario"
```
Expected: `OK`; every sh line `PASS:` (incl. `test_phase_playbooks.sh`); pytest `… passed`.

---

## Self-Review

**Spec coverage** (against `2026-06-23-re-phase-depth-delegation-sp3a-design.md`):
- §3.1 five-part playbook structure → Tasks 2/3/4 (each playbook) ✓
- §3.2 delegation reference + template → Task 1 ✓
- §3.3 per-phase content (triage/static/dynamic) → Tasks 2/3/4 ✓
- §3.4 lean SKILL.md pointers → Tasks 2/3/4 Step 2 ✓
- §5 deterministic drift test → Task 5 Step 1; delegation scenario → Task 5 Step 3 ✓
- §7 acceptance 1–5 → all mapped above ✓

**Placeholder scan:** the `<target>`/`<inv>`/`<file>`/`<value>`/`NN` tokens are intentional
fill-ins inside reference prose, not plan placeholders. Every file step shows complete
content and exact commands. No TBD/TODO. ✓

**Name consistency:** the playbook filenames (`<phase>-playbook.md`), the five section
headings (matched by the Task 5 grep substrings `## Method` / `## Failure modes` /
`## Red flags` / `## Have I understood enough` / `## Worked example`), and the cite paths
(`../reverse-engineering/...` from a SKILL, `../../reverse-engineering/...` from a playbook)
are identical across Tasks 1–5. The test greps for the exact heading substrings the
playbooks contain. ✓

**Scope guard:** only the three core phases + the delegation reference + tests are touched;
no advanced phase, script, gate, or report change. ✓
