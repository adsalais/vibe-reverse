# RE Harness v1 — Plan 4: Reporting + example — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `re-report` — the terminal phase that synthesizes the whole investigation into `REPORT.md`, **written even on complete failure** — and ship a worked example investigation. This completes v1.

**Architecture:** `re-report` is a light discipline skill plus `make_report.sh`, which scaffolds `REPORT.md` from `report-template.md` and auto-indexes the investigation's plans/artifacts/scripts; the agent then fills in the prose by reading the folder. A committed example investigation (`docs/reverse/_example/`) demonstrates the full output.

**Tech Stack:** POSIX `sh`, markdown. (No new external tools.)
**Depends on:** Plans 1–3 (9 skills), on `main`.
**Completes:** v1 (10 skills). After this, only the deferred subagent scenario suite remains optional.

**Authoring convention:** `make_report.sh` + its test are full code; `SKILL.md` gets verbatim frontmatter + a contract + a committed scenario (subagent RED/GREEN deferred per project choice); the example investigation is authored prose following the templates.

---

## File Structure (created by this plan)

| Path | Responsibility |
|---|---|
| `skills/re-report/report-template.md` | The `REPORT.md` skeleton. |
| `skills/re-report/make_report.sh` | Scaffold `REPORT.md` from the template + auto-index plans/artifacts/scripts. |
| `skills/re-report/SKILL.md` | Terminal synthesis + "write it even on failure" discipline. |
| `tests/scripts/test_report.sh` | Behavioral test for `make_report.sh`. |
| `tests/scenarios/re-report-failure.md` | RED/GREEN scenario (failed investigation still gets a report). |
| `docs/reverse/_example/...` | A complete worked example (crackme1, solved). |

---

## Task 1: `re-report` skill + `make_report.sh`

**Files:**
- Create: `tests/scripts/test_report.sh`, `skills/re-report/report-template.md`,
  `skills/re-report/make_report.sh`, `skills/re-report/SKILL.md`,
  `tests/scenarios/re-report-failure.md`

- [ ] **Step 1: Write the failing test `tests/scripts/test_report.sh`**

```sh
#!/usr/bin/env sh
set -eu
SCRIPT="skills/re-report/make_report.sh"
ROOT="$(mktemp -d)"; trap 'rm -rf "$ROOT"' EXIT
DIR="$ROOT/inv"; mkdir -p "$DIR/artifacts" "$DIR/scripts"
printf '# 01 triage plan\n' > "$DIR/01-triage-plan.md"
printf 'objdump output\n'   > "$DIR/artifacts/objdump.txt"
printf 'print("k")\n'       > "$DIR/scripts/solve.py"
fail() { echo "FAIL: $1" >&2; exit 1; }

OUT=$(sh "$SCRIPT" "$DIR") || fail "make_report.sh nonzero"
R="$DIR/REPORT.md"
[ -f "$R" ] || fail "REPORT.md not created"
for s in "Outcome" "Approaches tried" "Dead ends" "Reproduction" "Index"; do
  grep -q "$s" "$R" || fail "missing section: $s"
done
grep -q "01-triage-plan.md" "$R"     || fail "plan not indexed"
grep -q "artifacts/objdump.txt" "$R" || fail "artifact not indexed"
grep -q "scripts/solve.py" "$R"      || fail "script not indexed"

echo "PASS: test_report.sh"
```

- [ ] **Step 2: Run it — verify it FAILS** (`make_report.sh` missing).

- [ ] **Step 3: Write `skills/re-report/report-template.md`**

```markdown
# REPORT — <investigation>

- **Target & scope:** <file, sha256, authorization>
- **Goal:** <what we set out to do>
- **Outcome:** solved / partial / failed — <one line>

## Approaches tried
For each phase: what was attempted, **what worked, what failed, and why**
(hypotheses where unproven).

## Key findings
<the technical understanding gained, in plain language>

## Dead ends & ideas for next time
<emphasize on failure — these seed the next attempt>

## Reproduction
<exact steps / scripts to reproduce the result, if solved>
```

- [ ] **Step 4: Write `skills/re-report/make_report.sh`**

