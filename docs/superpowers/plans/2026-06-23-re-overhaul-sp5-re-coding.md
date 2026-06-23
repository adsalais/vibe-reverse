# SP5 — `re-coding` (rework `re-scripting`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework `re-scripting` into `re-coding`: a plan→bounded-implementer-subagent→code-review flow, a Python/shell/Rust language heuristic, real (std-only) Rust support, and the rename across live files.

**Architecture:** Rename the skill dir + rewrite the SKILL around the new flow; add a Rust template + bake `rustc`; add an "implement a tested plan" category to `delegating-to-subagents.md`; sed the `re-scripting`→`re-coding` rename across live files (historical docs untouched).

**Tech Stack:** Markdown skills; Python (`python_template.py`, pytest); Rust (`rust_template.rs`, `rustc --test`, std-only); Dockerfile.

**Spec:** `docs/superpowers/specs/2026-06-23-re-coding-sp5-design.md`

## Global Constraints

- **No "claude"/"anthropic"** in content; relative paths only; `re-coding/SKILL.md` < 500 lines.
- **Rust is std-only** (no crates: the air-gapped image has no crates.io); compile+test via `rustc --test`.
- **Bounded implementer:** the subagent implements a *tested plan*, does not redesign, and hands back **BLOCKED** rather than churning.
- **Rename touches live files only** — `docs/superpowers/plans/*` and `docs/superpowers/specs/*` are historical records; leave them. No `re-scripting` may remain in live files afterward.

---

### Task 1: Rename the skill + rewrite it + templates + test (suite stays green)

**Files:**
- Rename: `skills/re-scripting/` → `skills/re-coding/`; `script_template.py` → `python_template.py`
- Rewrite: `skills/re-coding/SKILL.md`
- Create: `skills/re-coding/rust_template.rs`
- Rename+rewrite: `tests/scripts/test_script_template.py` → `tests/scripts/test_coding_templates.py`

- [ ] **Step 1: Rename the directory and the Python template (preserve history)**

```sh
git mv skills/re-scripting skills/re-coding
git mv skills/re-coding/script_template.py skills/re-coding/python_template.py
git mv tests/scripts/test_script_template.py tests/scripts/test_coding_templates.py
```

- [ ] **Step 2: Rewrite `skills/re-coding/SKILL.md`** with exactly this content:

````markdown
---
name: re-coding
description: Use when a reverse-engineering task needs custom code beyond a one-liner — a format parser, deobfuscation routine, keygen, or angr/z3 harness. Plans it test-first, delegates implementation to a bounded subagent, then code-reviews it. Keywords: RE code, custom tool, parser, keygen, angr harness, z3, rust, python, shell, automate analysis.
---

# re-coding

Produce **tested, reviewed code** for an RE task — a parser, a deobfuscation routine, a
keygen, an angr/z3 harness. One-liners stay inline; this flow is for non-trivial or
reusable code.

## Workflow (plan → implement → review)

1. **Plan (you).** Pick the language (below) and write a short implementation plan into
   the investigation's `scripts/` that names the **unit tests** up front — the tests gate
   "done". Keep the deterministic logic in a pure function.
2. **Implement (a subagent).** Dispatch an implementer subagent whose **sole job is to make
   the tests pass** — hand it the plan + the tests. It implements and loops until the test
   command is green. It does **not** redesign the plan; after a few failed iterations, or
   on a real design fork, it returns **BLOCKED** with what it tried (a dead end) — it never
   churns invisibly. This is the "implement a tested plan" case in
   `../reverse-engineering/references/delegating-to-subagents.md`.
3. **Review (you).** Code-review the result against the plan — spec compliance + quality.
   Fix-loop via the subagent if needed. Save code + tests under `scripts/`, append a line
   to `scripts/README.md`, and cite it in the plan/findings (per
   `../reverse-engineering/references/evidence-and-findings.md`).

## Pick the language

Decide by **dependency footprint**, not preference:

| Use | When | Test with |
|---|---|---|
| **Python** (default) | touches the RE stack (angr/z3/capstone/unicorn/lief/pefile/miasm/qiling) or quick glue/logic | `pytest` |
| **Shell** | mostly orchestrating CLI tools (file/strings/objdump/yara pipelines) | POSIX-sh assertions |
| **Rust** | self-contained, **no external deps**, medium-to-high complexity pure logic (fast parser, custom-cipher reimpl, brute-forcer) | `rustc --test` |

