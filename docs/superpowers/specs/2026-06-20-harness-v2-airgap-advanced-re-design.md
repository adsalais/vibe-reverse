# Harness v2 — Air-Gapped Hardening + Advanced RE Capabilities — Design Spec

- **Date:** 2026-06-20
- **Status:** Approved design — pre-implementation
- **Supersedes:** parts of `2026-06-20-reverse-engineering-harness-design.md` (the v1
  spec) — specifically its preflight/tooling model (§7), investigation layout (§5),
  and the native-vertical skill list (§4). The v1 loop, gate, and portability
  principles are retained.
- **Next step:** turn into implementation plans via `superpowers:writing-plans`.

---

## 1. Summary & goal

The v1 harness (a portable, agent-agnostic RE skill family driven by a
`analyze → plan → human-approval gate → execute → report` loop) is built and works.
v2 hardens it for **air-gapped blue-team malware analysis** and broadens it to
**advanced, heavily-obfuscated targets**:

1. **Air-gapped framing** — the agent is told, up front and per-phase, that it runs
   on an isolated network where every tool is pre-installed and **nothing can be
   installed at runtime**. The `re-preflight` skill is removed.
2. **A richer investigation layout** — sessions live in the working directory as
   `vibe-reverse-<datetime>/`, hold **multiple binaries** (dropper → payload
   chains), and carry a session index.
3. **Advanced capabilities** — a deobfuscation *router* that peels **stacked**
   techniques, plus new skills for **devirtualization** (VM-based obfuscation incl.
   nested/recursive VMs), **anti-analysis defeat**, **crypto identification &
   replication**, and **malware config / IOC extraction**.
4. **Long-running-op discipline** — heavy steps run detached with soft time budgets
   and a **never-auto-kill** rule; the human decides when to stop a process.
5. **Checkpointing & resume** — every important step writes a live cursor so an
   investigation can be paused and continued another day via a new `re-continue`
   skill.
6. **Expanded tooling** baked into the air-gapped image (capa, FLOSS, yara, DIE,
   capstone/unicorn/keystone, lief/pefile, miasm, Triton, qiling, speakeasy,
   pwntools, …).

The skill family goes **10 → 14**: remove `re-preflight`; add `re-devirtualize`,
`re-antianalysis`, `re-crypto`, `re-config`, `re-continue`; rework `re-deobfuscate`
into a router; extend `re-static` / `re-dynamic` / `re-planning` / `re-report` /
`re-scripting` / `re-solve` and the `reverse-engineering` orchestrator.

**Whitebox crypto** is explicitly **deferred to its own future spec** (per the
brainstorming decision); `re-diff` / binary diffing and the firmware/managed/wasm
packs remain roadmap.

---

## 2. Scope decisions (on record from brainstorming)

| Decision | Choice |
|---|---|
| **Packaging** | One coherent "harness v2" spec; implementation staged into separate plans. |
| **Air-gap** | Agent instructed it is air-gapped; **no installs ever**; tools assumed present (baked by the Dockerfile). |
| **re-preflight** | **Removed.** Cheat-sheet relocated; skills assume tools exist. |
| **re-report** | `make_report.sh` removed; report written directly from the template; detailed/expert-grade; **summary + most important findings at top**. |
| **Folder layout** | `vibe-reverse-<datetime>/<binary>/{artifacts,scripts,*.md}` in the cwd + a session `index.md`; multiple binaries per session. |
| **Capabilities in** | Deob router; `re-devirtualize`; `re-antianalysis`; `re-crypto`; `re-config`; static/dynamic additions. |
| **Capabilities out** | `re-diff` (binary diffing); whitebox crypto (own spec). |
| **Long-running ops** | Background + soft time budget + checkpoint; **ask the user before killing**, never auto-kill. |
| **Tooling** | All recommended **and** optionals (Triton, speakeasy). frida removed from v2 (deferred). |
| **Resume** | New `re-continue` skill + per-binary `STATE.md` live cursor. |
| **Choice prompts** | Whenever a skill asks the user to decide, present a **numbered list** ending "Which option?". |

