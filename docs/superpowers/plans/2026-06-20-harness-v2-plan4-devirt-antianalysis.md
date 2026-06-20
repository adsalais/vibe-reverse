# Harness v2 — Plan 4: Devirtualization + Anti-Analysis — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the two research-grade skills — `re-devirtualize` (VM-based obfuscation, incl. nested/recursive VMs) and `re-antianalysis` (detect & neutralize the target's defenses) — completing the v2 family at **14 skills**.

**Architecture:** Both are mostly disciplined **methodology + references + adaptable templates**. `re-antianalysis` ships a static signature scanner (`antianalysis_scan.sh`) and a technique→bypass catalog. `re-devirtualize` ships a methodology doc and Triton/miasm skeletons the agent adapts via `re-scripting`. Both lean hard on `references/long-running-ops.md` and on honest, confidence-tagged partial results.

**Tech Stack:** POSIX `sh`, Python 3, Triton/miasm/angr/unicorn (baked in Plan 2), markdown.

**Implements (spec sections):** §5.2 (re-devirtualize), §5.3 (re-antianalysis).
**Depends on:** Plans 1–3 on `main` (orchestrator routing + the deob router already route to these).
**Completes:** v2 (14 skills).

**Plan sequence:** Plan 4 of 4.

## Global Constraints

- Skills tool-neutral; helper files by **relative path**; frontmatter `name` == dir name.
- Helper scripts: POSIX `sh` + `set -eu`; **never execute the target** in a static path; tool-optional.
- Devirtualization/anti-analysis work is often slow and partial: follow `references/long-running-ops.md` (background + budget + **ask before killing**) and **report confidence + partial results, never overclaim**.
- Air-gap rule: never install anything.
- Commit messages end with: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

## File Structure

| Path | Responsibility |
|---|---|
| `skills/re-antianalysis/antianalysis_scan.sh` | Static scan for anti-analysis signatures. |
| `skills/re-antianalysis/references/anti-analysis-catalog.md` | technique → detection signature → bypass. |
| `skills/re-antianalysis/SKILL.md` | Detect & neutralize the target's defenses. |
| `skills/re-devirtualize/references/devirt-methodology.md` | The 7-step devirt method + commercial VMs + recursion. |
| `skills/re-devirtualize/templates/triton_handler.py` | Recover one handler's semantics (Triton). |
| `skills/re-devirtualize/templates/miasm_lift.py` | Lift bytecode → IR (miasm). |
| `skills/re-devirtualize/SKILL.md` | Devirtualization methodology skill. |
| `tests/scripts/test_antianalysis_scan.sh`, `test_devirt_templates.py` | Behavioral / compile tests. |
| `tests/scenarios/re-antianalysis-antidebug.md`, `re-devirtualize-vm.md` | RED/GREEN scenarios (descriptive). |
| `deploy/smoke.sh`, `ARCHITECTURE.md`, `AGENTS.md`, `README.md` | Skill count 12 → 14; v2 complete. |

---

## Task 1: `re-antianalysis`

**Files:**
- Create: `tests/scripts/test_antianalysis_scan.sh`, `skills/re-antianalysis/antianalysis_scan.sh`, `skills/re-antianalysis/references/anti-analysis-catalog.md`, `skills/re-antianalysis/SKILL.md`, `tests/scenarios/re-antianalysis-antidebug.md`

**Interfaces:**
- Produces: `antianalysis_scan.sh <target> <out-dir>` → writes `<out>/artifacts/antianalysis/antianalysis.txt`; prints `[FLAG]`/`[ ok ]` lines per category. Never executes the target.

- [ ] **Step 1: Write the failing test `tests/scripts/test_antianalysis_scan.sh`**

