# 03 — solve plan — crackme1

## What I did this phase
- Wrote scripts/solve_crackme1.py (tested) implementing `key[i] = user[i] + 1`.
- Verified: `crackme1 AB BC` → "Correct!" (exit 0).

## What I found
- Keygen works for arbitrary usernames; the binary accepts the recovered key.

## Assessment
- **SOLVED.** (A z3 model via `templates/z3_skel.py` would reach the same result
  for a harder, non-invertible variant.)

## Open questions / uncertainties
- None.

## Proposed next steps
1. re-report: write REPORT.md — **cost: ⚡**

## Decision needed from you
1. Approve as-is
2. Approve with changes
3. Redirect
Which option?

> Approved (1).