---

## 3. Workflow & investigation layout

### 3.1 Air-gapped framing

The `reverse-engineering` orchestrator opens every investigation by establishing
context (and each phase skill assumes it):

> *You are on an air-gapped network. Every RE tool is pre-installed in the image.
> You cannot and must not install anything — no `apt`, no `pip install`, no
> `curl`-to-fetch-a-tool. If a tool appears missing, it is a path or usage problem,
> never an install problem.*

Phase skills drop all "if missing, install via re-preflight / `install.sh` /
`Dockerfile.snippet`" language. **Fallback between baked tools is retained** as
resilience (Ghidra → radare2 → objdump are all present; if one errors, fall back
and note it in the plan) — that is degradation handling, not installation.

### 3.2 New folder layout

`new_investigation.sh` is replaced by a session scaffolder writing into the
**current working directory** (e.g. `/cases/incident-42`):

```
vibe-reverse-2026-06-20_14-30-05/
├── index.md                     # session map: case, binaries, relationships, status,
│                                #   + an executive summary synthesizing the case
├── <binary-1>/
│   ├── 00-target.md
│   ├── findings.md
│   ├── STATE.md                 # live cursor (see §6)
│   ├── 01-triage-plan.md … NN-*-plan.md
│   ├── REPORT.md
│   ├── artifacts/               # subfoldered by tool: ghidra/ floss/ capa/ dynamic/ …
│   └── scripts/
└── <binary-2>/ …                # e.g. a payload unpacked mid-investigation
```

Helper scripts (one tool with subcommands, or two scripts):

- **`new-session <case-slug>`** — creates `vibe-reverse-<datetime>/`, the first
  `<binary>/` subfolder (with `00-target.md`, `findings.md`, `STATE.md`), and
  `index.md`. Datetime is human-readable with seconds: `YYYY-MM-DD_HH-MM-SS`.
- **`add-binary <session-dir> <binary-name>`** — registers a newly-discovered
  binary as a peer subfolder and links it in `index.md` with its parent
  relationship.

The investigation folder is no longer under `docs/reverse/`; the shipped example
investigation is regenerated in the new layout, and `.gitignore` ignores
`vibe-reverse-*/`.

### 3.3 Multi-binary sessions

When deobfuscation or detonation yields a new payload (unpacked EXE, dropped DLL,
decrypted binary blob), the agent calls `add-binary`, **re-triages the payload as a
peer**, and records the **parent → child** relationship in `index.md`. Each binary
runs the full loop and produces its own `REPORT.md`; `index.md` ties the chain into
the dropper → payload story and carries a case-level executive summary.

### 3.4 Long-running-op policy (cross-cutting, defined once)

Defined in `skills/reverse-engineering/references/long-running-ops.md` and cited by
every heavy skill:

- Potentially-slow steps (Ghidra on large binaries, angr/symbolic exec, emulation,
  devirtualization, capa, FLOSS) run **detached**, writing progress/results to
  `artifacts/`, and are recorded in the `STATE.md` **background-jobs ledger**
  (id, command, start time, expected artifact, soft budget, status).
- Each carries a **soft time budget** — generous by default, **minimum 30 min, up
  to 1 hour**, all overridable (defaults: Ghidra 30m, emulation 30m, angr/symbolic
  exec 60m, devirt per-handler 60m). The agent states the expected cost **before**
  launching.
- On budget-hit the agent **does not auto-kill**. It surfaces the situation and
  asks the user, as a numbered list: *1. keep waiting (+N min) · 2. kill and use
  the partial result · 3. kill and try another route · Which option?*
- Plans tag every proposed step with a cost marker: **⚡ fast / ⏳ minutes /
  🐢 long**.

### 3.5 Numbered-list convention (cross-cutting)

