# RE harness overhaul — SP5: `re-coding` (reworked `re-scripting`)

> **Status:** design approved (brainstorming), ready for implementation plan.
> **Scope:** sub-project **SP5** — rework the spine code-writing skill.
> **Depends on:** SP1 (evidence), SP4 (delegation boundary in `delegating-to-subagents.md`).
> **Audience:** an engineer/agent implementing the change to the `skills/` tree.

## 1. Why

`re-scripting` is the weakest spine skill: "write a small script test-first" undersells
what RE code work needs. SP5 turns it into **`re-coding`** — a one-artifact instance of
`subagent-driven-development`: the pilot writes a tested plan, a bounded implementer
subagent makes the tests pass, and the pilot code-reviews the result. It also gives the
skill a **language heuristic** (Python / shell / Rust) and real **Rust** support for
self-contained heavy-logic tasks.

## 2. The workflow (simplified subagent-driven-development, one artifact)

1. **Pilot — decide the language** (§3) and **write a short implementation plan with the
   unit tests specified.** Tests gate "done". (Keeps the existing rule: one-liners stay
   inline; this flow is for non-trivial/reusable code.)
2. **Implementer subagent — sole job: make the tests pass.** It receives the plan + the
   tests and implements until the test command is green. **Bounded:** it does **not**
   redesign the plan; after a small cap of failed iterations, or on a real design fork,
   it returns **BLOCKED** with what it tried (a dead end) rather than churning.
3. **Pilot — code-review** the result against the plan (spec compliance + quality); run a
   fix loop if needed. Save the tested artifact under the investigation's `scripts/`,
   append to `scripts/README.md`, and cite it in the plan/findings (per SP1).

This delegates *implementation* but keeps *design + review* piloted — the bound is the
tests, and the hand-back-on-BLOCKED prevents invisible churn (the constraint set in SP1).

### Delegation-boundary update (required)
`skills/reverse-engineering/references/delegating-to-subagents.md` gains a new
delegatable category: **"implement a written plan whose tests define done"** — distinct
from "figure out the approach" (which stays piloted). The implementer implements, does
not design, and hands back BLOCKED rather than looping forever.

## 3. Language selection

Decide by **dependency footprint**, not preference:

| Use… | When |
|---|---|
| **Python** (default) | the task touches the RE stack (angr/z3/capstone/unicorn/lief/pefile/miasm/qiling) or is quick glue/logic. Tested with `pytest`. |
| **Shell** | the task is mostly orchestrating CLI tools (file/strings/objdump/yara pipelines). Tested with the POSIX-sh assertion pattern. |
| **Rust** | the task is **self-contained, no external deps, medium-to-high complexity** pure logic (a fast parser, a custom-cipher reimplementation, a brute-forcer). |

**Honesty note in the skill:** most RE code stays Python because it leans on the Python
tooling; **Rust is the exception** for self-contained heavy compute. The criterion is
simply *"does it need the Python RE libs / external tools?" → Python/shell; "self-contained
heavy logic?" → Rust.*

## 4. Rust on the air-gapped image

- **std-only.** No crates.io is reachable, so Rust code uses the standard library only —
  no `cargo` dependency fetch. This matches the "self-contained, no dependencies" rule.
- **Compile + test with `rustc`.** Unit tests are `#[test]` functions run via
  `rustc --test <file>.rs -o <bin> && ./<bin>` (no `cargo` network). The deterministic
  logic lives in a pure function; the same pragmatic testing stance as Python applies.
- **Deploy:** bake a stable `rustc` toolchain into `deploy/Dockerfile`; note Rust in
  `README.md` + `INSTALL.md`. ⚠️ Requires an image rebuild to take effect (like the SP2
  `markdown` bake). The build's existing import/smoke gate should grow a `rustc --version`
  check.

## 5. Rename `re-scripting` → `re-coding`

The skill's scope now spans compiled code, so the name changes.
- **Rename the directory** `skills/re-scripting/` → `skills/re-coding/`; set `name: re-coding`
  in the frontmatter; rewrite the SKILL body (§2–4).