Most RE code is Python — it leans on the Python tooling. **Rust is the exception** for
self-contained heavy compute. Criterion: *needs the Python RE libs / external tools →
Python/shell; self-contained heavy logic → Rust.*

## Templates & testing stance

- **Python:** copy `python_template.py` — pure `solve(...)` + a module docstring + inline
  `# why` comments for a learner. Test with known input/output vectors.
- **Rust:** copy `rust_template.rs` — a pure function + `#[cfg(test)]` tests, **std-only**
  (no crates: the air-gapped image has no crates.io). Compile + test with
  `rustc --test rust_template.rs -o /tmp/t && /tmp/t`.
- **Pragmatic stance:** unit-test the **deterministic logic** (parsers, transforms,
  crypto/keygen, the decision function) with known vectors. Code inseparable from the
  binary (angr glue, ptrace hooks) is verified by **running it and checking the expected
  artifact** — capture that as the fixture and **document** how it was verified. Don't fake
  unit tests for what can't be unit-tested.

## Air-gapped env

Python tools install **globally** — run/test with `python3` (no venv). **Rust** is
std-only via `rustc` (no `cargo` fetch). Rich Python libs available to scripts:
`capstone`, `keystone`, `unicorn`, `lief`, `pefile`, `pyelftools`, `miasm`, `qiling`,
`yara`, `r2pipe`, `pwntools`, plus `angr`/`z3`.
````

- [ ] **Step 3: Create `skills/re-coding/rust_template.rs`** with exactly this content:

```rust
//! <one line: what this recovers/transforms and for which target>.
//!
//! WHY: explain the RE reasoning for a learner — what you observed in the binary and
//! why this reproduces it. std-only (no crates: the air-gapped image has no crates.io).
//!
//! Build & test:  rustc --test rust_template.rs -o /tmp/t && /tmp/t
//! Build & run:   rustc -O rust_template.rs -o /tmp/solve && /tmp/solve <input>

/// The deterministic core (parser / transform / keygen). Pure + side-effect-free so it
/// can be unit-tested with known input/output vectors. Replace the body.
fn solve(data: &[u8]) -> Vec<u8> {
    // why: placeholder identity transform — replace with the real logic.
    data.to_vec()
}

fn main() {
    let arg = std::env::args().nth(1).unwrap_or_default();
    println!("{}", String::from_utf8_lossy(&solve(arg.as_bytes())));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn known_vector() {
        // Replace with a known input/output vector recovered from the target.
        assert_eq!(solve(b"AB"), b"AB");
    }
}
```

- [ ] **Step 4: Write `tests/scripts/test_coding_templates.py`** with exactly this content:

```python
import py_compile
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

PY = Path("skills/re-coding/python_template.py")
RS = Path("skills/re-coding/rust_template.rs")


def test_python_template_compiles():
    py_compile.compile(str(PY), doraise=True)


def test_python_template_has_help():
    r = subprocess.run([sys.executable, str(PY), "--help"], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    assert "usage" in r.stdout.lower()


def test_rust_template_compiles_and_tests(tmp_path):
    # tool-optional: rustc is baked into the air-gapped image; skip where absent.
    if shutil.which("rustc") is None:
        pytest.skip("rustc not installed")
    binp = tmp_path / "t"
    c = subprocess.run(["rustc", "--test", str(RS), "-o", str(binp)],
                       capture_output=True, text=True)
    assert c.returncode == 0, c.stderr
    r = subprocess.run([str(binp)], capture_output=True, text=True)
    assert r.returncode == 0, r.stdout + r.stderr
    assert "test result: ok" in r.stdout
```

- [ ] **Step 5: Run the templates test + full suite**

```sh
python3 -m pytest tests/scripts/test_coding_templates.py -q 2>&1 | tail -2
for t in tests/scripts/test_*.sh; do sh "$t" >/dev/null 2>&1 || echo "FAILED: $t"; done; echo "sh done"
```
Expected: pytest `… passed` (the Rust test passes if `rustc` is present, else skips); `sh done` with no `FAILED:`.

- [ ] **Step 6: Commit**

```sh
git add -A skills/re-coding tests/scripts/test_coding_templates.py
git commit -m "re-coding: rename re-scripting; plan→implementer→review flow + Rust template"
```

---

### Task 2: Cross-reference rename across live files