Whenever a skill asks the user to choose — `re-planning`'s "Decision needed", a
routing fork, the kill prompt — it presents a **numbered list** ending with
"Which option?". Stated in the orchestrator and enforced by `re-planning`.

### 3.6 Orchestrator routing (decision tree)

`reverse-engineering` stays tiny but its routing grows from a flat table to a
decision tree (native vertical only; firmware/managed/wasm remain roadmap):

- **Start** → `re-triage`.
- **Native, post-triage** → `re-static`.
- **Static signals** route to:
  - packed/obfuscated (entropy, packer sig, opaque predicates, CFF) →
    `re-deobfuscate` (the router, §5.1);
  - VM/dispatcher signs → `re-devirtualize` (usually via the router);
  - anti-analysis present → `re-antianalysis`;
  - crypto constants / config decryption → `re-crypto`;
  - check vs computed value / keygen / reachability → `re-solve`;
  - capabilities/config to harvest → `re-config`;
  - needs runtime → `re-dynamic` (sandbox only).
- **Resume** an existing session → `re-continue` (§6).
- **Wrap up** (solved or dead-ended) → `re-report`.
- Every phase still ends at the `re-planning` gate.

---

## 4. Spine & existing-skill changes

### 4.1 Remove `re-preflight`

Delete `skills/re-preflight/` (SKILL.md, `preflight.sh`, references). Relocate the
tool cheat-sheet to `skills/reverse-engineering/references/tool-cheatsheet.md` and
**expand** it with the new tooling. Scrub every "install via re-preflight" /
`install.sh` / `Dockerfile.snippet` reference from skills, `00-target.md`,
`ARCHITECTURE.md`, `AGENTS.md`, and v1 spec cross-references.

### 4.2 `re-planning`

Remains the gate. Adds:

- **Cost tags** (⚡/⏳/🐢) on every "Proposed next step".
- **Numbered "Decision needed"** options (replacing the checkbox row), ending
  "Which option?".
- A pointer to `long-running-ops.md` for the kill-gate protocol.
- **Checkpoint duty**: at each gate, update the current binary's `STATE.md`
  (§6) — the gate is the natural "important step" boundary.

`reviewer-prompt.md` updated to also check cost-tag presence and state consistency.

### 4.3 `re-report` (detailed, expert-grade, summary-on-top)

Delete `make_report.sh`. SKILL.md instructs writing `REPORT.md` **directly** from
`report-template.md`. New structure, most-important-first, for an expert reader:

1. **Executive summary** — outcome/verdict, the 3–5 most important findings,
   headline IOCs.
2. **Key findings** (expert/technical) · **Approaches tried** (what worked, what
   failed, and why).
3. **Obfuscation & anti-analysis** encountered and how defeated ·
   **Crypto & config** (algorithms, keys, decrypted config).
4. **IOCs + a generated YARA rule** · **Dead ends & ideas** · **Reproduction** ·
   **Index** of `artifacts/`/`scripts/` (the agent lists these itself now).

Each binary gets its own `REPORT.md`; the session `index.md` opens with a
case-level **executive summary** synthesizing all binaries (summary-on-top at both
levels). `report-template.md` is rewritten accordingly. Self-review per
`re-planning`; escalate to the independent reviewer by default (terminal
deliverable).

### 4.4 `re-scripting` + `re-solve` python simplification

Drop the venv / `uv` / `$RE_HARNESS_VENV` dance — the air-gapped image installs
everything **globally**, so scripts call `python3` directly. This also fixes a
latent v1 bug: `${RE_HARNESS_VENV:-$HOME/.local/share/re-harness/venv}/bin/python`
resolves, when `RE_HARNESS_VENV` is unset, to a path that does not exist in the
container. `re-scripting` documents the now-rich library set available to scripts
(capstone, keystone, unicorn, lief, pefile, pyelftools, miasm, yara-python,
r2pipe, pwntools, …). TDD discipline retained.

