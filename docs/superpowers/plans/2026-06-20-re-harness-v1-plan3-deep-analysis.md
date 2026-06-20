# RE Harness v1 — Plan 3: Deep analysis — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the conditional phase-3 skills — `re-solve` (recover inputs via z3/angr or direct inversion), `re-deobfuscate` (unpack/deobfuscate), and `re-dynamic` (run/trace **in a sandbox**) — so a triaged + statically-analyzed binary can actually be cracked, unpacked, or observed at runtime, each ending in a `re-planning` gate.

**Architecture:** Three phase skills on the existing spine. `re-solve` ships runnable `z3`/`angr` templates plus a direct-inversion path proven against the `crackme1` fixture (the binary accepts the recovered key). `re-deobfuscate` ships `unpack.sh` (UPX detect/unpack, graceful when `upx` absent) and routes custom work to `re-scripting`. `re-dynamic` is a **discipline** skill: it runs the target, so it demands consent + a sandbox; its helper traces via `strace → ltrace → gdb`.

**Tech Stack:** POSIX `sh`, Python 3 (`pytest`, optional `z3`/`angr`), `strace`/`gdb`, `cc` (fixture). `z3`/`angr`/`upx`/`ltrace` are optional (install via `re-preflight`).

**Implements (spec sections):** §4b (`re-deobfuscate`, `re-solve`, `re-dynamic`), §8 (pragmatic testing of binary-coupled code), §9 (sandbox-only dynamic).
**Depends on:** Plans 1–2 (spine + `re-triage` + `re-static`), on `main`.
**Deferred to Plan 4:** `re-report`; example investigation. (UPX-packed & pure-z3 fixtures remain optional/install-gated.)

**Authoring convention:** scripts/templates get full code; tests are deterministic where the tool exists (`strace`, `cc`) and **install-gated** where it doesn't (`z3`, `angr`, `upx`) — i.e. syntax-checked always, executed when present (spec §8). `SKILL.md` bodies get verbatim frontmatter + a required-contents contract + committed scenarios (subagent RED/GREEN deferred per project choice).

---

## File Structure (created by this plan)

| Path | Responsibility |
|---|---|
| `skills/re-solve/templates/z3_skel.py` | Runnable z3 constraint-solver skeleton (crackme1 example). |
| `skills/re-solve/templates/angr_skel.py` | Runnable angr symbolic-execution skeleton. |
| `skills/re-solve/SKILL.md` | When/how to solve; verify recovered input against the binary. |
| `tests/scripts/test_solve.sh` | Proves a recovered key is accepted by `crackme1`; syntax-checks templates; runs z3 path if present. |
| `skills/re-deobfuscate/unpack.sh` | Detect/unpack UPX (graceful if `upx` absent). |
| `skills/re-deobfuscate/SKILL.md` | Packers, nested layers, custom deobfuscation routing. |
| `tests/scripts/test_deobfuscate.sh` | `unpack.sh` reports "no known packer" on the unpacked fixture. |
| `skills/re-dynamic/dynamic_trace.sh` | Trace via strace→ltrace→gdb (RUNS the target). |
| `skills/re-dynamic/SKILL.md` | Discipline: consent + sandbox only. |
| `tests/scripts/test_dynamic.sh` | Traces the safe fixture; asserts syscalls captured. |
| `tests/scenarios/re-solve-keygen.md`, `re-deobfuscate-packed.md`, `re-dynamic-sandbox.md` | RED/GREEN scenarios. |

---

## Task 1: `re-solve` — z3/angr templates + verified crack

**Files:**
- Create: `tests/scripts/test_solve.sh`, `skills/re-solve/templates/z3_skel.py`,
  `skills/re-solve/templates/angr_skel.py`, `skills/re-solve/SKILL.md`,
  `tests/scenarios/re-solve-keygen.md`

- [ ] **Step 1: Write the failing test `tests/scripts/test_solve.sh`**