- **Update live cross-references only** — every `re-scripting` mention in the live skills,
  their references/playbooks, the orchestrator, `AGENTS.md`, `ARCHITECTURE.md`,
  `INSTALL.md`, the shipped example (`docs/reverse/_example/crackme1/REPORT.md`), the
  scenarios, and the tests → `re-coding`.
- **Leave historical docs untouched** — `docs/superpowers/plans/*` and
  `docs/superpowers/specs/*` (including the earlier SPx docs) are point-in-time records of
  what the skill was called when they were written; rewriting them would falsify the
  record. (This SP5 spec is the one that introduces the new name.)
- A verification grep confirms **no `re-scripting` remains in live (non-historical) files**.

## 6. Templates
- Rename `script_template.py` → `python_template.py` (pure `solve()` + `#[test]`-style
  pytest-ready structure + `--help`, as today).
- NEW `rust_template.rs` — std-only, a pure function + `#[cfg(test)]` unit tests + a
  minimal `main` that reads args; compiled/tested via `rustc --test`.
- Shell needs no template (the POSIX-sh helper-script conventions already cover it); the
  skill points at the existing `*.sh` helpers as the pattern.

## 7. Files
- RENAME `skills/re-scripting/` → `skills/re-coding/` (dir + `SKILL.md` rewrite +
  `python_template.py`) + NEW `skills/re-coding/rust_template.rs`
- MODIFY `skills/reverse-engineering/references/delegating-to-subagents.md` (new category)
- MODIFY every live file referencing `re-scripting` (skills, references, playbooks,
  orchestrator, AGENTS/ARCHITECTURE/INSTALL/README, example REPORT, scenarios)
- MODIFY `deploy/Dockerfile` (bake `rustc`) + `README.md`/`INSTALL.md` (Rust note)
- RENAME `tests/scenarios/re-scripting-keygen.md` → `re-coding-keygen.md` (update to the new flow)
- RENAME `tests/scripts/test_script_template.py` → `test_coding_templates.py` (python +
  Rust template checks; Rust check **tool-optional** — skips if `rustc` absent)

## 8. Tests
- **Deterministic (pytest):** `test_coding_templates.py` — `python_template.py` compiles
  and `--help` exits 0 (as today); `rust_template.rs` compiles+tests via `rustc --test`
  **iff `rustc` is on PATH**, else `pytest.skip` (tool-optional, per the repo rule).
- **Scenario:** `re-coding-keygen.md` (renamed) — GREEN follows the flow: pilot writes
  plan+tests, a bounded implementer makes them pass (hands back BLOCKED rather than
  churning), pilot reviews; and picks the language by the heuristic. RED writes untested
  code inline or lets a subagent churn open-endedly.
- Full suite (sh + pytest) still exits 0; the rename leaves no dangling `re-scripting`
  reference in live files.

## 9. Out of scope
- No change to the other phases' analysis logic, the gate (SP4), the report (SP2), or the
  evidence contract (SP1) beyond the rename + the new delegation category.
- Vendored-cargo / external Rust crates (std-only only).

## 10. Acceptance criteria
1. `skills/re-coding/SKILL.md` describes the plan→implementer-subagent→code-review flow,
   the bounded/hand-back implementer, the language heuristic, and the Rust std-only +
   air-gap notes; one-liners-stay-inline threshold retained.
2. `delegating-to-subagents.md` carries the "implement a tested plan" category.
3. `python_template.py` + `rust_template.rs` exist; `rust_template.rs` is std-only and
   tested via `rustc --test`.
4. `deploy/Dockerfile` bakes `rustc`; README/INSTALL note Rust (rebuild flagged).
5. No `re-scripting` reference remains in live files; historical docs untouched.
6. `test_coding_templates.py` passes (Rust check skips without `rustc`); the
   `re-coding-keygen` scenario describes the GREEN flow; full suite exits 0.
7. No "claude"/"anthropic" in content; relative paths only; `re-coding/SKILL.md` < 500 lines.

## 11. Open questions
None — resolved in brainstorming: **rename to `re-coding`** (live files only, historical
docs untouched); the **bounded implementer** (tests gate + hand-back-on-BLOCKED, never
redesign) satisfies the no-churn constraint; **Rust is std-only `rustc --test`**, baked
into the image.