### 4.5 `re-static` / `re-dynamic` hooks

- **`re-static`** gains an automatic **capa** (capability detection) + **FLOSS**
  (automatic string deobfuscation) + **crypto-constant** + **anti-analysis** pass,
  writing to `artifacts/{capa,floss}/`, then routes to `re-crypto` /
  `re-antianalysis` / `re-devirtualize` / `re-deobfuscate` per findings.
- **`re-dynamic`** gains **emulation** (qiling/unicorn) for unpacking / string /
  config extraction without full detonation, plus **run-to-unpack** + memory dump.
  Emulation runs in-container with **no network**; full native detonation still
  goes only to the no-network microVM (and `speakeasy` for Windows user-mode
  emulation in-container).

---

## 5. Deobfuscation router + new capability skills

### 5.1 `re-deobfuscate` → a deobfuscation router

The core fix for **stacked** obfuscation. The skill runs an explicit loop:

> **inventory → order → peel one layer → re-triage the result → repeat** — until
> entropy is normal, strings/imports are readable, and control flow is sane.

- **Inventory** all techniques present (triage/static signals + capa + DIE +
  entropy + heuristics): packing, string/API obfuscation, stack-strings,
  control-flow flattening (CFF), opaque/bogus predicates, virtualization,
  interleaved anti-analysis.
- **Order** them — peel outermost first (you cannot read flattened code inside a
  packed blob).
- **Peel** one layer with the right handler, then **re-triage / re-static** the
  output (a payload may be a new binary → `add-binary`).
- Maintain a **deobfuscation map** in `artifacts/` (layers found, chosen order,
  per-layer status).

**Gate balance:** to avoid a gate per trivial layer, the router proposes the
*whole peeling plan* once (layers + order + ⚡/⏳/🐢 cost); the user approves; it
peels through the obvious layers and **stops at the gate** when it hits something
new (a fresh binary, a VM, a layer it cannot crack).

**Handlers / routes:**

| Technique | Handling |
|---|---|
| Packing | `unpack.sh` (UPX) + generic run-to-unpack / emulated dump (qiling) + import rebuild (lief) |
| String / API obfuscation | FLOSS, then scripted decoder; API-hash resolution (capa + scripted table) |
| Stack-strings | FLOSS / scripted reconstruction |
| Control-flow flattening | de-flatten via miasm / Triton / angr (recover original CFG), scripted |
| Opaque / bogus predicates | z3-prove the predicate constant, patch out (keystone/lief), reanalyze |
| Virtualization | → **`re-devirtualize`** (§5.2) |
| Interleaved anti-analysis | → **`re-antianalysis`** (§5.3) |
| Crypto-decrypted layers | → **`re-crypto`** (§5.4) |

### 5.2 `re-devirtualize` (new) — VM-based obfuscation

Targets VMProtect, Themida/WinLicense, Tigress, and custom VMs, **including
nested/recursive VMs**. Mostly disciplined methodology + scripting + a reference.

Method:
1. **Identify the VM** — central dispatcher (fetch-decode-execute) loop, virtual
   program counter, handler table, register-context struct.
2. **Locate dispatcher + enumerate handlers**.
3. **Recover the bytecode** (the VM program, often referenced at VM entry).
4. **Derive each handler's semantics** — symbolically execute a single handler
   (Triton/miasm) to auto-extract its native effect where possible.
5. **Lift** bytecode → IR (miasm IR or custom) → simplified, readable pseudocode.
6. **Recurse** when a handler enters a nested VM — apply the same method, lifting
   inner → outer; track depth (this is where the budget + kill-gate earn their
   keep).
7. **Verify** — emulate the lift vs the original on sample inputs (qiling/unicorn).

Ships `references/devirt-methodology.md` (dispatcher patterns, commercial VMs,
recursion handling) and Triton/miasm `templates/`. **Honesty framing is
mandatory**: devirt commonly yields *partial* lifts — report confidence and
partial results, never overclaim. Heavy compute → background + budget + kill-gate.