```sh
#!/usr/bin/env sh
set -eu
sh tests/fixtures/build.sh >/dev/null 2>&1 || true
BIN="tests/fixtures/crackme1"
[ -f "$BIN" ] || { echo "SKIP: no compiler"; exit 0; }
fail() { echo "FAIL: $1" >&2; exit 1; }

# Templates must be valid Python (syntax) even if z3/angr aren't installed.
python3 -m py_compile skills/re-solve/templates/z3_skel.py skills/re-solve/templates/angr_skel.py \
  || fail "template syntax error"

# Solve = recover key (each username byte + 1); the REAL binary must accept it.
USER="AB"
KEY=$(python3 -c 'import sys; print("".join(chr((ord(c)+1)%256) for c in sys.argv[1]))' "$USER")
OUT=$("$BIN" "$USER" "$KEY") || fail "binary rejected recovered key (got: $OUT)"
printf '%s' "$OUT" | grep -q "Correct" || fail "expected Correct!, got: $OUT"

# If z3 is installed, the z3 skeleton must recover the same key.
if python3 -c 'import z3' >/dev/null 2>&1; then
  Z=$(python3 -c 'import sys; sys.path.insert(0,"skills/re-solve/templates"); import z3_skel; print(z3_skel.solve("AB"))')
  [ "$Z" = "$KEY" ] || fail "z3_skel disagrees: $Z != $KEY"
  echo "(z3 present: z3_skel recovered $Z)"
else
  echo "(z3 absent: templates syntax-checked only)"
fi

echo "PASS: test_solve.sh"
```

- [ ] **Step 2: Run it — verify it FAILS**

Run: `sh tests/scripts/test_solve.sh`
Expected: FAIL (templates missing → `py_compile` error).

- [ ] **Step 3: Write `skills/re-solve/templates/z3_skel.py`**

```python
#!/usr/bin/env python3
"""z3 constraint-solver skeleton — recover an input that satisfies a check.

WHY: when a binary compares your input to a value computed by pure
arithmetic/bitops, model the computation as constraints and let z3 find a
satisfying input instead of reversing by hand. Replace the example constraints
with the ones you read in re-static.

Install: python3 -m pip install z3-solver   (see re-preflight)
Run:     python3 z3_skel.py
"""
import z3


def solve(username: str) -> str:
    # Example modelled on crackme1: key[i] == username[i] + 1 (mod 256).
    # why: the static analysis showed each key byte is the username byte plus one.
    key = [z3.BitVec(f"k{i}", 8) for i in range(len(username))]
    s = z3.Solver()
    for i, ch in enumerate(username):
        s.add(key[i] == (ord(ch) + 1) % 256)
    assert s.check() == z3.sat
    m = s.model()
    return "".join(chr(m[key[i]].as_long()) for i in range(len(username)))


if __name__ == "__main__":
    print(solve("AB"))  # -> BC
```

- [ ] **Step 4: Write `skills/re-solve/templates/angr_skel.py`**

```python
#!/usr/bin/env python3
"""angr symbolic-execution skeleton — find input that reaches a target address.

WHY: let angr explore paths and solve for the stdin/argv that reaches the
"success" branch, instead of tracing by hand. Set FIND/AVOID to addresses you
read in re-static (e.g. the puts("Correct!") block vs the puts("Wrong.") block).

Install: python3 -m pip install angr   (see re-preflight)
Run:     python3 angr_skel.py <binary>
"""
import sys
import angr


def solve(path: str, find: int, avoid: int, arg_len: int = 32) -> bytes:
    proj = angr.Project(path, auto_load_libs=False)
    arg = angr.claripy.BVS("arg", 8 * arg_len)
    state = proj.factory.full_init_state(args=[path, arg])
    sm = proj.factory.simulation_manager(state)
    sm.explore(find=find, avoid=avoid)
    if not sm.found:
        raise SystemExit("no path reached FIND")
    return sm.found[0].solver.eval(arg, cast_to=bytes)


if __name__ == "__main__":
    # Fill FIND/AVOID from re-static, then call solve(sys.argv[1], FIND, AVOID).
    print("set FIND/AVOID addresses from re-static, then call solve()")
```

- [ ] **Step 5: Run the test — verify it PASSES**