```sh
#!/usr/bin/env sh
set -eu
fail() { echo "FAIL: $1" >&2; exit 1; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
# a file whose strings include classic anti-debug / anti-VM markers
printf 'ptrace IsDebuggerPresent TracerPid VBoxGuest vmware\n' > "$TMP/s.bin"
OUT=$(sh skills/re-antianalysis/antianalysis_scan.sh "$TMP/s.bin" "$TMP/inv") || fail "nonzero"
printf '%s' "$OUT" | grep -q '\[FLAG\] anti-debug' || fail "anti-debug not flagged"
printf '%s' "$OUT" | grep -q '\[FLAG\] anti-VM'    || fail "anti-VM not flagged"
[ -f "$TMP/inv/artifacts/antianalysis/antianalysis.txt" ] || fail "report missing"
# a clean file flags nothing in those categories
printf 'hello world\n' > "$TMP/clean.bin"
OUT2=$(sh skills/re-antianalysis/antianalysis_scan.sh "$TMP/clean.bin" "$TMP/inv2")
printf '%s' "$OUT2" | grep -q '\[FLAG\] anti-debug' && fail "false positive on clean file" || true
echo "PASS: test_antianalysis_scan.sh"
```

- [ ] **Step 2: Run it — verify it FAILS** (`antianalysis_scan.sh` missing).

- [ ] **Step 3: Implement `skills/re-antianalysis/antianalysis_scan.sh`**

```sh
#!/usr/bin/env sh
# antianalysis_scan.sh — flag common anti-analysis signatures (static). NEVER runs
# the target. String-based API checks + an optional objdump pass for rdtsc/cpuid.
# Usage: antianalysis_scan.sh <target> <out-dir>
set -eu
TARGET="${1:?usage: antianalysis_scan.sh <target> <out-dir>}"
OUT="${2:?usage: antianalysis_scan.sh <target> <out-dir>}"
ART="$OUT/artifacts/antianalysis"; mkdir -p "$ART"
[ -f "$TARGET" ] || { echo "no such file: $TARGET" >&2; exit 1; }
REPORT="$ART/antianalysis.txt"
STR=$(strings -n 4 "$TARGET" 2>/dev/null || true)

check() { # <label> <regex>
  if printf '%s' "$STR" | grep -Eiq "$2"; then echo "[FLAG] $1"; else echo "[ ok ] $1"; fi
}
{
  echo "== anti-analysis scan: $TARGET =="
  check "anti-debug (ptrace/IsDebuggerPresent/TracerPid/NtQueryInformationProcess)" \
        'ptrace|IsDebuggerPresent|CheckRemoteDebugger|TracerPid|NtQueryInformationProcess|NtSetInformationThread'
  check "timing (GetTickCount/QueryPerformanceCounter/timeGetTime)" \
        'GetTickCount|QueryPerformanceCounter|timeGetTime'
  check "anti-VM (VBox/VMware/QEMU/Xen/VirtualBox)" \
        'vbox|vmware|qemu|xen|virtualbox'
  check "anti-sandbox (sbiedll/sandbox/wine)" \
        'sbiedll|sandboxie|sample|malware|wine_get'
  check "self-integrity / anti-dump (VirtualProtect/checksum/crc)" \
        'VirtualProtect|NtProtectVirtualMemory|checksum|crc32'
  if command -v objdump >/dev/null 2>&1; then
    DIS=$(objdump -d "$TARGET" 2>/dev/null || true)
    printf '%s' "$DIS" | grep -qiw 'rdtsc' && echo "[FLAG] rdtsc instruction (timing-based)" || echo "[ ok ] rdtsc instruction"
    printf '%s' "$DIS" | grep -qiw 'cpuid' && echo "[FLAG] cpuid instruction (VM detection)" || echo "[ ok ] cpuid instruction"
  fi
} | tee "$REPORT"
```

- [ ] **Step 4: Run the test — verify it PASSES** (`PASS: test_antianalysis_scan.sh`).

- [ ] **Step 5: Write `skills/re-antianalysis/references/anti-analysis-catalog.md`**

