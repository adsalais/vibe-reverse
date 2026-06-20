# Reverse-Engineering Harness — Design Spec

- **Date:** 2026-06-20
- **Status:** Approved design — pre-implementation
- **Next step:** turn into an implementation plan via `superpowers:writing-plans`

---

## 1. Summary & goal

Build a **portable, agent-agnostic family of skills** ("a harness") that lets a
non-expert *pilot* complex reverse-engineering (RE) tasks through a disciplined,
iterative loop:

> **analyze → write a plan → human approval gate → execute the next phase → repeat**

It is modeled on the `superpowers` skill family
(`brainstorming → writing-plans → executing-plans`), specialized for RE. Each
phase ends by writing a numbered, user-reviewed plan into a dated investigation
folder under `docs/reverse/`, and the investigation closes with a synthesized
`REPORT.md`.

**v1 scope:** the reusable *spine* plus a complete **native / CTF binary**
vertical (Ghidra, radare2/rizin, angr/z3, gdb). The other three target verticals
(firmware, managed/mobile, wasm) are **designed here as a roadmap** and built
later as self-contained "packs" that plug into the same spine.

The guiding philosophy: RE is inherently uncertain — you rarely know step 3 until
step 2 is done — so the harness makes the *plan → approve → go deeper → re-plan*
loop explicit, and bakes in enough RE domain knowledge that a non-expert is asked
expert-shaped questions at each step.

---

## 2. Context & constraints (decisions on record)

These were settled during brainstorming and drive every design choice below.

| Decision | Choice | Implication |
|---|---|---|
| **Targets** | All four (native/CTF, firmware/embedded, managed/mobile, obfuscated scripts/wasm) | Build native first; the rest are documented packs. |
| **Build order** | Design the whole harness; implement spine + native vertical first | v1 stays small and shippable; full vision on record. |
| **Platform** | Portable / agent-agnostic | Tools invoked via plain POSIX shell + `python3`; agent-specific tool names kept out of skill prose (see `references/agent-tools.md`). **Verified:** opencode auto-reads the same `.claude/skills/` tree as Claude Code, so one install serves both (§11a). |
| **Tool setup** | "Detect + instruct only" | A preflight skill detects tools, reports gaps, and **writes** `install.sh` + a `Dockerfile.snippet`. It **never installs anything itself**. |
| **Audience** | New to skill-writing and to RE | Skills emit plain-language explanations; on-the-fly code is tested + documented so it *teaches*. |

---

## 3. Architecture — the harness is one loop

```
        ┌─────────────────────────────────────────────────────┐
        │  reverse-engineering  (entry / orchestrator)         │
        │  routes to the current phase, owns the investigation │
        └───────────────┬─────────────────────────────────────┘
                        │
                        ▼
   ┌────────►  [ PHASE SKILL does its analysis ]  ──── uses ───►  helper scripts
   │             (triage → static → solve/…)                       (dump big output
   │                        │                                       to files)
   │                        ▼
   │          [ writes NN-<phase>-plan.md to docs/reverse/<inv>/ ]
   │                        │
   │                        ▼
   │          [ SELF-REVIEW: consistency · relevancy · evidence · scope ]
   │             (fix inline; escalate to an independent reviewer if complex)
   │                        │
   │                        ▼
   │             🛑 STOP — user reviews & approves the plan
   │                        │  (approve / edit / redirect)
   │                        ▼
   └──────────  orchestrator routes to the next phase
```

**Terminal phase:** when the user calls it done — solved *or* a dead end —
`re-report` synthesizes the whole investigation into `REPORT.md`, written **even on
complete failure** (dead ends seed the next attempt).

This maps directly onto the superpowers loop the user already has
(`brainstorming → writing-plans → executing-plans`): the same spine — **do work →
write a plan → human gate → next** — repeated each phase and specialized for RE.

Two architectural principles:

1. **One skill, one job, one written + approved artifact** before moving on.
2. **Heavy/noisy work runs in subagents and writes to files.** Decompiling a
   large binary spews thousands of lines; the phase reads the file and writes only
   a *summary* into the plan. This is what keeps the main chat clean and lets the
   harness scale to real binaries.

---

## 4. The skill family

