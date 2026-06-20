# 02 — static analysis plan — crackme1

## What I did this phase
- Ran `ghidra_decompile.sh` (objdump fallback) → artifacts/objdump.txt; read `main`.

## What I found
- `main` builds `want[i] = argv[1][i] + 1` for each byte of the username, then
  compares `strcmp(want, argv[2])`.
- Plain language: the valid key is each username character shifted up by one.

## Assessment
- Not packed; no obfuscation. The check is a pure, invertible transform →
  solver-friendly by **direct inversion** (no z3/angr needed).

## Open questions / uncertainties
- None material.

## Proposed next steps
1. re-solve: implement keygen (`key[i] = user[i] + 1`), verify against the binary — **cost: ⚡**

## Decision needed from you
1. Approve as-is
2. Approve with changes
3. Redirect
Which option?

> Approved (1).