```markdown
# Anti-analysis catalog — technique → detection → bypass

| Technique | Detection signature | Bypass |
|---|---|---|
| ptrace self-attach (Linux) | `ptrace(PTRACE_TRACEME)`; fails if a debugger is attached | run without a debugger, or patch the check / force the return value in gdb |
| IsDebuggerPresent / PEB.BeingDebugged | `IsDebuggerPresent`, PEB byte read | patch the branch; set PEB byte 0; emulator lies |
| NtQueryInformationProcess(ProcessDebugPort) | the Nt call + a compare | hook/patch the return; qiling hook |
| /proc/self/status TracerPid (Linux) | opens status, parses `TracerPid:` | run untraced; or fake the file in the emulator |
| rdtsc timing | `rdtsc` pairs around a region, delta compared | patch out; emulator returns controlled TSC |
| cpuid hypervisor bit | `cpuid` leaf 1 ECX bit 31 / leaf 0x40000000 | emulator/hook returns bare-metal values |
| anti-VM artifacts | strings: VBox/VMware/QEMU, MAC OUI, registry keys, files | run on bare-metal-like sandbox; hook the queries |
| anti-disassembly | junk bytes, overlapping instructions, opaque jumps | force linear/correct disasm in r2/Ghidra; this is a deob layer → re-deobfuscate |
| TLS callbacks / early entry | code runs before `main` (PE TLS dir) | set breakpoints on TLS callbacks before run |
| self-integrity / checksum | hashes its own code; refuses if patched | patch after the check, or hook the verifier to pass |

Sandbox-evasion that just **sleeps**: skip the sleep (debugger/emulator) rather than
wait it out. When emulating with qiling, install hooks that make these checks lie.
```

- [ ] **Step 6: Author `skills/re-antianalysis/SKILL.md`**

Frontmatter (verbatim):

```yaml
---
name: re-antianalysis
description: Use when a reverse-engineering target resists analysis — anti-debugging (ptrace, IsDebuggerPresent), anti-VM/sandbox (CPUID, timing, VM artifacts), anti-disassembly, or self-integrity checks — to detect and neutralize those defenses. Keywords: anti-debug, anti-VM, anti-sandbox, anti-disassembly, ptrace, IsDebuggerPresent, rdtsc, cpuid, evasion, bypass checks, TracerPid, self-integrity.
---
```

Required contents (the body MUST):
1. Scope: **detect & neutralize** the target's own anti-analysis. Pairs with `re-dynamic` (apply at detonation/emulation) and feeds `re-deobfuscate` (anti-disasm is a deob layer).
2. **Detect:** run `sh antianalysis_scan.sh <target> <investigation-dir>` (static signatures + rdtsc/cpuid) and cross-check capa; map hits via `references/anti-analysis-catalog.md`.
3. **Neutralize** (pick per technique, cite the catalog): patch the check out (keystone/lief via `re-scripting`), force the return in gdb, or make the emulator **lie** (qiling hooks faking TracerPid/CPUID/timing). Re-verify the target now proceeds.
4. Slow/iterative work follows `../reverse-engineering/references/long-running-ops.md`; record neutralized checks in the report's "Obfuscation & anti-analysis" section.
5. End with **`re-planning`**. Relative paths only.

- [ ] **Step 7: Write scenario `tests/scenarios/re-antianalysis-antidebug.md`**

```markdown
# Scenario: defeat anti-debugging (technique test)

**Setup:** A Linux sample exits immediately under gdb. `antianalysis_scan.sh` flags
`ptrace` and a `/proc/self/status` TracerPid read. The user wants to debug it.

**Prompt:** "This binary won't run under my debugger — get me past its protections."

**PASS criteria (GREEN, with re-antianalysis):**
- Runs antianalysis_scan.sh; identifies the ptrace/TracerPid anti-debug from the
  catalog (does not guess randomly).
- Chooses a concrete bypass (patch the check via re-scripting, or force the ptrace
  return in gdb, or fake TracerPid in the emulator) and explains why.
- Re-verifies the target proceeds; records the neutralized check.

**Typical RED (baseline, no skill):** concludes "it just crashes" or tries random
gdb commands without identifying or bypassing the specific anti-debug technique.
```

- [ ] **Step 8: RED/GREEN test the skill** with `re-antianalysis-antidebug.md`. Close loopholes; re-run.

- [ ] **Step 9: Commit**

```sh
git add skills/re-antianalysis tests/scripts/test_antianalysis_scan.sh tests/scenarios/re-antianalysis-antidebug.md
git commit -m "Plan2-4 T1: re-antianalysis skill + antianalysis_scan.sh + catalog"
```

---

## Task 2: `re-devirtualize`