**Files:** every live file referencing `re-scripting` (skills, references, playbooks, orchestrator, AGENTS/ARCHITECTURE/INSTALL, the shipped example) — **not** `docs/superpowers/*`.

- [ ] **Step 1: Sed the rename across live areas** (excludes `docs/superpowers/` historical docs)

```sh
grep -rlZ 're-scripting' skills/ tests/scenarios/ docs/reverse/ AGENTS.md ARCHITECTURE.md INSTALL.md 2>/dev/null \
  | xargs -0 sed -i 's/re-scripting/re-coding/g'
```

- [ ] **Step 2: Verify no `re-scripting` remains in live files**

```sh
grep -rn 're-scripting' skills/ tests/ docs/reverse/ AGENTS.md ARCHITECTURE.md INSTALL.md README.md 2>/dev/null \
  && echo "LEFTOVER (fix before commit)" || echo "clean: no re-scripting in live files"
```
Expected: `clean: no re-scripting in live files`. (Historical `docs/superpowers/*` intentionally still say `re-scripting`.)

- [ ] **Step 3: Run full suite + commit**

```sh
for t in tests/scripts/test_*.sh; do sh "$t" >/dev/null 2>&1 || echo "FAILED: $t"; done; echo "sh done"
python3 -m pytest tests/scripts/ -q 2>&1 | tail -1
git add -A skills/ tests/scenarios/ docs/reverse/ AGENTS.md ARCHITECTURE.md INSTALL.md
git commit -m "re: rename re-scripting -> re-coding across live cross-references"
```
Expected: `sh done` no `FAILED:`; pytest `… passed`.

---

### Task 3: Delegation reference — "implement a tested plan" category

**Files:**
- Modify: `skills/reverse-engineering/references/delegating-to-subagents.md`

- [ ] **Step 1: Add the category** — under the `## When to delegate` list, after the
  "Run a tested script" bullet, insert:

```markdown
- **Implement a written plan whose tests define "done"** (the `re-coding` flow) — hand the
  subagent the plan + the unit tests; it implements until the test command is green. This
  is bounded *because the tests are the spec*: the subagent does **not** design or choose
  the approach, and it returns **BLOCKED** (with what it tried) after a few failed
  iterations rather than churning. You wrote the plan/tests; you code-review the result.
```

- [ ] **Step 2: Verify + commit**

```sh
grep -q 'Implement a written plan' skills/reverse-engineering/references/delegating-to-subagents.md || echo MISSING
grep -niE 'claude|anthropic' skills/reverse-engineering/references/delegating-to-subagents.md && echo FAIL || echo OK
git add skills/reverse-engineering/references/delegating-to-subagents.md
git commit -m "delegating-to-subagents: add 'implement a tested plan' category (re-coding)"
```
Expected: no `MISSING`; `OK`.

---

### Task 4: Bake Rust into the image + docs (deploy; rebuild flagged)

**Files:**
- Modify: `deploy/Dockerfile`, `README.md`, `INSTALL.md`

- [ ] **Step 1: Add `rustc` to the runtime apt list** — in `deploy/Dockerfile`, replace:

```dockerfile
      file binutils binwalk gdb ltrace strace xxd yara \
```

with:

```dockerfile
      file binutils binwalk gdb ltrace strace xxd yara rustc \
```

- [ ] **Step 2: Add a `rustc` build-time check** — in the same `RUN`, replace:

```dockerfile
 && test -x /usr/lib/jvm/java-21-openjdk-amd64/bin/java \
```

with:

```dockerfile
 && test -x /usr/lib/jvm/java-21-openjdk-amd64/bin/java \
 && rustc --version \
```

- [ ] **Step 3: Note Rust in README.md and INSTALL.md**

In `README.md`, add a one-liner to the tooling/overview text:
```markdown
- **Rust** (`rustc`, std-only) is baked in for self-contained, dependency-free code (the `re-coding` skill picks it for heavy pure-logic tasks).
```
In `INSTALL.md`, add near the toolchain notes:
```markdown
`rustc` is installed for `re-coding`'s Rust path (std-only; no `cargo`/crates needed on the air-gapped image).
```

- [ ] **Step 4: Verify + commit** (the image is **not** rebuilt here — a Docker host is required)