### 4a. Spine — cross-cutting, built once, used everywhere

| Skill | One job |
|---|---|
| `reverse-engineering` | Entry point. Explains the loop, creates the investigation folder, routes to the right phase. Stays **tiny** (it loads into context). |
| `re-preflight` | Detect installed tools; report gaps; emit `install.sh` + `Dockerfile.snippet`. Never installs anything itself. |
| `re-planning` | Defines the plan artifact + the **STOP-and-wait-for-approval** gate. Every phase uses it to hand off. |
| `re-scripting` | On-the-fly Python with **TDD + inline docs**, saved to `scripts/`. Reuses `superpowers:test-driven-development`. |

### 4b. Phase skills — the native / CTF vertical (v1)

| Skill | Phase | One job |
|---|---|---|
| `re-triage` | 1 | ID the artifact (type, arch, packing, protections, strings, entropy); detect **which target family** it is; record target + **authorization/scope**; ask the user targeted questions; propose the next plan. |
| `re-static` | 2 | Static analysis: drive Ghidra-headless / r2 to decompile, capture to files, summarize, judge *obfuscated? nested? solver needed?* |
| `re-deobfuscate` | 3 (cond.) | Packers, nested layers, string / control-flow deobfuscation — often via `re-scripting`. |
| `re-solve` | 3 (cond.) | Symbolic execution / SMT (angr, z3) for keygen / path / constraint problems. |
| `re-dynamic` | 3 (cond.) | Run the target under gdb/ltrace/strace **in a sandbox only**; debugging, tracing, hooking. |
| `re-report` | end | Synthesize the whole investigation into `REPORT.md`: outcome, every approach tried, what worked, what failed (with *why*), dead ends + ideas, reproduction steps. **Written even on complete failure.** Runnable at any checkpoint for an interim writeup. |

The three phase-3 skills are intentionally **separate** (different disciplines,
different tools); triage/static route to whichever applies.

### 4c. Reference material

Lives as files *inside* the relevant skill, loaded only on demand (per the
`writing-skills` "heavy reference → separate file" rule):

- a **tool cheat-sheet** (which tool for which job),
- a **binary protections & obfuscation** reference,
- **Ghidra-headless usage** notes,
- `references/agent-tools.md` — Claude Code vs opencode tool-name map (portability).

### 4d. The final report (`re-report`)

The terminal phase. It reads the whole investigation folder (every
`NN-*-plan.md`, `findings.md`, `artifacts/`, `scripts/`) and synthesizes a single
polished `REPORT.md`. **It is mandatory even when the investigation failed** — a
complete failure is still a result, and the recorded dead ends + hypotheses are
exactly what seed the next attempt.

`re-report` is a light **discipline** skill: the rationalization *"we didn't solve
it, so there's nothing to write up"* is explicitly forbidden. It can also be run at
any checkpoint to produce an interim writeup.

`REPORT.md` structure:

- **Target & scope** — what it was, hashes, authorization.
- **Goal & outcome** — solved / partial / failed, in one line.
- **Approaches tried** — for each phase: what was attempted, **what worked, what
  failed, and why** (hypotheses where unproven).
- **Key findings** — the technical understanding gained, in plain language.
- **Dead ends & ideas for next time** — emphasized on failure.
- **Reproduction** — exact steps / scripts to reproduce the result (if solved).
- **Index** — pointers into `artifacts/` and `scripts/`.

A `report-template.md` ships in the skill so the structure is consistent.

---

## 5. Investigation layout & data flow

One investigation = one dated folder (satisfies the
`docs/reverse/<unique-name-with-date>` requirement):

```
docs/reverse/2026-06-20-crackme01/      ← <YYYY-MM-DD>-<slug>, unique per target
├── 00-target.md          # what we're reversing + AUTHORIZATION/scope + sha256/size/source + goal
│                         # + (if dynamic used) the sandbox that was authorized
├── 01-triage-plan.md     # ← gate artifact from re-triage
├── 02-static-plan.md     # ← gate artifact from re-static
├── 03-solve-plan.md      # ← etc.
├── findings.md           # running knowledge base — appended every phase (cumulative "what we know")
├── REPORT.md             # ← final synthesis from re-report (written even on complete failure)
├── install.sh            # from re-preflight
├── Dockerfile.snippet    # from re-preflight
├── artifacts/            # ALL heavy/verbose output lives here, never in chat
│   ├── ghidra/decompiled.c
│   ├── strings.txt
│   └── checksec.txt
└── scripts/              # on-the-fly python (code + tests + README)
    ├── solve_keygen.py
    ├── test_solve_keygen.py
    └── README.md
```