**Files:**
- Create: `tests/scripts/test_devirt_templates.py`, `skills/re-devirtualize/templates/triton_handler.py`, `skills/re-devirtualize/templates/miasm_lift.py`, `skills/re-devirtualize/references/devirt-methodology.md`, `skills/re-devirtualize/SKILL.md`, `tests/scenarios/re-devirtualize-vm.md`

- [ ] **Step 1: Write the failing test `tests/scripts/test_devirt_templates.py`**

```python
import py_compile
from pathlib import Path

TEMPLATES = [
    Path("skills/re-devirtualize/templates/triton_handler.py"),
    Path("skills/re-devirtualize/templates/miasm_lift.py"),
]

def test_exist():
    for t in TEMPLATES:
        assert t.is_file(), f"{t} missing"

def test_compile():
    for t in TEMPLATES:
        py_compile.compile(str(t), doraise=True)
```

- [ ] **Step 2: Run it — verify it FAILS**

Run: `python3 -m pytest tests/scripts/test_devirt_templates.py -q`
Expected: FAIL (templates missing).

- [ ] **Step 3: Implement `skills/re-devirtualize/templates/triton_handler.py`**

```python
#!/usr/bin/env python3
"""Recover one VM handler's semantics by symbolic execution (Triton).

WHY: a virtualized binary replaces native code with a fetch-decode-execute loop over
bytecode; each handler implements one virtual opcode. Symbolically executing a single
handler and reading the resulting expression for the output register tells you what
that opcode DOES (e.g. "vreg2 = vreg0 + vreg1") without reversing it by hand. Repeat
per handler to build an opcode->semantics table — the core of devirtualization.

Adapt: set the handler start/end addresses and the VM context (register) layout.
Usage: python3 triton_handler.py <target> <handler_start_hex> <handler_end_hex>
"""
import argparse


def recover(target: str, start: int, end: int) -> None:
    # why: import here so the template byte-compiles where Triton is absent.
    from triton import TritonContext, ARCH  # noqa: F401
    # ctx = TritonContext(ARCH.X86_64); map the code bytes; symbolize the virtual
    # registers / VM context; emulate start..end; print the symbolic AST of each
    # modified vreg to read off the opcode's semantics. (Fill in for this VM.)
    raise SystemExit("Fill in the VM context layout + emulation loop (see SKILL.md).")


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("target")
    p.add_argument("handler_start", help="hex address of the handler start")
    p.add_argument("handler_end", help="hex address of the handler end")
    a = p.parse_args()
    recover(a.target, int(a.handler_start, 16), int(a.handler_end, 16))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Implement `skills/re-devirtualize/templates/miasm_lift.py`**

```python
#!/usr/bin/env python3
"""Lift recovered VM bytecode to miasm IR and simplify it.

WHY: once each virtual opcode's semantics are known (see triton_handler.py), the VM
program is just a list of (opcode, operands). Mapping each to its IR effect and
chaining them yields a miasm IR block you can simplify and read as near-native logic
— the devirtualized function. Handle nested VMs by lifting the INNER VM first, then
substituting its lifted result into the outer program.

Adapt: provide the recovered bytecode and the opcode->semantics table.
Usage: python3 miasm_lift.py <bytecode_file> <opcode_table_json>
"""
import argparse
import json


def lift(bytecode: bytes, opmap: dict) -> str:
    # why: import here so the template byte-compiles where miasm is absent.
    from miasm.expression.expression import ExprId  # noqa: F401
    # for each (opcode, operands) in the decoded bytecode: build its IR from opmap,
    # chain into an IRBlock, run the symbolic/expression simplifier, and render the
    # simplified expressions as pseudocode. (Fill in for this VM.)
    raise SystemExit("Fill in the opcode->IR mapping + simplification (see SKILL.md).")


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("bytecode_file")
    p.add_argument("opcode_table_json", help="JSON: opcode -> recovered semantics")
    a = p.parse_args()
    bc = open(a.bytecode_file, "rb").read()
    opmap = json.load(open(a.opcode_table_json))
    print(lift(bc, opmap))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 5: Run the test — verify it PASSES** (`2 passed`).

- [ ] **Step 6: Write `skills/re-devirtualize/references/devirt-methodology.md`**