```sh
#!/usr/bin/env sh
# make_report.sh — scaffold REPORT.md from the template and auto-index the
# investigation's plans, artifacts, and scripts. Fill in the prose afterward.
# Usage: make_report.sh <investigation-dir>
set -eu
DIR="${1:?usage: make_report.sh <investigation-dir>}"
[ -d "$DIR" ] || { echo "no such dir: $DIR" >&2; exit 1; }
TPL="$(dirname "$0")/report-template.md"
REPORT="$DIR/REPORT.md"

cp "$TPL" "$REPORT"

{
  echo
  echo "## Index (auto-generated)"
  echo
  echo "### Plans"
  found=0; for f in "$DIR"/[0-9]*-plan.md; do [ -e "$f" ] || continue; echo "- $(basename "$f")"; found=1; done; [ "$found" = 0 ] && echo "- (none)"
  echo
  echo "### Artifacts"
  found=0; for f in "$DIR"/artifacts/*; do [ -e "$f" ] || continue; echo "- artifacts/$(basename "$f")"; found=1; done; [ "$found" = 0 ] && echo "- (none)"
  echo
  echo "### Scripts"
  found=0; for f in "$DIR"/scripts/*; do [ -e "$f" ] || continue; echo "- scripts/$(basename "$f")"; found=1; done; [ "$found" = 0 ] && echo "- (none)"
} >> "$REPORT"

echo "wrote: $REPORT"
```

- [ ] **Step 5: Run the test — verify it PASSES.** Eyeball a real run: scaffold a temp investigation, run `make_report.sh`, `cat REPORT.md`.

- [ ] **Step 6: Write scenario `tests/scenarios/re-report-failure.md`**

```markdown
# Scenario: report a FAILED investigation (discipline)

**Setup:** After several phases the target was NOT cracked (dead end). The user
says: "we failed, no point writing it up — let's move on."

**PASS criteria (GREEN, with re-report):**
- Still writes REPORT.md (runs make_report.sh, fills the prose).
- Records outcome = failed, the approaches tried and WHY each failed, and
  concrete ideas for next time.
- Does NOT skip the report.

**Typical RED (baseline, no skill):** agrees there's "nothing to report" and skips
it, losing the dead-end knowledge.
```

- [ ] **Step 7: Author `skills/re-report/SKILL.md`** (DISCIPLINE contract)

Frontmatter (verbatim):

```yaml
---
name: re-report
description: Use at the end of a reverse-engineering investigation — solved or not — to synthesize a final REPORT.md of what was tried, what worked, what failed, and ideas for next time. Symptoms you are about to violate it: "we failed, nothing to write", "skip the writeup". Keywords: report, writeup, summary, debrief, findings, conclusion, post-mortem.
---
```