**The data-flow rule:** verbose tool output goes to `artifacts/`; the phase
(or a subagent) reads the file and writes only a **summary** into the plan +
`findings.md`. Numbered plans are point-in-time handoffs; `findings.md` is the
deduplicated cumulative record; `REPORT.md` is the terminal synthesis.

---

## 6. The plan = the gate artifact

Every phase ends by writing a numbered `NN-<phase>-plan.md` with this shape
(defined by `re-planning`):

```markdown
# 02 — Static analysis plan — crackme01

## What I did this phase
- Decompiled with Ghidra headless → artifacts/ghidra/decompiled.c (summary below)

## What I found
- License check at main+0x1ac compares against a value derived from the username
- Plain-language note: it builds a "key" by hashing your name, then compares

## Assessment
- Not packed. One obfuscated function (opaque predicates). A solver (z3) would
  crack the check directly.

## Open questions / uncertainties
- The hash looks like a CRC variant — not yet confirmed.

## Proposed next steps
1. re-solve: model the check in z3 to recover a valid key — expected: a working key
2. (branch) if z3 is slow, re-dynamic: breakpoint the compare and read the value

## Decision needed from you
- [ ] Approve as-is   [ ] Approve with changes   [ ] Redirect
```

### Plan self-review (before the gate)

After writing a plan — and **before** presenting it — Claude runs a self-review and
fixes issues inline, so the human gate (your scarcest resource) never receives a
sloppy or self-contradicting plan. Checklist:

- **Consistency** — internally (does *Assessment* contradict *Proposed next
  steps*?) and across documents (matches the goal in `00-target.md`; doesn't
  contradict `findings.md`).
- **Relevancy** — is each next step justified by a finding and does it advance the
  goal? Is the *recommended* step genuinely the highest-value one? No busywork.
- **Evidence / honesty** — does each claim cite an `artifacts/` file, or is it
  explicitly flagged as an unconfirmed hypothesis? No overclaiming.
- **Scope** — does it propose the *next* step, not a five-step leap?

**Inline always; escalate when it matters.** The inline checklist runs every time.
For *complex or high-uncertainty* plans, Claude escalates to an **independent
reviewer subagent** (prompt shipped as `reviewer-prompt.md`) that reads the plan +
`00-target.md` + `findings.md` and is tasked to find contradictions,
unjustified / irrelevant steps, overclaims, and scope creep; its issues are
resolved before the gate. Escalation triggers:

- the next step is high-cost or irreversible (e.g., running the target in
  `re-dynamic`, a long symbolic-execution run);
- low confidence / many open questions remain;
- the investigation has branched or backtracked (higher contradiction risk);
- the plan proposes multiple competing paths at once.

`re-report` applies the same self-review to `REPORT.md` and — as the terminal
deliverable — escalates to an independent reviewer **by default**.

### The STOP discipline

`re-planning` is a **discipline skill** (written to resist Claude charging
ahead). After writing the plan, Claude presents a ~3-line summary + the file path
and **waits**. Forbidden rationalizations (explicit red-flags table,
superpowers-style):

- *"the next step is obviously fine, I'll just do it"*
- *"I'll save a round-trip by continuing"*
- *"the plan is trivial"*

The user pilots; that is the entire point. *Violating the letter of the gate is
violating the spirit of the gate.*

### How the user approves

Plain chat: *"approved"*, *"do 1, skip 2"*, *"focus on the dynamic route instead."*
The user may also edit the plan file directly and say *"go."* No special tooling —
keeps it portable.

---

## 7. Preflight artifacts (`re-preflight` → `preflight.sh`)

`preflight.sh` probes each known tool (`command -v` / version), prints a
**tool / found? / version / purpose** table, then for anything missing generates
two files. The skill **never installs** — it only detects and writes.