```markdown
# Devirtualization methodology

Code virtualization replaces native instructions with bytecode interpreted by an
embedded VM. Goal: recover readable logic. Expect **partial** results — report
confidence.

## Recognize a VM
- A central **dispatcher** loop: read next bytecode, index a **handler table**,
  jump. Look for a big jump/switch table and a loop that keeps returning to it.
- A **virtual program counter** (a register/memory slot stepped each iteration) and
  a **VM context** struct holding virtual registers.
- Commercial: VMProtect, Themida/WinLicense, Code Virtualizer; academic: Tigress.
  Custom VMs are common in CTF and bespoke malware.

## Steps
1. **Locate** the dispatcher + handler table; enumerate handler addresses.
2. **Recover the bytecode** (the VM program — often pointed to at VM entry).
3. **Derive each handler's semantics** — symbolically execute one handler
   (`templates/triton_handler.py`) and read the output expression. Build an
   opcode → semantics table.
4. **Decode** the bytecode into (opcode, operands) using the VM's instruction format.
5. **Lift** to IR and simplify (`templates/miasm_lift.py`) → near-native pseudocode.
6. **Recursion / nesting:** if a handler itself enters another VM, treat the inner
   VM with steps 1–5 first, substitute its lifted result, then continue the outer.
   Track depth; each level multiplies cost — budget + ask-before-kill apply.
7. **Verify** by emulating the lifted logic vs the original on sample inputs
   (qiling/unicorn). Note any unhandled handlers as gaps.

## Honesty
A clean full devirtualization of a commercial protector is rarely one-shot. Deliver
the dispatcher map + opcode table + a partial lift with a clear confidence note and
the list of handlers still unresolved — that is real progress, not failure.
```

- [ ] **Step 7: Author `skills/re-devirtualize/SKILL.md`**

Frontmatter (verbatim):

```yaml
---
name: re-devirtualize
description: Use when a reverse-engineering target is protected by code virtualization / a VM-based obfuscator (VMProtect, Themida, Tigress, or a custom bytecode VM, possibly nested) — to find the dispatcher, recover the bytecode and handler semantics, and lift it back to readable logic. Keywords: devirtualize, virtualization, VMProtect, Themida, Tigress, VM obfuscation, dispatcher, handler table, bytecode, lifting, nested VM, recursion.
---
```

Required contents (the body MUST):
1. When to use: triage/static/deob shows a dispatcher loop + handler table (virtualized code). Usually reached via the `re-deobfuscate` router.
2. Follow `references/devirt-methodology.md`: locate dispatcher → recover bytecode → derive handler semantics (`templates/triton_handler.py`) → decode → lift (`templates/miasm_lift.py`) → **recurse for nested VMs** → verify by emulation.
3. Adapt the templates via **`re-scripting`** (tested where the logic is deterministic, e.g. the bytecode decoder); run heavy symbolic/lift steps per `../reverse-engineering/references/long-running-ops.md` (background + budget + **ask before killing**).
4. **Honesty (REQUIRED):** devirt is typically partial — deliver the dispatcher map, opcode→semantics table, and a confidence-tagged partial lift with unresolved handlers listed. Never present a partial lift as a complete decompilation.
5. End with **`re-planning`**. Relative paths only.

- [ ] **Step 8: Write scenario `tests/scenarios/re-devirtualize-vm.md`**

```markdown
# Scenario: virtualized check (technique + honesty test)

**Setup:** Static analysis of a crackme shows no normal logic — `main` enters a loop
that reads a byte array, indexes a 32-entry table of small functions, and jumps.
There is no straight-line key check. The user wants the key.

**Prompt:** "I can't find the check — the code is just a big interpreter loop. Help."

**PASS criteria (GREEN, with re-devirtualize):**
- Recognizes a VM (dispatcher + handler table + bytecode), per the methodology.
- Lays out the steps: enumerate handlers, recover semantics (Triton template),
  decode bytecode, lift (miasm template); mentions recursion if a handler nests.
- Tags heavy steps with cost and is HONEST about partial results / confidence.
- Ends at a re-planning gate; does NOT claim a full decompile from a glance.

**Typical RED (baseline, no skill):** tries to read the dispatcher as if it were
normal code, or claims it "can't be reversed", with no VM-recovery plan.
```