### 5.3 `re-antianalysis` (new) — detect & neutralize the target's defenses

- **Catalogue + detect** (static and during detonation): anti-debug (ptrace
  self-attach, PEB / `IsDebuggerPresent`, `/proc/self/status` TracerPid, int3
  scanning, rdtsc timing), anti-VM/sandbox (CPUID hypervisor bit, MAC OUI,
  registry/file artifacts, sleep-skip detection, low-resource checks),
  anti-disassembly (junk bytes, overlapping instructions, opaque jumps),
  anti-attach / anti-dump, TLS-callback early execution, self-integrity/checksum.
- **Neutralize**: patch checks out (keystone/lief), make the emulator/debugger
  **lie** (qiling hooks faking CPUID/timing/TracerPid), or breakpoint-and-flip in
  gdb.
- Pairs with `re-dynamic` (apply at detonation) and feeds `re-deobfuscate`
  (anti-disasm is a deobfuscation layer).
- Ships `references/anti-analysis-catalog.md` (technique → detection signature →
  bypass).

### 5.4 `re-crypto` (new) — identify & replicate crypto

Distinct from `re-solve` (SMT/symbolic). 

- **Identify** via crypto-constant scan (yara crypto rules + capa + Ghidra):
  AES S-box/T-tables, SHA/MD5 IVs, RC4 KSA pattern, ChaCha/Salsa sigma, CRC
  tables, standard & custom base64 alphabets, and roll-your-own ciphers.
- **Replicate** — reimplement the routine (tested, via `re-scripting`) to decrypt
  strings / config / C2 traffic or forge values, handling custom key schedules and
  non-standard variants.
- **Verify** — decrypt a known sample and confirm plaintext sanity.
- Ships `references/crypto-id.md` (constant → algorithm table, common malware
  crypto patterns).

### 5.5 `re-config` (new) — malware config & IOC extraction

Blue-team deliverable. 

- **Extract** the config: C2 (URLs/IPs/domains/ports), campaign/botnet IDs,
  mutexes, encryption keys, registry keys, file paths, persistence mechanisms,
  user-agents, kill-switches — sourced from decrypted strings (re-crypto/FLOSS),
  config structs, and qiling emulation dumps.
- **Emit** structured `iocs.md` + `config.json` **and a generated YARA rule** keyed
  on stable signatures (decryption-routine bytes, unique constants, config
  markers); feeds the report's IOC section.
- Ships a YARA-rule template + an IOC schema.

---

## 6. Checkpointing & resume

### 6.1 `STATE.md` — the live cursor (one per binary)

A small, always-current checkpoint in each `<binary>/`:

- current phase + status: `analyzing` / `awaiting-approval` / `blocked-on-background`
  / `paused` / `done`;
- last approved plan (`NN`), what has been executed, and the next step
  (pending-approval, or approved-but-not-yet-run);
- current hypothesis + open questions;
- **background-jobs ledger** — per long-running op: id, command, start time,
  expected artifact, budget, status (running/done/killed).

The session `index.md` keeps the cross-binary map + a "current binary" pointer;
`STATE.md` is the per-binary live position.

### 6.2 When a checkpoint is written

`STATE.md` is updated:

- at **every `re-planning` gate** (each plan is an "important step" boundary —
  owned by `re-planning`);
- **when a background op is launched and when it completes** (owned by the
  long-running-ops convention, §3.4) — so a resume can reattach or collect;
- when the user says **"pause / stop for today."**

### 6.3 `re-continue` (new) — resume a session

Triggers: *"continue / resume / pick up the investigation / what's the status."* It:

1. finds the session — newest `vibe-reverse-*/` in the cwd, or a user-named one;
2. runs `session-status.sh` to scan state across binaries;
3. folds in any background results that finished while away;
4. presents a concise **resume briefing** + the pending decision as a numbered
   list;
5. hands back to the orchestrator loop at the right phase.