**`install.sh`** — OS-aware, copy-paste, each line commented:

```bash
# radare2 — disassembly & analysis
sudo apt-get install -y radare2        # Debian/Ubuntu
# angr — symbolic execution (Python)
python3 -m pip install angr            # any OS
```

**`Dockerfile.snippet`** — paste into a Dockerfile:

```dockerfile
RUN apt-get update && apt-get install -y file binwalk radare2 gdb ltrace
RUN pip install angr z3-solver
# Ghidra needs a JDK + manual download (big); see the comment block in the snippet
```

**Ghidra wrinkle:** Ghidra is not a simple `apt` package — it needs a JDK plus a
download+unzip. Both generated files include that recipe in a comment block.

Detection is best-effort and portable (Linux + macOS; Windows via a WSL note).
The tool→purpose mapping lives in the cheat-sheet so it stays maintainable.

---

## 8. On-the-fly scripting (`re-scripting`)

When a phase needs real custom code (a format parser, a deobfuscation routine, an
angr harness), the routine is:

1. **Test first** — `test_<name>.py` with known input/output vectors
   (reuses `superpowers:test-driven-development`).
2. **Implement** `<name>.py` with a module docstring + inline `# why` comments
   written *for a learner* — explain the RE reasoning, not just the syntax.
3. Run to green → save both to `scripts/`, append a line to `scripts/README.md`,
   and cite the script in the current plan's "What I did."

A `script_template.py` (argparse CLI + docstring + `if __name__`) ships in the
skill. `re-solve` ships `angr_skel.py` / `z3_skel.py` starters that `re-scripting`
wraps with tests.

**Pragmatic testing stance (important for RE):** test the *deterministic logic* —
parsers, transforms, crypto/keygen routines, the decision function — with known
vectors. Code that is inseparable from the binary (angr glue, ptrace hooks) is
verified by *running it and checking the expected artifact*, with that
sample/expected-output captured as the fixture. We do **not** fake unit tests for
things that cannot be unit-tested; we document how they were verified instead.

---

## 9. Safety & error handling

**Static-by-default; never run the target except in a sandbox.** Reversing an
unknown binary can mean handling malware.

- Triage and static phases **never execute** the target — `file`, `strings`,
  `binwalk`, Ghidra, r2 only *read* bytes. Safe by construction.
- **`re-dynamic` is the only phase that runs the target**, and it is
  discipline-gated: explicit user consent **and** an isolated sandbox (container
  with `--network none`, throwaway VM, or restricted user) — **never on the
  host**. The sandbox used is recorded in `00-target.md`.
- **`re-triage` records authorization/scope up front** (CTF / owned / authorized
  engagement). The harness *prompts and records* — RE hygiene, not a gatekeeper.

**Graceful degradation:**

- Missing tools → phase scripts fall back (no Ghidra? → r2/rizin → objdump) and
  note the degradation in the plan. Preflight is the front line; scripts
  double-check.
- Huge binaries / slow analysis → run in a subagent or background, write to
  `artifacts/`, summarize per-function on demand. Never dump everything into chat.
- Anti-analysis / packed / corrupt → detected and routed to `re-deobfuscate`,
  not a crash.

**Backtracking is first-class.** RE is non-linear. A plan can legitimately say
*"dead end — here are two alternative approaches,"* and the user redirects. Plans
are numbered and append-only, so branches stay on the record — and `re-report`
captures them as ideas for next time.