- [ ] **Step 9: RED/GREEN test the skill** with `re-devirtualize-vm.md`. Close loopholes; re-run.

- [ ] **Step 10: Commit**

```sh
git add skills/re-devirtualize tests/scripts/test_devirt_templates.py tests/scenarios/re-devirtualize-vm.md
git commit -m "Plan2-4 T2: re-devirtualize skill + Triton/miasm templates + methodology"
```

---

## Task 3: Finalize v2 — skill count, docs, full suite

**Files:**
- Modify: `deploy/smoke.sh`, `ARCHITECTURE.md`, `AGENTS.md`, `README.md`

- [ ] **Step 1: Bump the baked-skill count in `deploy/smoke.sh`** (12 → 14)

```sh
n=$(ls -1d /opt/vibe-reverse/skills/*/ 2>/dev/null | wc -l)
[ "$n" -eq 14 ] || fail "expected 14 skills, found $n"
```
```sh
ok "14 skills baked"
```

- [ ] **Step 2: Finalize `ARCHITECTURE.md`**

- §4 tables: mark `re-devirtualize` + `re-antianalysis` built; the family is **14 skills** (spine: reverse-engineering, re-planning, re-scripting, re-continue; phases: re-triage, re-static, re-deobfuscate, re-devirtualize, re-antianalysis, re-crypto, re-config, re-solve, re-dynamic, re-report). Confirm `re-preflight` is gone.
- Note v2 is complete; whitebox crypto + `re-diff` + firmware/managed/wasm remain roadmap.

- [ ] **Step 3: Finalize `AGENTS.md`** — skill count **14**; repo map lists all 14; confirm air-gap / numbered-list / long-running conventions are documented.

- [ ] **Step 4: Update `README.md`** — status: "v2 complete: air-gapped harness, 14 skills (stacked-obfuscation router, devirtualization, anti-analysis, crypto, config/IOC, checkpoint/resume). Whitebox crypto is the next spec."

- [ ] **Step 5: Run the full deterministic suite**

```sh
for t in tests/scripts/test_*.sh; do sh "$t" || { echo "FAILED: $t"; exit 1; }; done
python3 -m pytest tests/scripts/ -q
( cd docs/reverse/_example/crackme1/scripts && python3 -m pytest -q )
```
Expected: all PASS.

- [ ] **Step 6: Sanity-check the skill tree count**

```sh
n=$(ls -1d skills/*/ | wc -l); echo "skills: $n"
```
Expected: `skills: 14`.

- [ ] **Step 7: Commit**

```sh
git add deploy/smoke.sh ARCHITECTURE.md AGENTS.md README.md
git commit -m "Plan2-4 T3: finalize v2 — 14 skills; smoke count 14; docs complete"
```

---

## Self-Review (author's check against the spec)

- **Spec coverage (Plan 4 slice):** re-antianalysis §5.3 ✓ (T1, detect via antianalysis_scan + catalog, neutralize, pairs with dynamic/deob); re-devirtualize §5.2 ✓ (T2, full 7-step methodology incl. recursion, Triton+miasm templates, honesty/partial framing). v2 success criteria — VM partial lift + nested recursion (T2 methodology/scenario), never-overclaim (T2 honesty contract) — ✓. Family completes at 14 (T3).
- **Placeholders:** none — `antianalysis_scan.sh` + tests are complete; templates byte-compile and are tested; references are concrete; the templates intentionally raise "fill in" SystemExit as per-target skeletons (documented, compile-tested). Scenarios are descriptive (the v1 pattern for discipline/technique scenarios that don't need a compiled fixture).
- **Type/name consistency:** `antianalysis_scan.sh <target> <out-dir>` writes `artifacts/antianalysis/antianalysis.txt` and emits `[FLAG] anti-debug`/`[FLAG] anti-VM` exactly as the test greps; template paths `skills/re-devirtualize/templates/{triton_handler,miasm_lift}.py` match the compile test; skill names equal dir names (`re-devirtualize`, `re-antianalysis`); smoke count 14 matches the final `ls skills/*/` count (spine 4 + phases 10).
```
