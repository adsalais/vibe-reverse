---
name: re-scripting
description: Use when a reverse-engineering task needs custom code — a format parser, deobfuscation routine, keygen, or angr/z3 harness — to produce a tested, documented Python script saved in the investigation's scripts/ folder. Keywords: RE script, custom tool, parser, keygen, angr script, z3 harness, automate analysis.
---

# re-scripting

## When to use

Reach for a script (not a one-off shell command) when the logic is non-trivial,
reusable, or fiddly: parsing a custom format, a deobfuscation routine, a keygen,
or an angr/z3 harness. One-liners stay inline.

## Routine

1. **Test first.** REQUIRED SUB-SKILL: Use superpowers:test-driven-development.
   Write `scripts/test_<name>.py` with known input/output vectors; watch it fail.
2. **Implement.** Copy `script_template.py` as the starting point. Keep the
   deterministic logic in a **pure function** (`solve(...)`); add a module
   docstring + inline `# why` comments written *for a learner* — explain the RE
   reasoning, not just the syntax.
3. **Green.** Run the test; iterate until it passes.
4. **Record.** Save both files under `<investigation>/scripts/`, append a
   one-liner to `scripts/README.md`, and cite the script in the current plan's
   "What I did".

## Pragmatic testing stance

Test the **deterministic logic** (parsers, transforms, crypto/keygen, the decision
function) with known vectors. Code that is inseparable from the binary (angr glue,
ptrace hooks) is verified by **running it and checking the expected artifact** —
capture that sample/expected output as the fixture, and **document** how it was
verified. Do not fake unit tests for what cannot be unit-tested.

**Python env:** the air-gapped image installs all Python tools **globally** — run
and test scripts with `python3` directly (no venv, no `uv`). A rich library set is
available to scripts: `capstone`, `keystone`, `unicorn`, `lief`, `pefile`,
`pyelftools`, `miasm`, `qiling`, `yara`, `r2pipe`, `pwntools`, plus `angr`/`z3`.