**Honesty about uncertainty.** The plan template's "Open questions" field forces
Claude to flag what it has not confirmed (*"looks like AES, key schedule
unverified"*) instead of overclaiming — overconfident RE conclusions waste hours.

**Secrets hygiene.** Decompiled output / strings may hold keys / PII; artifacts
stay local and are never pasted to external services.

---

## 10. Testing the skills themselves

Skills are built the way `superpowers:writing-skills` mandates —
**RED → GREEN → REFACTOR with subagent pressure tests** (no skill without a
failing test first):

- **Discipline skills** (`re-planning` gate **+ plan self-review**, `re-dynamic`
  sandbox rule, `re-scripting` TDD, `re-report` "always write it"): pressure-test a
  subagent (*"in a hurry — skip the self-review and just show the plan"* / *"just
  run the binary"* / *"we failed, skip the report"*) and verify it still
  self-reviews / stops / sandboxes / tests-first / writes the report. Capture
  rationalizations → close loopholes.
- **Technique / reference skills** (`re-triage`, `re-static`, `re-solve`,
  `re-preflight`): give a subagent a **tiny sample binary** + the skill and verify
  it triages / decompiles / solves correctly.
- **Test fixtures** (authored in-house — safe, not real malware): a trivial
  crackme, a UPX-packed hello-world, and a simple z3-solvable check, under
  `tests/fixtures/` (source + build script).

The implementation plan will sequence each skill as **baseline-fail → write →
verify**.

---

## 11. Packaging & portability

A single repo (this one) with a flat `skills/` dir — the portable form that works
as Claude Code personal skills, as a plugin later, or in opencode:

```
reverse_skills/
├── README.md
├── INSTALL.md                    # install steps for Claude Code AND opencode (§11a)
├── skills/
│   ├── reverse-engineering/SKILL.md          # tiny orchestrator
│   ├── re-preflight/{SKILL.md, preflight.sh}
│   ├── re-planning/{SKILL.md, reviewer-prompt.md}
│   ├── re-scripting/{SKILL.md, script_template.py}
│   ├── re-triage/{SKILL.md, triage.sh}
│   ├── re-static/{SKILL.md, ghidra_decompile.sh, references/ghidra-headless.md}
│   ├── re-deobfuscate/SKILL.md
│   ├── re-solve/{SKILL.md, templates/angr_skel.py, templates/z3_skel.py}
│   ├── re-dynamic/SKILL.md
│   └── re-report/{SKILL.md, report-template.md}
├── references/agent-tools.md     # CC vs opencode tool-name map (portability)
├── tests/fixtures/               # tiny safe sample binaries + sources
└── docs/reverse/                 # runtime investigations (gitignored except one example)
```

**Portability tactics** (verified against the Claude Code + opencode loaders):

- Tools invoked via plain POSIX shell + `python3`; scripts std-lib-first,
  non-interactive, `--help`-documented.
- Reference helper files with **relative paths** (`scripts/x.py`) — never
  `${CLAUDE_SKILL_DIR}` (Claude-Code-only; inert in opencode).
- **`description` is the portable discovery contract** — both agents auto-load
  skills by it. Keep it third-person and trigger-keyword-rich.
- Author to the **strictest validator**: `name` = lowercase-alphanumeric-hyphen,
  ≤64 chars, equal to the directory name, no `anthropic`/`claude`/XML tags;
  `description` ≤1024 chars.
- Don't rely on `allowed-tools` to auto-grant bash (Claude-Code-only); assume the
  agent must already permit bash.
- Keep each `SKILL.md` < 500 lines; push detail into `references/` (opencode
  surfaces ≤10 files per skill).

Real investigations under `docs/reverse/` are **gitignored** (they may hold
sensitive target data); we ship **one example investigation** as living
documentation.

### 11a. Installation (`INSTALL.md`, for Claude Code **and** opencode)

**Verified (research, 2026-06):** opencode (≥ v1.0.190, Dec 2025) auto-discovers
Claude-style `SKILL.md` skills and reads the **same `.claude/skills/` /
`~/.claude/skills/` trees as Claude Code** (plus a tool-neutral `.agents/skills/`
tree). So *one* installed tree serves both agents — no per-agent copies, no
manifest, no config entry; discovery is by the `description` field in both.

`INSTALL.md` (a v1 deliverable) gives copy-paste steps:

- **Global, serves both agents** — symlink (dev) or copy each skill dir into
  `~/.claude/skills/`:
  ```bash
  # from the cloned repo root
  for d in skills/*/; do ln -s "$PWD/$d" "$HOME/.claude/skills/$(basename "$d")"; done
  # or, to copy instead of symlink:  cp -r skills/* ~/.claude/skills/
  ```
- **Per-project** — commit the skills under the repo's `.claude/skills/` (both
  agents read it) or `.agents/skills/` (tool-neutral).
- **opencode-native (optional)** — `~/.config/opencode/skills/<name>/` (global) or
  `.opencode/skills/<name>/` (project); or point opencode at any folder via
  `opencode.json` → `"skills": { "paths": [...] }`, with access gated by
  `"permission": { "skill": {...} }`.

**Invocation difference (does not affect us):** Claude Code skills are auto-loaded
*and* user-invocable as `/skill-name`; opencode skills are **model-invoked only**
(opencode's `/slash` is a separate "commands" feature). The harness relies on
description-driven auto-loading, which both support identically.

A `plugin.json` for one-step Claude Code marketplace install is deferred (§13).
Because every `SKILL.md` is plain markdown + POSIX/`python3` scripts with relative
paths, the identical files work in both agents.

---

## 12. Roadmap — the other three verticals

The architecture accounts for all four target families from day one because
**`re-triage` detects every format family**. If a target is not native, triage
says *"this is a firmware / managed / wasm target — that pack is not built yet;
here is the roadmap"* instead of failing.

Each future pack is self-contained and reuses the spine (orchestrator + planning
gate + scripting + preflight + report, extended with that pack's tools):

| Pack | Tools | Triggered when triage detects |
|---|---|---|
| `re-firmware` | binwalk / unblob, fs carving, cross-arch decompilation | flash images, bootloaders, raw dumps |
| `re-managed` | jadx, apktool, ILSpy / cfr | APK, DEX, .NET PE, Java class/jar |
| `re-wasm` | wabt (`wasm2wat`), JS deobfuscation, source-maps | `.wasm`, packed / obfuscated scripts |

---

## 13. Scope — v1 build list vs deferred

**Build in v1:**

- **Skills (10):** `reverse-engineering`, `re-preflight`, `re-planning`,
  `re-scripting`, `re-triage`, `re-static`, `re-deobfuscate`, `re-solve`,
  `re-dynamic`, `re-report`.
- **Scripts:** `preflight.sh`, `triage.sh`, `ghidra_decompile.sh`,
  `script_template.py`, `angr_skel.py`, `z3_skel.py`.
- **References:** `ghidra-headless.md`, tool cheat-sheet,
  protections/obfuscation reference, `agent-tools.md`, `report-template.md`,
  `reviewer-prompt.md` (independent plan reviewer).
- **Docs:** `README.md`, `INSTALL.md` (Claude Code + opencode).
- **Fixtures:** trivial crackme, UPX-packed hello-world, z3-solvable check
  (+ build script).
- **One example investigation** under `docs/reverse/` (including a sample
  `REPORT.md`).

**Deferred (documented, not built):**

- `re-firmware`, `re-managed`, `re-wasm` packs.
- Plugin / marketplace packaging (`plugin.json`).
- CI for the skill test suite.

---

## 14. Success criteria

- A user can point the harness at a native binary and, through a sequence of
  **approved plans**, get from "unknown file" to a documented understanding or
  solution — with all heavy output in `artifacts/` and the chat kept clean.
- Each skill passes its subagent pressure / application tests.
- On a machine with no tools, `re-preflight` produces a working `install.sh` and
  a valid `Dockerfile.snippet`.
- Under time pressure, `re-dynamic` still refuses to run a target outside a
  sandbox.
- `re-triage` correctly classifies a non-native target and points to the roadmap
  instead of failing.
- A **failed** investigation still produces a useful `REPORT.md` (approaches
  tried, why they failed, ideas for next time) — failure is documented, never
  silently dropped.
- Plans reach the user **internally consistent**: the self-review catches
  *Assessment*↔*next-step* contradictions and unjustified steps before the gate, so
  review cycles are not wasted on avoidable errors.
- `INSTALL.md` lets a new user install the harness in **both** Claude Code and
  opencode from a clean machine.

---

## 15. Open questions (none blocking)

- **(Resolved)** opencode natively reads `.claude/skills/` and `.agents/skills/`
  (since v1.0.190, Dec 2025) — one tree serves both agents (§11a). Remaining
  caveat: opencode's bundled helper-file support is confirmed in source but
  **undocumented**, so pin/test against a known opencode version if helper scripts
  are load-bearing.
- Finalize the exact preflight tool list during implementation.
- Whether to ship a `plugin.json` for marketplace distribution (deferred).
- Choice of managed-code decompilers per platform (deferred to `re-managed`).