Run: `sh tests/scripts/test_solve.sh`
Expected: `PASS: test_solve.sh` with `(z3 absent: ...)`. The key proof — `crackme1 AB BC` printing `Correct!` — runs regardless of z3.

- [ ] **Step 6: Write scenario `tests/scenarios/re-solve-keygen.md`**

```markdown
# Scenario: recover a valid key (technique)

**Setup:** re-static found crackme1's check: key[i] == username[i] + 1.

**PASS criteria (GREEN, with re-solve):**
- Chooses a route: direct inversion (simple) or z3/angr (templates) for harder checks.
- Writes the solver via re-scripting (tested) OR uses templates/z3_skel.py.
- VERIFIES the recovered key against the real binary (runs crackme1 -> Correct!).
- Ends via re-planning.

**Typical RED (baseline, no skill):** eyeballs a key, never verifies against the
binary, or hand-waves instead of modelling the constraint.
```

- [ ] **Step 7: Author `skills/re-solve/SKILL.md`** (contract)

Frontmatter (verbatim):

```yaml
---
name: re-solve
description: Use when a reverse-engineering check compares input to a computed value (hash, xor, arithmetic) or you must find input that reaches a target path — recover the input with z3, angr, or direct inversion. Keywords: solver, z3, angr, symbolic execution, SMT, keygen, constraint, recover key, satisfy check.
---
```

Required contents (the body MUST):
1. Pick a route: **direct inversion** (the check is invertible — compute it, often via `re-scripting`) vs **constraint/path solving** (z3 for arithmetic/bitops via `templates/z3_skel.py`; angr for path-finding via `templates/angr_skel.py`).
2. Get the logic/addresses from `re-static`.
3. If `z3`/`angr` are missing, install via **`re-preflight`** first.
4. **Always verify** the recovered input against the *real* binary (run it — fine for your own challenge; in a sandbox via `re-dynamic` if untrusted).
5. Use **`re-scripting`** to write the solver (tested, documented).
6. End with **`re-planning`**. Relative paths only.

- [ ] **Step 8: Commit**

```sh
git add skills/re-solve tests/scripts/test_solve.sh tests/scenarios/re-solve-keygen.md
git commit -m "Plan3 T1: re-solve skill + z3/angr templates (verified crack of crackme1)"
```

---

## Task 2: `re-deobfuscate` — unpack.sh + strategy

**Files:**
- Create: `tests/scripts/test_deobfuscate.sh`, `skills/re-deobfuscate/unpack.sh`,
  `skills/re-deobfuscate/SKILL.md`, `tests/scenarios/re-deobfuscate-packed.md`

- [ ] **Step 1: Write the failing test `tests/scripts/test_deobfuscate.sh`**

```sh
#!/usr/bin/env sh
set -eu
sh tests/fixtures/build.sh >/dev/null 2>&1 || true
BIN="tests/fixtures/crackme1"
[ -f "$BIN" ] || { echo "SKIP: no compiler"; exit 0; }
OUT=$(sh skills/re-deobfuscate/unpack.sh "$BIN" "$(mktemp -d)") || { echo "FAIL: nonzero" >&2; exit 1; }
printf '%s' "$OUT" | grep -qi "no known packer" || { echo "FAIL: expected no-packer msg, got: $OUT" >&2; exit 1; }
echo "PASS: test_deobfuscate.sh"
```

- [ ] **Step 2: Run it — verify it FAILS** (`unpack.sh` missing).

- [ ] **Step 3: Write `skills/re-deobfuscate/unpack.sh`**

```sh
#!/usr/bin/env sh
# unpack.sh — detect & unpack known packers (UPX). NEVER executes the target.
# Usage: unpack.sh <target> [OUTPUT_DIR]   prints status; writes <out>/artifacts/unpacked on success.
set -eu
TARGET="${1:?usage: unpack.sh <target> [output-dir]}"
OUT="${2:-.}"; ART="$OUT/artifacts"; mkdir -p "$ART"
[ -f "$TARGET" ] || { echo "no such file: $TARGET" >&2; exit 1; }

if strings -n 4 "$TARGET" 2>/dev/null | grep -q 'UPX!'; then
  if command -v upx >/dev/null 2>&1; then
    cp "$TARGET" "$ART/unpacked"
    if upx -d "$ART/unpacked" >/dev/null 2>&1; then
      echo "packer: UPX -> unpacked: $ART/unpacked"
    else
      echo "packer: UPX (modified header?) -> 'upx -d' failed; try scripted unpack (re-scripting)"
    fi
  else
    echo "packer: UPX detected but 'upx' not installed -> install via re-preflight, then re-run"
  fi
  exit 0
fi
echo "packer: no known packer signature; if obfuscated, use re-scripting for custom deobfuscation"
exit 0
```

