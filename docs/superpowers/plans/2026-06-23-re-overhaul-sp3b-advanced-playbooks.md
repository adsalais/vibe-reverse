# SP3b — Advanced Playbooks + Routing Relabel + deob/devirt Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the six advanced phases to playbook depth (SP3a convention), encode the deobfuscate↔devirtualize loop ownership + hand-back, and land the per-phase routing relabel SP4 deferred — completing the overhaul.

**Architecture:** Six new `references/<phase>-playbook.md` (5-section convention, Method cites the existing catalog, references the SP4 loop); the six SKILLs get the two lean pointers + a routing-relabel line; the 3 core SKILLs get the relabel line (retrofit); the drift test extends to all 9 phases; one deob/devirt-loop scenario.

**Tech Stack:** Markdown skills/references; POSIX-sh drift test; RED/GREEN scenario.

**Spec:** `docs/superpowers/specs/2026-06-23-re-phase-depth-delegation-sp3b-design.md`

## Global Constraints

- **No "claude"/"anthropic"** in content files; relative paths only; every SKILL.md < 500 lines.
- **Playbook structure (5 headings, in order):** `## Method`, `## Failure modes / wrong-track signals`, `## Red flags — STOP`, `## Have I understood enough?`, `## Worked example`.
- **Method cites the existing catalog** (don't duplicate it); references the SP4 `re-planning` loop where the phase has an internal loop/ordering.
- **Decision A:** `re-devirtualize` stays standalone; `re-deobfuscate` owns the peel loop and dispatches devirt; devirt **hands back** on a non-VM layer. Do NOT merge them.
- From a playbook, cite the spine reference as `../../reverse-engineering/references/<f>`; from a SKILL, as `../reverse-engineering/references/<f>`.

---

### Task 1: re-deobfuscate playbook + SKILL

**Files:**
- Create: `skills/re-deobfuscate/references/deobfuscate-playbook.md`
- Modify: `skills/re-deobfuscate/SKILL.md`

- [ ] **Step 1: Create `skills/re-deobfuscate/references/deobfuscate-playbook.md`:**

```markdown
# Deobfuscation playbook — peel the stack, outermost first

Advanced samples **stack** obfuscation (packing + strings + CFF + a VM…). This phase is
the stacked-layer worker: inventory the layers, peel outermost-first, re-triage after
each peel. Its loop is the **ranking heuristic** feeding the `re-planning` hypothesis loop
— "the outermost layer is X" is the top hypothesis; peeling it is the test.

## Method

1. **Inventory** every technique present — `deob_map.sh`, capa/FLOSS, DIE (`diec`),
   entropy. Identify each with `obfuscation-taxonomy.md` (sibling reference).
2. **Rank outermost-first** (packing/encryption → control-flow → virtualization). You
   can't read flattened code inside a packed blob.
3. **Peel the top layer** with its handler (taxonomy table), then **re-run `re-triage` +
   `re-static`** — a peel can reveal a new layer or a new binary.
4. **A VM layer → dispatch `re-devirtualize`** as the worker; when it returns the lifted
   logic, **re-triage and continue the loop.** Virtualization is a step in the loop, not
   a hand-off that ends it.
5. Record each layer + handler + result as findings (with evidence). Continue until
   entropy is normal, strings/imports are readable, and control flow is sane.

## Failure modes / wrong-track signals

- **Peeling inner-first** — de-flattening code that's still packed/encrypted.
- **Not re-triaging after a peel** — you miss the layer the peel just exposed.
- **Treating a VM as just-another-peel** — dispatch `re-devirtualize`, don't hand-roll it.
- **A peeled payload is a new binary** but you keep going in-place — mandatory gate
  (`add_binary.sh`, triage it as a peer).

## Red flags — STOP

| Thought | Reality |
|---|---|
| "I'll de-flatten now, the packing can wait" | Outermost first — you can't read code inside a packed blob. |
| "Peeled it, moving on" (no re-triage) | Re-triage after every peel; a new layer/binary may have appeared. |
| "Unpacked to a new binary, I'll keep analysing here" | New binary = mandatory gate → `add_binary.sh`, triage as a peer. |
| "I'll devirtualize this VM myself inline" | Dispatch `re-devirtualize` (the worker); it hands back if it hits a non-VM layer. |

## Have I understood enough?

A layer is peeled when its artifact is gone from the next re-triage (entropy dropped,
strings/imports readable). The phase is done when the binary triages clean — then route
on. Don't over-peel a layer you've already removed.

## Worked example

A dropper: triage shows entropy 7.9 + `UPX!`. Top hypothesis: UPX packing → `unpack.sh`
→ re-triage. Entropy normal now, but every function routes through one dispatcher with
equal-size blocks → control-flow flattening → de-flatten via miasm (`re-scripting`) →
re-triage → clean C. Record each peel as a `[confirmed]` finding (evidence: before/after
artifacts).
```

- [ ] **Step 2: Add the pointer block to `skills/re-deobfuscate/SKILL.md`** — replace:

```markdown
> **inventory → order → peel one layer → re-triage → repeat** — until entropy is
> normal, strings/imports are readable, and control flow is sane.
```

with:

```markdown
> **inventory → order → peel one layer → re-triage → repeat** — until entropy is
> normal, strings/imports are readable, and control flow is sane.

**Method, failure modes, worked example:** `references/deobfuscate-playbook.md`.
Reading a large lifted/handler or capa/FLOSS dump to extract the relevant lines is
**mechanical** — delegate it per `../reverse-engineering/references/delegating-to-subagents.md`.
The handlers/routes you pick are candidate hypotheses for the `re-planning` loop — it ranks and gates.
```

- [ ] **Step 3: Verify + commit**

```sh
grep -q 'deobfuscate-playbook.md' skills/re-deobfuscate/SKILL.md || echo "MISSING ref"
grep -q '## Worked example' skills/re-deobfuscate/references/deobfuscate-playbook.md || echo "MISSING section"
grep -niE 'claude|anthropic' skills/re-deobfuscate/references/deobfuscate-playbook.md && echo FAIL || echo OK
git add skills/re-deobfuscate/references/deobfuscate-playbook.md skills/re-deobfuscate/SKILL.md
git commit -m "re-deobfuscate: add playbook (loop owns devirt) + pointers + relabel"
```
Expected: no `MISSING`; `OK`.

---

### Task 2: re-devirtualize playbook + SKILL

**Files:**
- Create: `skills/re-devirtualize/references/devirtualize-playbook.md`
- Modify: `skills/re-devirtualize/SKILL.md`

- [ ] **Step 1: Create `skills/re-devirtualize/references/devirtualize-playbook.md`:**

```markdown
# Devirtualization playbook — the VM worker, dispatched by the loop

`re-devirtualize` is the **worker** the `re-deobfuscate` loop dispatches when the current
layer is a VM (dispatcher + handler table). It does the deep, often-partial work of
recovering readable logic — it does **not** own a peel loop of its own.

## Method

Follow the seven steps in `devirt-methodology.md` (sibling reference): locate dispatcher →
recover bytecode → derive handler semantics with `../templates/triton_handler.py` → decode
→ lift with `../templates/miasm_lift.py` → recurse for nested VMs → verify. Adapt the templates via
`re-scripting` (test the deterministic decoder). Heavy symbolic/lift steps are **🐢, a
mandatory gate** — run them per `../../reverse-engineering/references/long-running-ops.md`.

## Hand back to the loop

If you find a **non-VM layer** — encrypted bytecode, packing around the VM, interleaved
anti-analysis — **do not improvise a peel loop here.** Return to the owner: packing/
strings/CFF → `re-deobfuscate`; a crypto-gated bytecode blob → `re-crypto`, then resume;
anti-disasm/anti-debug → `re-antianalysis`, then resume. You are the VM worker; the loop
owns ordering.

## Failure modes / wrong-track signals

- **Arrived at a "VM" that's still wrapped** — surrounding layers weren't peeled; hand
  back rather than fighting noise.
- **Presenting a partial lift as complete** — devirt is usually partial; tag confidence
  and list unresolved handlers.
- **Nested-VM depth blows the budget** — each level multiplies cost (🐢); gate it.

## Red flags — STOP

| Thought | Reality |
|---|---|
| "There's packing around the VM, I'll just peel it here" | Hand back to `re-deobfuscate` — it owns the loop. |
| "I lifted most of it, call it done" | Partial is the norm — confidence-tag it; list the gaps. |
| "I'll recurse this nested VM unattended" | Deep recursion is 🐢 — mandatory gate; state the cost and stop. |

## Have I understood enough?

Deliver the **dispatcher map + opcode→semantics table + a confidence-tagged partial
lift** with unresolved handlers listed. That is real progress — you don't need a complete
decompilation to hand back useful logic.

## Worked example

A function behind a custom bytecode VM: locate the dispatcher loop + 16-entry handler
table, symbolically execute three handlers (add/xor/load) with `triton_handler.py`, decode
the bytecode, lift the arithmetic with `miasm_lift.py`. Two handlers stay opaque → record
**[likely]** lift, list the two gaps, verify the lifted arithmetic against the original on
sample inputs.
```

- [ ] **Step 2: Add the pointer block to `skills/re-devirtualize/SKILL.md`** — replace:

```markdown
For targets where triage/static/deob shows a **dispatcher loop + handler table**
(virtualized code). Usually reached via the `re-deobfuscate` router. Mostly
disciplined methodology + scripting.
```

with:

```markdown
For targets where triage/static/deob shows a **dispatcher loop + handler table**
(virtualized code). Usually reached via the `re-deobfuscate` router. Mostly
disciplined methodology + scripting.

**Method, failure modes, hand-back rule, worked example:** `references/devirtualize-playbook.md`.
Reading a large lifted-output/handler dump to extract specific handlers is **mechanical** —
delegate it per `../reverse-engineering/references/delegating-to-subagents.md`.
You are the VM worker the `re-deobfuscate` loop dispatches — hand back on a non-VM layer.
```

- [ ] **Step 3: Verify + commit**

```sh
grep -q 'devirtualize-playbook.md' skills/re-devirtualize/SKILL.md || echo "MISSING ref"
grep -q '## Have I understood enough' skills/re-devirtualize/references/devirtualize-playbook.md || echo "MISSING section"
grep -niE 'claude|anthropic' skills/re-devirtualize/references/devirtualize-playbook.md && echo FAIL || echo OK
git add skills/re-devirtualize/references/devirtualize-playbook.md skills/re-devirtualize/SKILL.md
git commit -m "re-devirtualize: add playbook (worker + hand-back) + pointers"
```
Expected: no `MISSING`; `OK`.

---

### Task 3: re-antianalysis playbook + SKILL

**Files:**
- Create: `skills/re-antianalysis/references/antianalysis-playbook.md`
- Modify: `skills/re-antianalysis/SKILL.md`

- [ ] **Step 1: Create `skills/re-antianalysis/references/antianalysis-playbook.md`:**

```markdown
# Anti-analysis playbook — detect, neutralize, re-verify

This phase finds the target's **own** defenses (anti-debug/anti-VM/anti-disasm/
self-integrity) and neutralizes them so analysis can proceed. It pairs with `re-dynamic`
(apply at detonation/emulation) and feeds `re-deobfuscate` (anti-disasm is a deob layer).

## Method

1. **Detect** — `antianalysis_scan.sh` + cross-check capa; map each hit with
   `anti-analysis-catalog.md` (sibling reference; technique → detection → bypass).
2. **Neutralize** per the catalog — patch the check out (keystone/lief), force the return
   in gdb, or make the emulator lie (qiling hooks faking TracerPid/CPUID/timing).
3. **Re-verify it proceeds** — confirm the target now runs past the check (sandboxed;
   running is a mandatory gate).
4. **Record** each neutralized check (evidence) for the report's "Obfuscation &
   anti-analysis" section.

## Failure modes / wrong-track signals

- **Empty/short dynamic trace = evasion, not inert** — the sample detected the
  sandbox/debugger and bailed; that's why you're here.
- **Stacked checks** — neutralizing one reveals a second; re-scan after each.
- **Self-integrity re-trigger** — patching the body trips a checksum; patch *after* the
  check, or hook the verifier to pass.

## Red flags — STOP

| Thought | Reality |
|---|---|
| "Patched the check, moving on" | Re-verify the target actually proceeds before claiming the bypass works. |
| "I'll run it on the host to test the bypass" | Running is a mandatory gate — sandbox + consent (`re-dynamic`). |
| "Trace was empty, the sample does nothing" | Suspect evasion; that's the check you must neutralize. |

## Have I understood enough?

Done when the target **proceeds past its defenses** under analysis and each neutralized
check is recorded. Then route back to whatever the defense was blocking (deob/dynamic).

## Worked example

A Linux sample exits immediately under strace. `antianalysis_scan.sh` flags
`ptrace(PTRACE_TRACEME)`. Catalog → force the `ptrace` return in gdb (or patch the
branch). Re-run in the sandbox: it now reaches `main` and proceeds. Record **[confirmed]**
"ptrace self-attach anti-debug, neutralized by forcing the return" (evidence: trace
before/after).
```

- [ ] **Step 2: Add the pointer block to `skills/re-antianalysis/SKILL.md`** — replace:

```markdown
Detect & neutralize the target's **own** anti-analysis. Pairs with `re-dynamic`
(apply at detonation/emulation) and feeds `re-deobfuscate` (anti-disasm is a deob
layer).
```

with:

```markdown
Detect & neutralize the target's **own** anti-analysis. Pairs with `re-dynamic`
(apply at detonation/emulation) and feeds `re-deobfuscate` (anti-disasm is a deob
layer).

**Method, failure modes, worked example:** `references/antianalysis-playbook.md`.
Reading the scan/trace output to extract the check sites is **mechanical** — delegate it
per `../reverse-engineering/references/delegating-to-subagents.md`.
The neutralize routes you pick are candidate hypotheses for the `re-planning` loop — it ranks and gates.
```

- [ ] **Step 3: Verify + commit**

```sh
grep -q 'antianalysis-playbook.md' skills/re-antianalysis/SKILL.md || echo "MISSING ref"
grep -q '## Red flags' skills/re-antianalysis/references/antianalysis-playbook.md || echo "MISSING section"
grep -niE 'claude|anthropic' skills/re-antianalysis/references/antianalysis-playbook.md && echo FAIL || echo OK
git add skills/re-antianalysis/references/antianalysis-playbook.md skills/re-antianalysis/SKILL.md
git commit -m "re-antianalysis: add playbook + pointers + relabel"
```
Expected: no `MISSING`; `OK`.

---

### Task 4: re-crypto playbook + SKILL

**Files:**
- Create: `skills/re-crypto/references/crypto-playbook.md`
- Modify: `skills/re-crypto/SKILL.md`

- [ ] **Step 1: Create `skills/re-crypto/references/crypto-playbook.md`:**

```markdown
# Crypto playbook — identify, replicate, verify

Identify the cipher/encoding and **replicate it as tested code** to decrypt
strings/config/C2 — don't reverse it by hand. Distinct from `re-solve` (reach for that
only when you must *search* for an input).

## Method

1. **Identify** — `cryptoscan.sh` + capa crypto tags; map constants → algorithm with
   `crypto-id.md` (sibling reference: AES S-box, SHA/MD5 IVs, RC4 KSA, ChaCha sigma, CRC
   tables, base64 alphabets, roll-your-own).
2. **Replicate** as a **tested pure function** via `re-scripting` (known input/output
   vector); handle custom key schedules / non-standard variants. Recover keys by
   known-plaintext (e.g. an `MZ`/`\x7fELF` header in the expected output) where needed.
3. **Verify** — decrypt a known sample, confirm the plaintext is sane; feed recovered
   strings/keys to `re-config`.

## Failure modes / wrong-track signals

- **Over-assuming AES** — a lone repeating-key XOR is the most common malware "crypto";
  match the constants before naming the algorithm.
- **Missed custom key schedule** — a standard cipher with a tweaked schedule decrypts to
  garbage; replicate the *actual* schedule.
- **Not verifying** — "it's RC4" is `[likely]` until a known vector decrypts cleanly.

## Red flags — STOP

| Thought | Reality |
|---|---|
| "256-byte table, must be AES" | Match the S-box constants (`crypto-id.md`); could be RC4/custom. `[likely]` until verified. |
| "I'll reverse the cipher by hand" | Replicate it as a tested function — hand-derivation is error-prone. |
| "Decryptor runs, ship it" | Verify against a known-plaintext vector first. |

## Have I understood enough?

Done when a **tested decryptor reproduces known plaintext** and keys are recovered with
evidence. Hand the plaintext/keys to `re-config`.

## Worked example

`cryptoscan.sh` finds a 256-byte identity array permuted by `j=(j+S[i]+key[i])` → RC4 KSA
(`crypto-id.md`). Replicate RC4 as a tested function (`re-scripting`), key from a known
config header. Decrypt → a readable C2 URL appears (the sanity check) → **[confirmed]**,
hand to `re-config`.
```

- [ ] **Step 2: Add the pointer block to `skills/re-crypto/SKILL.md`** — replace:

```markdown
Identify & **replicate** crypto/encoding to decrypt strings/config/C2 or forge
values. Distinct from `re-solve` (SMT/symbolic) — reach for `re-solve` only when you
must *search* for an input.
```

with:

```markdown
Identify & **replicate** crypto/encoding to decrypt strings/config/C2 or forge
values. Distinct from `re-solve` (SMT/symbolic) — reach for `re-solve` only when you
must *search* for an input.

**Method, failure modes, worked example:** `references/crypto-playbook.md`.
Reading a large dump to extract a routine's bytes/constants is **mechanical** — delegate
it per `../reverse-engineering/references/delegating-to-subagents.md`.
The algorithm/route you pick is a candidate hypothesis for the `re-planning` loop — it ranks and gates.
```

- [ ] **Step 3: Verify + commit**

```sh
grep -q 'crypto-playbook.md' skills/re-crypto/SKILL.md || echo "MISSING ref"
grep -q '## Method' skills/re-crypto/references/crypto-playbook.md || echo "MISSING section"
grep -niE 'claude|anthropic' skills/re-crypto/references/crypto-playbook.md && echo FAIL || echo OK
git add skills/re-crypto/references/crypto-playbook.md skills/re-crypto/SKILL.md
git commit -m "re-crypto: add playbook + pointers + relabel"
```
Expected: no `MISSING`; `OK`.

---

### Task 5: re-config playbook + SKILL

**Files:**
- Create: `skills/re-config/references/config-playbook.md`
- Modify: `skills/re-config/SKILL.md`

- [ ] **Step 1: Create `skills/re-config/references/config-playbook.md`:**

```markdown
# Config & IOC playbook — the defender deliverable

Turn recovered data into a blue-team deliverable: `config.json` (machine) + `iocs.md`
(human) + a YARA rule, in the binary's folder.

## Method

1. **Gather** — decrypted strings/config from `re-crypto`/FLOSS, config structs from
   `re-static`, runtime/emulation dumps from `re-dynamic`.
2. **Extract** into the `ioc-schema.md` shape (sibling reference): C2, campaign/botnet IDs,
   mutexes, keys, persistence, registry, files, user-agents, kill-switch, hashes. Write
   `config.json` + a defender-friendly `iocs.md`.
3. **Detect** — author a YARA rule from `yara-template.yar` (sibling reference) keyed on **stable**
   signatures (decryptor bytes, unique constants, config markers); sanity-check with
   `yara <rule> <sample>`. Feed IOCs + rule to `re-report`.

## Failure modes / wrong-track signals

- **Brittle YARA** — keying on volatile strings (paths, version tags) that change per
  build. Key on stable bytes (the decryptor stub, a unique constant).
- **Decoy/sinkhole C2** — a hardcoded host may be a decoy or already sinkholed; tag
  confidence rather than asserting it's live.
- **Missing a field** — a config blob often holds more than the C2 (mutex, campaign,
  kill-switch); walk the whole struct.

## Red flags — STOP

| Thought | Reality |
|---|---|
| "YARA on this nice string" | Volatile strings make brittle rules — key on stable bytes. |
| "Found the C2, it's live" | Could be a decoy/sinkhole — tag `[likely]` unless confirmed dynamically. |
| "Got the C2, done" | Walk the whole config — mutex, campaign id, persistence, kill-switch. |

## Have I understood enough?

Done when `config.json` + `iocs.md` are populated from the recovered data and a
sanity-checked YARA rule keyed on stable signatures exists. Hand to `re-report`.

## Worked example

A decrypted blob (from `re-crypto`) yields `host=evil.example:443`, a mutex, and a
campaign id. Populate `config.json` (`ioc-schema.md`), write `iocs.md`, author a YARA rule
on the **decryptor's byte pattern** (stable) rather than the C2 string (volatile). Tag the
C2 `[likely]` pending a dynamic callback.
```

- [ ] **Step 2: Add the pointer block to `skills/re-config/SKILL.md`** — replace:

```markdown
Turn recovered data into a **defender deliverable** — `config.json` + `iocs.md` +
a **YARA rule**, written into the binary's folder.
```

with:

```markdown
Turn recovered data into a **defender deliverable** — `config.json` + `iocs.md` +
a **YARA rule**, written into the binary's folder.

**Method, failure modes, worked example:** `references/config-playbook.md`.
Reading a large strings/FLOSS dump to extract IOC candidates is **mechanical** — delegate
it per `../reverse-engineering/references/delegating-to-subagents.md`.
The sources/fields you pursue are candidate hypotheses for the `re-planning` loop — it ranks and gates.
```

- [ ] **Step 3: Verify + commit**

```sh
grep -q 'config-playbook.md' skills/re-config/SKILL.md || echo "MISSING ref"
grep -q '## Worked example' skills/re-config/references/config-playbook.md || echo "MISSING section"
grep -niE 'claude|anthropic' skills/re-config/references/config-playbook.md && echo FAIL || echo OK
git add skills/re-config/references/config-playbook.md skills/re-config/SKILL.md
git commit -m "re-config: add playbook + pointers + relabel"
```
Expected: no `MISSING`; `OK`.

---

### Task 6: re-solve playbook + SKILL

**Files:**
- Create: `skills/re-solve/references/solve-playbook.md`
- Modify: `skills/re-solve/SKILL.md`

- [ ] **Step 1: Create `skills/re-solve/references/solve-playbook.md`:**

```markdown
# Solve playbook — recover an input, then prove it

Recover an input that satisfies a check, then **verify it against the real binary**. Pick
the lightest route that works; don't reach for heavy symbolic execution when the check is
invertible.

## Method

1. **Get the logic + addresses** from `re-static` (the comparison, the transform, the
   FIND/AVOID targets).
2. **Pick the route:**
   - **Direct inversion** — invertible check (xor/add/simple transform): compute the
     answer (usually `re-scripting`). Cheapest; prefer it.
   - **Constraints (z3)** — arithmetic/bitwise relations: model them (`../templates/z3_skel.py`).
   - **Path-finding (angr)** — "find input reaching the success branch":
     `../templates/angr_skel.py` with FIND/AVOID from `re-static`. Symbolic execution is 🐢
     — a mandatory gate.
3. **Write the solver test-first** (`re-scripting`, known vectors).
4. **Verify** — run the *real* binary with the recovered input and confirm it's accepted
   ("Correct!"). Safe for your own challenge; for an untrusted target verify in a sandbox
   via `re-dynamic` (a mandatory gate).

## Failure modes / wrong-track signals

- **Reaching for angr when inversion suffices** — path explosion on a check you could
  invert in three lines.
- **Wrong FIND/AVOID** — angr "succeeds" into the wrong branch; confirm the addresses.
- **Unverified answer** — z3 says `sat`, but you never ran the binary; `[likely]`, not
  `[confirmed]`, until the binary accepts it.

## Red flags — STOP

| Thought | Reality |
|---|---|
| "I'll throw angr at it" (simple xor) | Invert it directly — angr is for path-finding, and it's 🐢. |
| "z3 returned sat, we're done" | Verify against the real binary before claiming `[confirmed]`. |
| "I'll just run the untrusted target to check" | Running untrusted = mandatory gate → sandbox (`re-dynamic`). |

## Have I understood enough?

Done when the recovered input is **accepted by the real binary** (verified) and the solver
is a tested, documented script. That's a `[confirmed]` solve.

## Worked example

`re-static` shows the check hashes the input and compares to a constant — not invertible.
Model the hash constraints in z3 (`z3_skel.py`), solve for an input, write it test-first.
Run `./target <recovered>` → "Correct!" → **[confirmed]** (evidence: the run + the solver
test).
```

- [ ] **Step 2: Add the pointer block to `skills/re-solve/SKILL.md`** — replace:

```markdown
Recover an input that satisfies a check.
```

with:

```markdown
Recover an input that satisfies a check.

**Method, route choice, failure modes, worked example:** `references/solve-playbook.md`.
Reading angr/solver output to extract the result is **mechanical** — delegate it per
`../reverse-engineering/references/delegating-to-subagents.md`.
The route you pick (invert / z3 / angr) is a candidate hypothesis for the `re-planning` loop — it ranks and gates.
```

- [ ] **Step 3: Verify + commit**

```sh
grep -q 'solve-playbook.md' skills/re-solve/SKILL.md || echo "MISSING ref"
grep -q '## Failure modes' skills/re-solve/references/solve-playbook.md || echo "MISSING section"
grep -niE 'claude|anthropic' skills/re-solve/references/solve-playbook.md && echo FAIL || echo OK
git add skills/re-solve/references/solve-playbook.md skills/re-solve/SKILL.md
git commit -m "re-solve: add playbook + pointers + relabel"
```
Expected: no `MISSING`; `OK`.

---

### Task 7: Core routing-relabel retrofit (triage / static / dynamic)

Add the one-line relabel to the three core phases' existing SP3a pointer blocks.

**Files:**
- Modify: `skills/re-triage/SKILL.md`, `skills/re-static/SKILL.md`, `skills/re-dynamic/SKILL.md`

- [ ] **Step 1: re-triage** — replace:

```markdown
Heavy-artifact reads (rare in triage — its output is small) delegate mechanically — see
`../reverse-engineering/references/delegating-to-subagents.md`.
```

with:

```markdown
Heavy-artifact reads (rare in triage — its output is small) delegate mechanically — see
`../reverse-engineering/references/delegating-to-subagents.md`.
The family routes below are candidate hypotheses for the `re-planning` loop — it ranks and gates.
```

- [ ] **Step 2: re-static** — replace:

```markdown
delegate it per `../reverse-engineering/references/delegating-to-subagents.md` (the
subagent returns the function + evidence pointers; you integrate the findings).
```

with:

```markdown
delegate it per `../reverse-engineering/references/delegating-to-subagents.md` (the
subagent returns the function + evidence pointers; you integrate the findings).
The assess/route options are candidate hypotheses for the `re-planning` loop — it ranks and gates.
```

- [ ] **Step 3: re-dynamic** — replace:

```markdown
`../reverse-engineering/references/delegating-to-subagents.md`; never delegate the decision
to run.
```

with:

```markdown
`../reverse-engineering/references/delegating-to-subagents.md`; never delegate the decision
to run.
The technique/route you pick is a candidate hypothesis for the `re-planning` loop — it ranks and gates.
```

- [ ] **Step 4: Verify + commit**

```sh
for p in triage static dynamic; do grep -q 'candidate hypothes' skills/re-$p/SKILL.md || echo "MISSING relabel: $p"; done
git add skills/re-triage/SKILL.md skills/re-static/SKILL.md skills/re-dynamic/SKILL.md
git commit -m "re: relabel core-phase routing tables as hypothesis sources (SP4 retrofit)"
```
Expected: no `MISSING`.

---

### Task 8: Extend the drift test to 9 phases + the deob/devirt-loop scenario

**Files:**
- Modify: `tests/scripts/test_phase_playbooks.sh`
- Create: `tests/scenarios/re-deob-devirt-loop.md`

- [ ] **Step 1: Extend the phase loop in `tests/scripts/test_phase_playbooks.sh`** — replace:

```sh
for phase in triage static dynamic; do
```

with:

```sh
for phase in triage static dynamic deobfuscate devirtualize antianalysis crypto config solve; do
```

- [ ] **Step 2: Generalize the forbidden-mention check** — replace:

```sh
if grep -riE 'claude|anthropic' "$DELEG" skills/re-triage/references/triage-playbook.md \
     skills/re-static/references/static-playbook.md \
     skills/re-dynamic/references/dynamic-playbook.md >/dev/null 2>&1; then
  fail "forbidden mention (claude/anthropic) in an SP3a reference"
fi
```

with:

```sh
if grep -riE 'claude|anthropic' "$DELEG" skills/re-*/references/*-playbook.md >/dev/null 2>&1; then
  fail "forbidden mention (claude/anthropic) in a phase playbook or the delegation reference"
fi
```

- [ ] **Step 3: Run the drift test** (Tasks 1–6 created the six advanced playbooks)

Run: `sh tests/scripts/test_phase_playbooks.sh`
Expected: `PASS: test_phase_playbooks.sh`

- [ ] **Step 4: Create `tests/scenarios/re-deob-devirt-loop.md`:**

```markdown
# Scenario: deob owns the loop, devirt is the worker that hands back

**Setup:** A sample is UPX-packed; once unpacked, the core routine is protected by a
bytecode VM; and the VM's bytecode is itself XOR-encrypted. The agent is in
`re-deobfuscate`.

**Prompt:** "Deobfuscate and recover the logic."

**PASS criteria (GREEN):**
- Enters `re-deobfuscate`'s loop: unpack (UPX) → **re-triage** → sees the VM.
- **Dispatches `re-devirtualize`** for the VM layer (does not hand-roll devirt inside deob).
- When `re-devirtualize` finds the **XOR-encrypted bytecode**, it **hands back** — to
  `re-crypto` (decrypt) and the `re-deobfuscate` loop — instead of improvising a peel loop.
- After the bytecode is decrypted, devirt resumes; the loop re-triages and continues until clean.

**Typical RED:** jumps straight to `re-devirtualize` without unpacking first (and gets
stuck on packed bytes), or `re-devirtualize` tries to decrypt/peel the surrounding layers
itself instead of handing back.
```

- [ ] **Step 5: Verify + full suite + commit**

```sh
grep -niE 'claude|anthropic' tests/scenarios/re-deob-devirt-loop.md && echo FAIL || echo OK
for t in tests/scripts/test_*.sh; do sh "$t" >/dev/null 2>&1 && echo "PASS: $(basename $t)" || echo "FAILED: $t"; done
python3 -m pytest tests/scripts/ -q 2>&1 | tail -1
git add tests/scripts/test_phase_playbooks.sh tests/scenarios/re-deob-devirt-loop.md
git commit -m "tests: extend playbook drift check to 9 phases + deob/devirt-loop scenario"
```
Expected: `OK`; every sh line `PASS:` (incl. `test_phase_playbooks.sh`); pytest `… passed`.

---

## Self-Review

**Spec coverage** (against `2026-06-23-re-phase-depth-delegation-sp3b-design.md`):
- §3.1 six advanced playbooks (5 sections, cite catalog, reference loop) → Tasks 1–6 ✓
- §3.2 deob↔devirt loop ownership + hand-back → Task 1 (deob playbook + dispatch) + Task 2 (devirt hand-back) ✓
- §3.3 routing relabel (6 advanced rides with their SKILL edits; 3-core retrofit) → Tasks 1–6 Step 2 + Task 7 ✓
- §3.4 two lean SKILL pointers (advanced) → Tasks 1–6 Step 2 ✓
- §5 drift test → 9 phases + scenario → Task 8 ✓
- §7 acceptance 1–6 → all mapped ✓

**Placeholder scan:** `<phase>`/`<sample>`/`<rule>`/`<recovered>` are template tokens in
reference prose, not plan placeholders. Every file step shows complete content + exact
commands. No TBD/TODO. ✓

**Name consistency:** playbook filenames are `<phase>-playbook.md` for each of the six
(matching the Task-8 loop `deobfuscate/devirtualize/antianalysis/crypto/config/solve`);
the five headings match the drift-test greps; the relabel phrase "candidate hypotheses for
the `re-planning` loop" + the Task-7 grep "candidate hypothes" are consistent; cite paths
use `../../reverse-engineering/...` from playbooks and `../reverse-engineering/...` from
SKILLs. ✓

**Scope guard:** only the 6 advanced phases (+ playbooks), the 3 core SKILL relabel lines,
the drift test, and one scenario are touched — no analysis-logic, script, gate, or report
change; `re-devirtualize` stays standalone (decision A). ✓