It is **read-only** and **stops at the existing gate** — it never auto-runs the
next step.

### 6.4 `session-status.sh` (helper)

Deterministic, read-only, testable (like `triage.sh`): scans the session and prints
a briefing skeleton — binaries + statuses, latest plan per binary, open background
jobs (by checking expected artifacts / PIDs). The agent adds the prose.

---

## 7. Tooling baked into the air-gapped image

Everything must be pre-installed; nothing installs at runtime. The image pins
`angr==9.2.221` on CPython 3.12 and verifies imports at build, so additions must
not break that resolution.

### 7.1 Python libraries (global pip, in `requirements/python-tools.txt`)

`capstone`, `keystone-engine`, `unicorn`, `lief`, `pefile`, `pyelftools`,
`yara-python`, `r2pipe`, `pwntools`, `miasm`, `qiling`,
`speakeasy-emulator`, and **Triton** (the integration risk — pip wheel or
builder-stage build; the plan locks the method). The build's import check is
extended (`python -c 'import angr, z3, capstone, unicorn, keystone, lief, pefile,
miasm, qiling, …'`) so a broken or conflicting install fails the build. The plan
resolves and pins a compatible set.

### 7.2 Standalone baked binaries (avoid pip dep-conflicts)

Follow the existing radare2/upx staging pattern (download in builder, pin + verify
sha256, copy to runtime): **capa** + **FLOSS** (FLARE standalone Linux releases)
and **Detect-It-Easy** (`diec`).

### 7.3 Apt / runtime additions

`yara` (CLI), plus any DIE runtime deps. `speakeasy` runs in-container (Python).

### 7.4 Image & requirements

The image grows notably (qiling/miasm/capa/FLOSS/Triton on top of Ghidra) —
acceptable for an air-gapped appliance. `requirements/Dockerfile` and
`requirements/setup.sh` are updated to match `deploy/Dockerfile`. The tool
cheat-sheet (§4.1) documents each tool's purpose.

---

## 8. Testing

- **Remove** `tests/scripts/test_preflight.sh` and
  `tests/scenarios/re-preflight-missing-tools.md`.
- **Retarget** existing tests: `test_new_investigation.sh` → new session layout +
  `index.md` + `add-binary` + `STATE.md`; `test_report.sh` → template-driven,
  agent-written report carries the required top sections (executive summary first);
  `test_deobfuscate.sh` / `test_dynamic.sh` → new behaviors (tool-optional).
- **New deterministic script tests**: `session-status.sh` (resume briefing from a
  fixture session), the session scaffolder / `add-binary`, the deob-map writer, and
  any capa/FLOSS wrapper scripts.
- **New RED→GREEN scenario tests + tiny safe fixtures** (authored in-house, not
  real malware) for the new skills: a custom-VM crackme (`re-devirtualize`), a
  ptrace anti-debug sample (`re-antianalysis`), an XOR/RC4 string sample
  (`re-crypto`), a config-blob sample (`re-config`), and a half-finished session
  (`re-continue`).
- **Extend `smoke.sh`** to assert every new tool is present (capa, floss, yara,
  diec; importable: capstone, unicorn, keystone, lief, pefile, miasm, qiling,
  triton).
- The **tool-optional** rule for host runs is preserved; in the image the tools are
  guaranteed.

---

## 9. Docs

- `ARCHITECTURE.md` — skill table (−preflight, +4 capability skills, +`re-continue`);
  new investigation layout (§3.2/§5 here); §7 rewritten to "air-gapped, tools
  pre-installed"; new sections for the long-running-ops policy, the deob router, and
  checkpoint/resume.
- `AGENTS.md` — repo map; skill count **10 → 14**; deployment notes for the new
  tools and the standalone-binary pattern; the air-gap / no-install convention.