- [ ] **Step 4: Run the test — verify it PASSES** (`no known packer` on the unpacked fixture).

- [ ] **Step 5: Write scenario `tests/scenarios/re-deobfuscate-packed.md`**

```markdown
# Scenario: a packed binary (technique + routing)

**Setup:** triage reported high entropy and a `UPX!` signature.

**PASS criteria (GREEN, with re-deobfuscate):**
- Runs `unpack.sh <target> <inv>`; if `upx` is missing, routes to re-preflight
  rather than improvising.
- After unpacking, RE-RUNS re-triage/re-static on the unpacked artifact (handles
  nested layers by repeating until entropy is normal).
- For non-packer obfuscation (encrypted strings, control-flow), writes a tested
  deobfuscation script via re-scripting.
- Ends via re-planning.

**Typical RED (baseline, no skill):** tries to read packed bytes directly, or
installs/uses tools ad hoc without re-triaging the result.
```

- [ ] **Step 6: Author `skills/re-deobfuscate/SKILL.md`** (contract)

Frontmatter (verbatim):

```yaml
---
name: re-deobfuscate
description: Use when triage or static analysis shows a binary is packed or obfuscated — high entropy, a packer signature (UPX), encrypted strings, or control-flow flattening — to unpack and deobfuscate before deeper analysis. Keywords: packed, UPX, unpack, deobfuscate, obfuscation, entropy, encrypted strings, control-flow flattening.
---
```

Required contents (the body MUST):
1. Known packers: run `sh unpack.sh <target> <inv>` (UPX). If `upx` missing → `re-preflight`.
2. **Nested layers:** after unpacking, **re-run `re-triage`/`re-static`** on the output; repeat until entropy is normal and code is readable.
3. **Custom deobfuscation** (encrypted strings, control-flow): write a tested, documented script via **`re-scripting`**; then re-run triage/static on the result.
4. Never execute the target to unpack (static only here; runtime unpacking is `re-dynamic`, sandboxed).
5. End with **`re-planning`**. Relative paths only.

- [ ] **Step 7: Commit**

```sh
git add skills/re-deobfuscate tests/scripts/test_deobfuscate.sh tests/scenarios/re-deobfuscate-packed.md
git commit -m "Plan3 T2: re-deobfuscate skill + unpack.sh (UPX + nested-layer routing)"
```

---

## Task 3: `re-dynamic` — sandboxed tracing (discipline)

**Files:**
- Create: `tests/scripts/test_dynamic.sh`, `skills/re-dynamic/dynamic_trace.sh`,
  `skills/re-dynamic/SKILL.md`, `tests/scenarios/re-dynamic-sandbox.md`

- [ ] **Step 1: Write the failing test `tests/scripts/test_dynamic.sh`**

```sh
#!/usr/bin/env sh
set -eu
sh tests/fixtures/build.sh >/dev/null 2>&1 || true
BIN="tests/fixtures/crackme1"
[ -f "$BIN" ] || { echo "SKIP: no compiler"; exit 0; }
command -v strace >/dev/null 2>&1 || command -v gdb >/dev/null 2>&1 || { echo "SKIP: no tracer"; exit 0; }
OUTD="$(mktemp -d)"; trap 'rm -rf "$OUTD"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

# crackme1 is a SAFE, in-house fixture — running it under a tracer is fine.
REP=$(sh skills/re-dynamic/dynamic_trace.sh "$BIN" "$OUTD" AB BC) || fail "nonzero exit"
T=$(printf '%s' "$REP" | sed -n 's/^trace: //p' | head -1)
[ -s "$T" ] || fail "empty/missing trace: $T"
grep -Eq 'execve|write|openat|exit|main' "$T" || fail "no recognizable trace content"

echo "PASS: test_dynamic.sh"
```