```sh
grep -q 'rustc' deploy/Dockerfile && grep -q 'rustc --version' deploy/Dockerfile || echo "MISSING dockerfile"
grep -q -i 'rust' README.md INSTALL.md || echo "MISSING docs"
sh tests/scripts/test_deploy_image.sh >/dev/null 2>&1 && echo "deploy lint PASS" || echo "deploy lint FAILED"
git add deploy/Dockerfile README.md INSTALL.md
git commit -m "deploy: bake rustc (std-only) for re-coding's Rust path + note in README/INSTALL"
```
Expected: no `MISSING`; `deploy lint PASS`. ⚠️ Rust inside `vibe-reverse` only works after `sh deploy/build.sh` rebuilds the image.

---

### Task 5: Rename + rewrite the keygen scenario

**Files:**
- Rename: `tests/scenarios/re-scripting-keygen.md` → `tests/scenarios/re-coding-keygen.md`

- [ ] **Step 1: Rename the scenario file**

```sh
git mv tests/scenarios/re-scripting-keygen.md tests/scenarios/re-coding-keygen.md
```

- [ ] **Step 2: Replace `tests/scenarios/re-coding-keygen.md`** with exactly this content:

```markdown
# Scenario: re-coding a keygen (plan → bounded implementer → review)

**Setup:** Static analysis recovered an invertible check (`key[i] = user[i] + 1`). The
agent needs a keygen — non-trivial enough to warrant real, tested code.

**Prompt:** "Write the keygen."

**PASS criteria (GREEN, with re-coding):**
- **Picks the language by the heuristic** — pure self-contained logic, no RE-lib
  dependency → Rust *or* Python is defensible; a quick Python keygen is the expected
  default (Rust only if it argued self-contained/heavy).
- **Plans test-first:** writes the unit tests (known vector, e.g. `"AB" → "BC"`) before
  the implementation.
- **Delegates implementation to a bounded subagent** whose sole job is to make the tests
  pass; the subagent does not redesign and would hand back **BLOCKED** rather than churn.
- **Code-reviews** the result against the plan, then **verifies against the real binary**
  (per re-solve), and saves code + tests under `scripts/`.

**Typical RED:** writes an untested keygen inline, or hands a subagent an open-ended
"figure out the keygen" task with no tests to gate it.
```

- [ ] **Step 3: Verify + full suite + commit**

```sh
grep -niE 'claude|anthropic' tests/scenarios/re-coding-keygen.md && echo FAIL || echo OK
grep -rn 're-scripting' tests/scenarios/ 2>/dev/null && echo "LEFTOVER" || echo "scenarios clean"
for t in tests/scripts/test_*.sh; do sh "$t" >/dev/null 2>&1 || echo "FAILED: $t"; done; echo "sh done"
python3 -m pytest tests/scripts/ -q 2>&1 | tail -1
git add -A tests/scenarios/
git commit -m "tests: rename+rewrite keygen scenario for the re-coding flow"
```
Expected: `OK`; `scenarios clean`; `sh done` no `FAILED:`; pytest `… passed`.

---

## Self-Review

**Spec coverage** (against `2026-06-23-re-coding-sp5-design.md`):
- §2 plan→implementer→review flow + bounded/hand-back → Task 1 (SKILL) + Task 3 (delegation category) ✓
- §3 language heuristic → Task 1 (SKILL table) ✓
- §4 Rust std-only `rustc --test` + Docker bake → Task 1 (rust_template) + Task 4 ✓
- §5 rename live-only, historical untouched → Task 1 (dir) + Task 2 (sed + grep) ✓
- §6 templates (python rename + rust new) → Task 1 ✓
- §7/§8 tests (python + tool-optional rust; scenario) → Task 1 (test) + Task 5 ✓
- §10 acceptance 1–7 → all mapped ✓

**Placeholder scan:** `<one line>`/`<input>`/`<these>` are template tokens; every step has
complete content + exact commands. No TBD/TODO. ✓

**Name consistency:** `python_template.py` / `rust_template.rs` / `test_coding_templates.py`
match across Tasks 1, 4, 5; the test asserts the exact `rustc --test` invocation and the
"test result: ok" string Rust prints; the SKILL, delegation category, and scenario all use
"implement a tested plan" / BLOCKED consistently. ✓

**Scope guard:** only the renamed skill, the delegation reference, the deploy Rust bake,
the live cross-refs, and the templates/tests/scenario are touched; `docs/superpowers/*`
historical docs are left as-is. ✓
