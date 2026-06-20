# REPORT — crackme1

- **Target & scope:** tests/fixtures/crackme1 (sha256 4d140842…), in-house CTF fixture (authorized).
- **Goal:** find a key the binary accepts for a given username.
- **Outcome:** solved — `key[i] = username[i] + 1`.

## Approaches tried
- **Triage** (re-triage): ELF PIE x86-64, entropy 1.79 (not packed),
  PIE/NX/RELRO/canary; strings revealed a `<user> <key>` usage + `strcmp`.
  *Worked:* identified a simple, unobfuscated check. *Failed:* nothing.
- **Static** (re-static, objdump fallback): `main` builds `want[i]=user[i]+1`
  then `strcmp(want, key)`. *Worked:* recovered the exact derivation. (Ghidra would
  give decompiled C, but the disassembly was enough here.)
- **Solve** (re-solve, direct inversion): keygen `key[i]=user[i]+1`; verified
  `crackme1 AB BC` → `Correct!`. *Worked.*

## Key findings
The "license check" is a one-byte Caesar shift: the valid key is each username
character plus one. No packing or obfuscation; protections are present but
irrelevant to a pure keygen.

## Dead ends & ideas for next time
- None hit. For a harder variant where the transform isn't invertible, model the
  constraint with `templates/z3_skel.py` (z3) instead of direct inversion.

## Reproduction
    python3 docs/reverse/_example/scripts/solve_crackme1.py AB   # -> BC
    tests/fixtures/crackme1 AB BC                                 # -> Correct!

## Index (auto-generated)

### Plans
- 01-triage-plan.md
- 02-static-plan.md
- 03-solve-plan.md

### Artifacts
- artifacts/objdump.txt
- artifacts/triage.txt

### Scripts
- scripts/README.md
- scripts/solve_crackme1.py
- scripts/test_solve_crackme1.py
