# Architecture & Workflow

How the reverse-engineering harness works, end to end.

- **This doc** = how the pieces fit and how an investigation flows.
- **Design rationale & decisions** = `docs/superpowers/specs/2026-06-20-reverse-engineering-harness-design.md`
- **Install** = `INSTALL.md` · **Overview** = `README.md`

---

## 1. The idea in one paragraph

The harness turns an AI agent into a **disciplined reverse-engineering co-pilot**.
Reverse engineering is uncertain and iterative — you rarely know step 3 until step
2 is done — so instead of letting the agent race ahead, the harness makes it work
in a loop: do one phase of analysis, write a short **plan**, **stop for your
approval**, then continue. The agent does the heavy lifting (running tools,
reading decompiled code, writing scripts); **you stay in control of direction**.
It is modelled on the `superpowers` workflow (`brainstorming → writing-plans →
executing-plans`), specialized for RE.

---

## 2. The core loop

```
        ┌─────────────────────────────────────────────────────┐
        │  reverse-engineering  (entry / orchestrator)         │
        │  records authorization, scaffolds the investigation, │
        │  routes to the current phase                         │
        └───────────────┬─────────────────────────────────────┘
                        │
                        ▼
   ┌────────►  [ PHASE SKILL does its analysis ]  ── uses ──►  helper scripts +
   │             triage → static → deobf/solve/dynamic          tools (Ghidra, r2,
   │                        │                                    angr…) → write
   │                        │                                    big output to files
   │                        ▼
   │          [ re-planning: write NN-<phase>-plan.md ]
   │                        │
   │                        ▼
   │          [ SELF-REVIEW: consistency · relevancy · evidence · scope ]
   │             (fix inline; escalate to an independent reviewer if complex)
   │                        │
   │                        ▼
   │             🛑 STOP — you review & approve the plan
   │                        │   (approve / edit / redirect)
   │                        ▼
   └──────────  orchestrator routes to the next phase

   …when solved or dead-ended →  re-report writes REPORT.md (even on failure)
```

Two rules make this work:

1. **One skill, one job, one approved artifact before moving on.**
2. **Heavy/noisy output goes to files, not the chat.** Decompiling a binary spews
   thousands of lines; the phase writes them to `artifacts/` and puts only a
   *summary* in the plan. This keeps the conversation readable and lets the
   harness handle real, large binaries.

---

## 3. Lifecycle of an investigation (worked example)

You say: **"Reverse-engineer `./challenge`."**

| # | What happens | Skill | Files touched |
|---|---|---|---|
| 1 | Records **authorization/scope**, scaffolds the session in the CWD | `reverse-engineering` + `new_session.sh` | `vibe-reverse-<datetime>/<challenge>/{00-target.md, findings.md, STATE.md, artifacts/, scripts/}` + `index.md` |
| 2 | (later) registers an unpacked payload as a peer binary | `add_binary.sh` | a new `<payload>/` subfolder + an `index.md` link |
| 3 | **Triage:** file type, arch, packing, protections, strings; decide the target family | `re-triage` ⏳ | `01-triage-plan.md` |
| — | self-review → 🛑 **you approve / redirect** | `re-planning` | — |
| 4 | **Static analysis:** decompile (Ghidra headless / r2), assess *obfuscated? nested? solver needed?* | `re-static` ⏳ | `artifacts/ghidra/decompiled.c`, `02-static-plan.md` |
| — | self-review → 🛑 **you approve** | `re-planning` | — |
| 5 | Branch as needed: defeat packing / solve a check / run under a debugger | `re-deobfuscate`·`re-solve`·`re-dynamic` ⏳ | `NN-*-plan.md`, `scripts/*.py` |
| 6 | **Wrap up:** synthesize everything | `re-report` ⏳ | `REPORT.md` |

(✅/⏳ status in §4. Today the spine — steps 1, 2, and the gate — is built; the
phase skills are being added per the build sequence in §11.)

