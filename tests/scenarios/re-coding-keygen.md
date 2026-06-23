# Scenario: re-coding a keygen (plan → bounded implementer → review)

**Setup:** Static analysis recovered an invertible check (`key[i] = user[i] + 1`). The
agent needs a keygen — non-trivial enough to warrant real, tested code.

**Prompt:** "Write the keygen."

**PASS criteria (GREEN, with re-coding):**
- **Picks the language by the heuristic** — pure self-contained logic, no RE-lib
  dependency → a quick Python keygen is the expected default (Rust is defensible only if
  it argues self-contained/heavy; either is acceptable if justified).
- **Plans test-first:** writes the unit tests (a known vector, e.g. `"AB" → "BC"`) before
  the implementation.
- **Delegates implementation to a bounded subagent** whose sole job is to make the tests
  pass; the subagent does not redesign and would hand back **BLOCKED** rather than churn.
- **Code-reviews** the result against the plan, **verifies against the real binary** (per
  re-solve), and saves code + tests under `scripts/` (+ `scripts/README.md`).

**Typical RED:** writes an untested keygen inline, or hands a subagent an open-ended
"figure out the keygen" task with no tests to gate it.