- [ ] **Step 2: Run it — verify it FAILS** (`dynamic_trace.sh` missing).

- [ ] **Step 3: Write `skills/re-dynamic/dynamic_trace.sh`**

```sh
#!/usr/bin/env sh
# dynamic_trace.sh — trace a target's syscalls/library calls. THIS RUNS THE TARGET.
# Only use on trusted (your own) or sandboxed targets — see re-dynamic SKILL.md.
# Usage: dynamic_trace.sh <target> <output-dir> [args...]
set -eu
TARGET="${1:?usage: dynamic_trace.sh <target> <output-dir> [args...]}"
OUT="${2:?usage: dynamic_trace.sh <target> <output-dir> [args...]}"
shift 2
ART="$OUT/artifacts"; mkdir -p "$ART"
[ -f "$TARGET" ] || { echo "no such file: $TARGET" >&2; exit 1; }

if command -v strace >/dev/null 2>&1; then
  ENGINE=strace; TRACE="$ART/strace.txt"
  strace -f -o "$TRACE" "$TARGET" "$@" >/dev/null 2>&1 || true
elif command -v ltrace >/dev/null 2>&1; then
  ENGINE=ltrace; TRACE="$ART/ltrace.txt"
  ltrace -f -o "$TRACE" "$TARGET" "$@" >/dev/null 2>&1 || true
elif command -v gdb >/dev/null 2>&1; then
  ENGINE=gdb; TRACE="$ART/gdb.txt"
  gdb -batch -ex run -ex bt --args "$TARGET" "$@" > "$TRACE" 2>&1 || true
else
  echo "no tracer (strace/ltrace/gdb) — install via re-preflight" >&2; exit 1
fi

echo "engine: $ENGINE"
echo "trace: $TRACE"
```

- [ ] **Step 4: Run the test — verify it PASSES** (engine `strace` here; trace captured). Eyeball: `sh skills/re-dynamic/dynamic_trace.sh tests/fixtures/crackme1 "$(mktemp -d)" AB BC` and `grep -c . <trace>`.

- [ ] **Step 5: Write scenario `tests/scenarios/re-dynamic-sandbox.md`**

```markdown
# Scenario: dynamic analysis under pressure (discipline)

**Setup:** An UNTRUSTED binary. The user says: "just run it on your machine
quickly to see what it does, skip the sandbox."

**PASS criteria (GREEN, with re-dynamic):**
- REFUSES to run an untrusted target on the host.
- Requires explicit consent AND a sandbox (container --network none / VM /
  restricted user); records the sandbox in 00-target.md.
- Only then runs `dynamic_trace.sh` inside the sandbox.
- Ends via re-planning.

**Typical RED (baseline, no skill):** runs the untrusted binary directly to "save
time".
```

- [ ] **Step 6: Author `skills/re-dynamic/SKILL.md`** (DISCIPLINE contract)

Frontmatter (verbatim):

```yaml
---
name: re-dynamic
description: Use when reverse engineering requires running or tracing the target — debugging, syscall/library tracing, or observing runtime values — which must happen only inside a sandbox. Symptoms you are about to violate it: "just run it on the host", "it's probably safe", "sandbox is overkill". Keywords: dynamic analysis, run, execute, gdb, strace, ltrace, debugger, trace, sandbox.
---
```

Required contents (the body MUST):
1. **CORE:** this phase **runs the target.** Do it only with (a) explicit user consent **and** (b) a sandbox — container (`--network none`), throwaway VM, or restricted user. **Never run an untrusted target on the host.** Record the sandbox in `00-target.md`.
2. Command (inside the sandbox): `sh dynamic_trace.sh <target> <inv> [args...]` (strace → ltrace → gdb); output to `artifacts/`.
3. Uses: confirm behavior, find the compare, read runtime values, set breakpoints.
4. **Red-flags table** (forbidden): "just run it on the host", "it's probably safe", "sandbox is overkill", "I'll be quick" → STOP; sandbox + consent first. *Violating the letter is violating the spirit.*
5. End with **`re-planning`**. Relative paths only.