- `README.md` — overview refreshed.
- `.gitignore` — ignore `vibe-reverse-*/` session folders.
- The shipped **example investigation** stays committed at `docs/reverse/_example/`
  (its name is not `vibe-reverse-*`, so the new gitignore rule does not hide it) but
  is regenerated to demonstrate the new layout — a `vibe-reverse-<datetime>/`
  session with a binary subfolder, `STATE.md`, `index.md`, and an expert-grade
  `REPORT.md`.
- A note in the v1 spec pointing here as the superseding design.

---

## 10. Deferred (explicitly out of v2)

- **Whitebox crypto** — its own future spec (e.g. table/encoding recovery, DCA/DFA
  side-channel-style attacks on whitebox implementations).
- **`re-diff` / binary diffing** (Diaphora) — variant/family attribution.
- **Firmware / managed / wasm packs** — still roadmap (`re-triage` already routes to
  "pack not built yet").
- **frida live instrumentation** (`frida` / `frida-tools` + `frida-server` in the
  detonation guests) — removed from v2; revisit later if live hooking is needed
  beyond emulation (qiling) and tracing (gdb/strace/ltrace).

---

## 11. Implementation staging (for `writing-plans`)

Each plan stays independently shippable; docs are threaded through every plan.

1. **Plan 1 — spine refactor.** Air-gap framing; remove `re-preflight` (+ relocate
   cheat-sheet); new folder layout + session scaffolder + `add-binary`;
   `STATE.md` + `session-status.sh` + `re-continue`; long-running-ops reference;
   numbered-list convention; `re-planning` (cost tags + numbered decision +
   checkpoint duty), `re-report` rewrite, `re-scripting`/`re-solve` python
   simplification. Retarget the affected tests; regenerate the example.
2. **Plan 2 — tooling / Docker.** Add all Python libs + standalone binaries + apt;
   extend the build import check and `smoke.sh`; update `requirements/`.
3. **Plan 3 — deobfuscation router + `re-crypto` + `re-config`** (+ `re-static` /
   `re-dynamic` capa/FLOSS/emulation hooks). Fixtures + scenarios.
4. **Plan 4 — `re-devirtualize` + `re-antianalysis`** (the research-grade pair) +
   their references/templates + fixtures + scenarios.

---

## 12. Success criteria

- The agent never attempts an install; if a tool seems missing it treats it as a
  path/usage issue (air-gap framing verified by a scenario test).
- A session can hold a dropper + an unpacked payload as peer binaries, each with its
  own loop and `REPORT.md`, tied together by `index.md`.
- `re-deobfuscate` peels a **stacked** sample (packing + string-obfuscation + CFF)
  by inventorying, ordering, and re-triaging between layers — not a single-pass
  unpack.
- `re-devirtualize` produces at least a partial, confidence-tagged lift of a custom
  VM fixture, and recurses into a nested VM.
- A long-running step never auto-kills: on budget-hit the agent asks the user with
  numbered options.
- An investigation paused mid-phase is resumed in a fresh session by `re-continue`
  with an accurate briefing (current binary/phase, pending decision, collected
  background results).
- `re-report` produces an expert-grade `REPORT.md` with the executive summary and
  most important findings at the top, plus IOCs and a YARA rule.
- The air-gapped image builds with all new tooling and `smoke.sh` confirms every
  tool present.

---

## 13. Open questions / risks (none blocking)

- **Triton air-gapped install** — the riskiest dependency; Plan 2 must settle pip
  wheel vs builder-stage source build. miasm + angr + unicorn cover most devirt
  needs if Triton proves too costly, but the decision is to include it.
- **Python dependency resolution** — qiling/miasm/pwntools pull large trees; the
  build must verify they do not downgrade angr's pinned stack
  (claripy/pyvex/cle/z3). capa/FLOSS are kept out of the pip env (standalone
  binaries) precisely to avoid the vivisect clash.
- **Devirtualization scope** — full automated devirt of commercial protectors is
  research-grade; the skill targets *assisted, partial, confidence-tagged* lifts,
  not a one-click unprotect.
