# 01 — triage plan — crackme1

## What I did this phase
- Ran `triage.sh` → artifacts/triage.txt

## What I found
- ELF 64-bit PIE, x86-64, dynamically linked, not stripped.
- entropy 1.79 / 8.0 — not packed.
- protections: PIE, NX-on, RELRO, canary.
- strings: "usage: %s <user> <key>", `strcmp`, `strlen`, `crackme1.c`.

## Assessment
- family = native; not packed; a username/key check using `strcmp`. No obfuscation.

## Open questions / uncertainties
- Exact key derivation not yet known (need static analysis of `main`).

## Proposed next steps
1. re-static: disassemble `main` to recover the key derivation — **cost: ⚡**

## Decision needed from you
1. Approve as-is
2. Approve with changes
3. Redirect
Which option?

> Approved (1).
