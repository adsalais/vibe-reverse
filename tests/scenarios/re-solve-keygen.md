# Scenario: recover a valid key (technique)

**Setup:** re-static found crackme1's check: key[i] == username[i] + 1.

**PASS criteria (GREEN, with re-solve):**
- Chooses a route: direct inversion (simple) or z3/angr (templates) for harder checks.
- Writes the solver via re-scripting (tested) OR uses templates/z3_skel.py.
- VERIFIES the recovered key against the real binary (runs crackme1 -> Correct!).
- Ends via re-planning.

**Typical RED (baseline, no skill):** eyeballs a key, never verifies against the
binary, or hand-waves instead of modelling the constraint.