The investigation is **non-linear**: any plan can say *"dead end — here are two
other approaches,"* and you redirect. Numbered plans are append-only, so the trail
(including dead ends) stays on record and feeds the final report.

---

## 4. The skill family

**Spine** — cross-cutting, used in every investigation:

| Skill | Role | Status |
|---|---|---|
| `reverse-engineering` | Entry point: authorization, scaffolding, routing (air-gapped) | ✅ built |
| `re-planning` | The plan artifact + self-review + STOP-for-approval gate + STATE.md checkpoint | ✅ built |
| `re-scripting` | On-the-fly Python with TDD + learner-oriented docs | ✅ built |
| `re-continue` | Resume a paused session from `STATE.md` (read-only; stops at the gate) | ✅ built |

**Phases** — the native/CTF binary vertical:

| Skill | Role | Status |
|---|---|---|
| `re-triage` | Identify the artifact; record scope; route by target family | ✅ built |
| `re-static` | Decompile & statically analyze; capa/FLOSS scan; route | ✅ built |
| `re-deobfuscate` | Stacked-layer **router**: inventory → order → peel → re-triage | ✅ built |
| `re-devirtualize` | VM-based obfuscation (incl. nested/recursive VMs) | ⏳ Plan 4 |
| `re-antianalysis` | Detect & neutralize anti-debug/anti-VM/anti-disasm | ⏳ Plan 4 |
| `re-crypto` | Identify & replicate crypto (decrypt strings/config/C2) | ✅ built |
| `re-config` | Config & IOC extraction → IOC list + YARA rule | ✅ built |
| `re-solve` | Symbolic execution / SMT (angr, z3): keygen, paths, constraints | ✅ built |
| `re-dynamic` | Run/trace/**emulate** — **sandbox only** | ✅ built |
| `re-report` | Synthesize expert `REPORT.md` — **written even on complete failure** | ✅ built |

Each skill is a `SKILL.md` (markdown instructions) plus optional helper scripts
and `references/` files loaded only when needed.

---

## 5. The investigation folder

One session = one `vibe-reverse-<datetime>/` folder created **in the working
directory** (git-ignored — it may hold sensitive target data). A session holds
**one or more binaries** (a dropper plus the payloads it yields), each in its own
subfolder:

```
vibe-reverse-2026-06-20_14-30-05/
├── index.md               # session map: binaries, relationships, case exec-summary
├── <challenge>/
│   ├── 00-target.md       # what it is + AUTHORIZATION/scope + hashes + goal
│   ├── findings.md        # running, cumulative "what we know"
│   ├── STATE.md           # live cursor: phase/status/next-step + background-jobs ledger
│   ├── 01-triage-plan.md  # ← a gate artifact (one per phase, numbered)
│   ├── 02-static-plan.md
│   ├── REPORT.md          # final synthesis (written even on failure)
│   ├── artifacts/         # ALL heavy/verbose tool output (never pasted into chat)
│   └── scripts/           # on-the-fly Python (code + tests + README)
└── <payload>/ …           # a peer binary added mid-investigation (add_binary.sh)
```

**Data-flow rule:** tools write verbose output to `artifacts/`; the phase reads
the file and writes a **summary** into the plan and `findings.md`. Numbered plans
are point-in-time hand-offs; `findings.md` is the cumulative record; `STATE.md` is
the resumable live cursor; `REPORT.md` is the terminal synthesis (one per binary;
the session `index.md` carries a case-level executive summary).

---

## 6. The plan and the gate (the heart of the harness)

Every phase ends by writing `NN-<phase>-plan.md`:

```markdown
# 02 — Static analysis plan — challenge
## What I did this phase      → summary + links into artifacts/
## What I found               → key findings, in plain language
## Assessment                 → packed? obfuscated? solver needed?
## Open questions / uncertainties   → what is NOT yet confirmed
## Proposed next steps        → 1. action — why, which skill/tool, expected output
## Decision needed from you   → [ ] Approve  [ ] Approve w/ changes  [ ] Redirect
```

Before you ever see it, `re-planning` runs a **self-review** and fixes problems
inline:

- **Consistency** — does the *Assessment* contradict the *next steps*? Does it
  clash with `findings.md` or the goal in `00-target.md`?
- **Relevancy** — is each step justified by a finding and does it advance the
  goal? Is the *recommended* step the highest-value one?
- **Evidence / honesty** — does each claim cite an `artifacts/` file, or is it
  flagged as an unconfirmed hypothesis? (No overclaiming.)
- **Scope** — does it propose the *next* step, not a five-step leap?

For **complex or high-uncertainty** plans it **escalates** to an independent
reviewer subagent (prompt: `skills/re-planning/reviewer-prompt.md`) that reads the
plan + `00-target.md` + `findings.md` and hunts for contradictions, unjustified
steps, overclaims, and scope creep — triggered when the next step is
high-cost/irreversible (e.g. running the target), confidence is low, the
investigation branched, or several paths compete.

Then it **STOPS**: presents a ≤3-line summary + the plan path and waits. You
approve in chat (*"approved"*, *"do 1, skip 2"*, *"redirect"*) or edit the plan
file and say *"go."* This gate is the whole point — *violating the letter of the
gate is violating its spirit.*

---

## 7. Tooling (air-gapped — everything is pre-installed)

The harness runs on an **air-gapped network**: every RE tool is baked into the
image and **the agent never installs anything** (no `apt`, no `pip install`, no
`curl`-to-fetch). A "missing" tool is a path/usage problem, not an install problem.
`skills/reverse-engineering/references/tool-cheatsheet.md` maps tool → purpose.

Resilience is **fallback between baked tools** (e.g. Ghidra → radare2 → objdump),
noted in the plan — that is degradation handling, not installation.

Slow tools (Ghidra, angr, emulation, devirtualization, capa, FLOSS) follow
`references/long-running-ops.md`: run **detached**, write to `artifacts/`, carry a
generous soft budget (30–60 min), and on a budget-hit **ask the user** (numbered
options) — never auto-kill.

The baked toolset (see `deploy/Dockerfile` + `requirements/python-tools.txt`):
Ghidra/radare2/objdump/binutils, `upx`, Detect-It-Easy, `capa`, FLOSS, `yara`,
`gdb`/`ltrace`/`strace`, `qemu` (microVM), and the Python stack — `angr`/`z3`,
`capstone`/`keystone`/`unicorn`, `miasm`/Triton, `qiling`, `lief`/`pefile`/
`pyelftools`, `pwntools`, `speakeasy`. Python tools install **globally**; scripts
call `python3` directly. For a dev host, `requirements/setup.sh` provides them.

---

## 8. On-the-fly scripting

When a phase needs real code (a parser, a deobfuscation routine, a keygen, an
angr/z3 harness), `re-scripting` writes it **test-first** (reusing
`superpowers:test-driven-development`), from `script_template.py`, with a module
docstring + inline `# why` comments aimed at a learner. Code and test land in the
investigation's `scripts/`.

**Pragmatic testing stance:** the deterministic logic (parsers, transforms,
crypto/keygen) is unit-tested with known vectors; code that is inseparable from
the binary (angr glue, ptrace hooks) is verified by running it and checking the
expected artifact, with that sample captured as a fixture and the verification
documented. We do not fake unit tests for what cannot be unit-tested.

---

## 9. Safety model

- **Static by default.** Triage and static analysis only *read* bytes (`file`,
  `strings`, `binwalk`, Ghidra, r2) — they never execute the target.
- **Dynamic only in a sandbox.** `re-dynamic` is the only phase that runs the
  target, and only with your consent **and** isolation (container with
  `--network none`, a throwaway VM, or a restricted user) — never on the host. The
  sandbox is recorded in `00-target.md`.
- **Authorization up front.** Triage records that you're authorized to analyze the
  target (CTF / owned / authorized engagement).
- **Honesty about uncertainty.** The plan's *Open questions* field forces the
  agent to flag what it hasn't confirmed instead of overclaiming.
- **Secrets hygiene.** Decompiled output may hold keys/PII; artifacts stay local
  and are never sent to external services.

---

## 10. Reporting

`re-report` reads the whole investigation folder and writes a polished
`REPORT.md`: target & scope, outcome (solved / partial / failed), **every
approach tried with what worked, what failed, and why**, dead ends + ideas for
next time, reproduction steps, and an index into `artifacts/`/`scripts/`. It is
written **even when the investigation failed** — a documented dead end is what
seeds the next attempt.

---

## 11. How the harness itself is built & tested

The repo is a portable `skills/` tree:

```
reverse_skills/
├── README.md · INSTALL.md · ARCHITECTURE.md
├── references/agent-tools.md          # CC↔opencode map + portability rules
├── skills/<name>/SKILL.md (+ scripts, references/)
├── tests/
│   ├── scripts/      # deterministic tests (POSIX sh + pytest)
│   └── scenarios/    # RED→GREEN subagent scenarios, one per skill
└── docs/
    ├── superpowers/specs/   # the design spec
    └── superpowers/plans/   # the implementation plans
```

Two kinds of test:

- **Deterministic script tests** — `new_session.sh`/`add_binary.sh`,
  `session_status.sh`, the per-phase helper scripts, and `script_template.py` have
  real tests (`tests/scripts/`) run on every change.
- **Skill scenario tests** — each `SKILL.md` is built with the `writing-skills`
  RED→GREEN method: a fresh subagent attempts a scenario *without* the skill
  (baseline failure), then *with* it (must comply). Scenarios live in
  `tests/scenarios/`.

**Build sequence (v1):** the harness is built incrementally so each step is
usable on its own.

1. **Plan 1 — spine & packaging** ✅ (orchestrator, planning+gate, scripting)
2. **Plan 2 — triage + static** ✅ (re-triage, re-static)
3. **Plan 3 — deobfuscate + solve + dynamic** ✅ (re-deobfuscate, re-solve, re-dynamic)
4. **Plan 4 — reporting + example investigation** ✅ (re-report) — **v1 complete**

**v2 (air-gap + advanced capabilities)** — see
`docs/superpowers/specs/2026-06-20-harness-v2-airgap-advanced-re-design.md` and the
four `…-harness-v2-plan*.md` plans: spine refactor (air-gap, remove preflight, new
session layout, checkpoint/resume) → tooling/Docker → deob-router + crypto + config
→ devirtualization + anti-analysis. Family **10 → 14** skills.

---

## 12. Portability (Claude Code + opencode)

Every skill is plain markdown + POSIX-sh / Python-3 scripts, so the **same install
serves both agents** — opencode reads the same `~/.claude/skills/` tree as Claude
Code (see `INSTALL.md`). Portability rules the skills follow (see
`references/agent-tools.md`):

- helper files referenced by **relative path** (never `${CLAUDE_SKILL_DIR}`);
- the `description` field is the discovery contract (both agents auto-load by it);
- `name` = lowercase-hyphen, equal to the directory name;
- scripts are std-lib-first, non-interactive, `--help`-able.

---

## 13. Roadmap — the other target families

`re-triage` is designed to recognize *every* format family from day one. When a
target isn't native, it says *"this is a firmware / managed / wasm target — that
pack isn't built yet"* instead of failing. Each future pack is self-contained and
reuses the same spine (orchestrator + planning gate + scripting +
report):

| Pack | Tools | Triggered when triage detects |
|---|---|---|
| `re-firmware` | binwalk / unblob, fs carving, cross-arch | flash images, bootloaders, raw dumps |
| `re-managed` | jadx, apktool, ILSpy / cfr | APK, DEX, .NET PE, Java class/jar |
| `re-wasm` | wabt (`wasm2wat`), JS deobfuscation | `.wasm`, packed / obfuscated scripts |