Required contents (the body MUST):
1. **CORE:** synthesize `REPORT.md` at the end — **mandatory even on complete failure.** A documented dead end seeds the next attempt. The rationalization "we didn't solve it, so there's nothing to write" is forbidden.
2. Command: `sh make_report.sh <investigation-dir>` scaffolds `REPORT.md` (template + auto-index); then **fill in the prose** by reading `00-target.md`, the `NN-*-plan.md` files, `findings.md`, and `artifacts/`.
3. Cover: target & scope, outcome, **approaches tried (what worked / failed / why)**, key findings (plain language), dead ends & ideas, reproduction steps.
4. Self-review the report (consistency / relevancy / evidence) per `re-planning`; as the terminal deliverable, **escalate to the independent reviewer by default** (use `re-planning`'s `reviewer-prompt.md`).
5. Relative paths only.

- [ ] **Step 8: Commit**

```sh
git add skills/re-report tests/scripts/test_report.sh tests/scenarios/re-report-failure.md
git commit -m "Plan4 T1: re-report skill + make_report.sh (writeup, even on failure)"
```

---

## Task 2: Worked example investigation

**Files:**
- Create under `docs/reverse/_example/` (this path is the one un-ignored dir in `.gitignore`):
  `00-target.md`, `01-triage-plan.md`, `02-static-plan.md`, `03-solve-plan.md`,
  `findings.md`, `scripts/solve_crackme1.py`, `scripts/test_solve_crackme1.py`,
  `scripts/README.md`, `artifacts/triage.txt`, `REPORT.md`

- [ ] **Step 1: Generate the real triage artifact**

```sh
sh tests/fixtures/build.sh
mkdir -p docs/reverse/_example/artifacts docs/reverse/_example/scripts
sh skills/re-triage/triage.sh tests/fixtures/crackme1 docs/reverse/_example >/dev/null
# (this writes docs/reverse/_example/artifacts/triage.txt)
```

- [ ] **Step 2: Write `00-target.md`** — crackme1, sha256 (from triage), authorization = "in-house CTF fixture (authorized)", goal = "find a key the binary accepts".

- [ ] **Step 3: Write the three plans** following the `re-planning` template:
  - `01-triage-plan.md` — found: ELF PIE x86-64, low entropy (not packed), strings show `strcmp`/usage; assessment: native, not packed; next: re-static.
  - `02-static-plan.md` — found: `main` builds `want[i] = argv[1][i] + 1`, then `strcmp(want, argv[2])`; assessment: not packed, **solver-friendly (direct inversion)**; next: re-solve.
  - `03-solve-plan.md` — solved: key = each username byte + 1; verified `crackme1 AB BC` → `Correct!`; next: re-report.

- [ ] **Step 4: Write `scripts/solve_crackme1.py` + `scripts/test_solve_crackme1.py` + `scripts/README.md`**

`solve_crackme1.py` (documented, pure function):
```python
#!/usr/bin/env python3
"""Keygen for crackme1 — recover a valid key for a username.

WHY: static analysis (02-static-plan) showed the binary computes
want[i] = username[i] + 1 and compares it to the key, so the key is just each
username byte incremented by one.
"""
import sys


def keygen(username: str) -> str:
    # why: invert the check want[i] == username[i] + 1
    return "".join(chr((ord(c) + 1) % 256) for c in username)


if __name__ == "__main__":
    print(keygen(sys.argv[1] if len(sys.argv) > 1 else "AB"))
```

`test_solve_crackme1.py`:
```python
from solve_crackme1 import keygen

def test_known_vector():
    assert keygen("AB") == "BC"  # 'A'+1='B', 'B'+1='C'
```

`scripts/README.md`: one line — "solve_crackme1.py: keygen (key = username byte + 1); verified against the binary."

- [ ] **Step 5: Write `findings.md`** — cumulative: format, the check logic, the key formula, "solved".

- [ ] **Step 6: Generate `REPORT.md` and fill it in**

```sh
sh skills/re-report/make_report.sh docs/reverse/_example >/dev/null
```
Then edit `docs/reverse/_example/REPORT.md`: outcome = solved; approaches (triage → static → solve, what worked); key finding (the +1 formula); dead ends = none (note alternative angr/z3 route); reproduction = `python3 scripts/solve_crackme1.py <user>` then run the binary.

- [ ] **Step 7: Verify the example's own script test passes**

```sh
( cd docs/reverse/_example/scripts && python3 -m pytest test_solve_crackme1.py -q )
```
Expected: 1 passed.

- [ ] **Step 8: Commit**

```sh
git add docs/reverse/_example
git commit -m "Plan4 T2: worked example investigation (crackme1, solved, with REPORT.md)"
```

---

## Task 3: Finalize v1 — wire orchestrator + docs + merge

**Files:**
- Modify: `skills/reverse-engineering/SKILL.md`, `ARCHITECTURE.md`, `README.md`

- [ ] **Step 1: Update the orchestrator note** — change the closing line to:
"All v1 phase skills are built (triage → static → deobfuscate / solve / dynamic →
report). See `docs/reverse/_example/` for a worked investigation."

- [ ] **Step 2: Run the full deterministic suite**

```sh
for t in tests/scripts/*.sh; do sh "$t" || exit 1; done
python3 -m pytest tests/scripts/ -q
( cd docs/reverse/_example/scripts && python3 -m pytest -q )
```
Expected: all PASS.

- [ ] **Step 3: Update `ARCHITECTURE.md`** — mark `re-report` ✅ built; mark Plan 4 ✅; note v1 complete.

- [ ] **Step 4: Update `README.md` status** — "v1 complete: full native/CTF vertical (10 skills). Firmware / managed / wasm packs are the roadmap."

- [ ] **Step 5: Commit**

```sh
git add skills/reverse-engineering/SKILL.md ARCHITECTURE.md README.md
git commit -m "Plan4 T3: finalize v1 — orchestrator + docs; 10 skills complete"
```

---

## Self-Review (author's check against the spec)

- **Spec coverage (Plan 4 slice):** `re-report` §4d/§10 ✓ (T1, terminal synthesis + "even on failure" discipline + reviewer escalation); `report-template.md` ✓; example investigation §13 ✓ (T2, includes a sample `REPORT.md`). v1 now covers §4 in full.
- **Placeholders:** none — `make_report.sh` + test are complete; the example is concrete (real triage artifact + a tested keygen + filled REPORT.md); `SKILL.md` has verbatim frontmatter + contract + committed scenario.
- **Type/name consistency:** skill name `re-report` == dir; `make_report.sh` writes `REPORT.md` with sections the test asserts and an auto-index the test checks; example reuses the `re-planning` plan template and `report-template.md`; `keygen()` is imported by name in the example's test.
- **Completes v1:** 10 skills; orchestrator/ARCHITECTURE/README updated; example demonstrates the end-to-end loop.
