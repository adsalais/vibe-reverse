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