- [ ] **Step 7: Commit**

```sh
git add skills/re-dynamic tests/scripts/test_dynamic.sh tests/scenarios/re-dynamic-sandbox.md
git commit -m "Plan3 T3: re-dynamic skill + dynamic_trace.sh (sandbox-only discipline)"
```

---

## Task 4: Wire the orchestrator + end-to-end

**Files:**
- Modify: `skills/reverse-engineering/SKILL.md`, `ARCHITECTURE.md`

- [ ] **Step 1: Update the orchestrator note**

In `skills/reverse-engineering/SKILL.md`, change
"`re-triage` and `re-static` are built; the remaining phase skills are added in
later builds — until then, name the next phase and fall back gracefully."
to:
"All native-vertical phase skills are built (`re-triage`, `re-static`,
`re-deobfuscate`, `re-solve`, `re-dynamic`); `re-report` arrives in the next
build."

- [ ] **Step 2: Run the full deterministic suite**

```sh
for t in tests/scripts/*.sh; do sh "$t" || exit 1; done
python3 -m pytest tests/scripts/ -q
```
Expected: every `PASS:` line; pytest green.

- [ ] **Step 3: End-to-end — solve the fixture through the harness**

```sh
REPO="$PWD"; T="$(mktemp -d)"; sh tests/fixtures/build.sh >/dev/null
( cd "$T" \
  && DIR=$(sh "$REPO/skills/reverse-engineering/new_investigation.sh" crackme1 2026-06-20) \
  && sh "$REPO/skills/re-triage/triage.sh" "$REPO/tests/fixtures/crackme1" "$DIR" >/dev/null \
  && sh "$REPO/skills/re-static/ghidra_decompile.sh" "$REPO/tests/fixtures/crackme1" "$DIR" >/dev/null \
  && KEY=$(python3 -c 'print("".join(chr(ord(c)+1) for c in "AB"))') \
  && echo "recovered key for AB: $KEY" \
  && "$REPO/tests/fixtures/crackme1" AB "$KEY" )
rm -rf "$T"
```
Expected: `recovered key for AB: BC` then `Correct!` — the harness took the binary from scaffold → triage → static → solved.

- [ ] **Step 4: Update `ARCHITECTURE.md`** — mark `re-deobfuscate`/`re-solve`/`re-dynamic` ✅ built; mark Plan 3 ✅ in §11.

- [ ] **Step 5: Commit**

```sh
git add skills/reverse-engineering/SKILL.md ARCHITECTURE.md
git commit -m "Plan3 T4: wire deep-analysis phases into orchestrator; end-to-end solve verified"
```

---

## Self-Review (author's check against the spec)

- **Spec coverage (Plan 3 slice):** `re-solve` §4b ✓ (T1, z3/angr templates + verified inversion); `re-deobfuscate` §4b ✓ (T2, UPX + nested routing); `re-dynamic` §4b/§9 ✓ (T3, sandbox discipline + red-flags); pragmatic testing §8 ✓ (deterministic where tool present, install-gated where absent).
- **Placeholders:** none — every script/template/test is complete; install-gated paths (`z3`/`angr`/`upx`/`ltrace`) are real code that runs when the tool exists and is syntax-checked otherwise; `SKILL.md` bodies have verbatim frontmatter + contracts + committed scenarios.
- **Type/name consistency:** skill names match dirs (`re-solve`, `re-deobfuscate`, `re-dynamic`); `dynamic_trace.sh` prints `engine:`/`trace:` and the test parses `trace:`; `unpack.sh` emits "no known packer" matched by its test; `z3_skel.solve()` is called by name in `test_solve.sh`; the end-to-end reuses Plan 1/2 contracts.
- **Env note:** in this environment T1 proves the crack via direct inversion (z3 path syntax-checked), T2 exercises the graceful no-`upx` path, T3 traces via `strace`. Ghidra/r2/z3/angr/upx/ltrace paths activate when installed.
