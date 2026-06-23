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
