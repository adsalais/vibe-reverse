# REPORT — crackme1 (vibe-reverse-2026-06-20_12-00-00)

> Audience: an expert reverse engineer. Put the most important things first.

## Executive summary
- **Outcome / verdict:** solved — the key for any username is recoverable in O(n).
- **What it is:** ELF 64-bit PIE x86-64 CTF crackme; a `<user> <key>` check, not packed.
- **Top findings (3–5):**
  1. **[confirmed]** The check is `want[i] = username[i] + 1` then `strcmp(want, key)` —
     a pure, invertible byte transform.
  2. **[confirmed]** No packing/obfuscation (entropy 1.79); standard hardening (PIE/NX/RELRO/canary).
  3. **[confirmed]** Keygen `key[i] = username[i] + 1` is verified against the binary.
- **Headline IOCs:** none (benign in-house fixture).

## Key findings
`main` reads `argv[1]` (user) and `argv[2]` (key). It computes a `want` buffer where
each byte is the corresponding username byte plus one, then accepts iff
`strcmp(want, key) == 0`. There is no hashing, encryption, or hidden state.

## Approaches tried
- **Triage** (`triage.sh`): identified native ELF, not packed, with a `strcmp`-based
  check — worked, routed to static.
- **Static** (`ghidra_decompile.sh`, objdump fallback): recovered the `+1` transform —
  worked; concluded direct inversion beats a solver here.
- **Solve** (`re-scripting`): a 1-line pure keygen, unit-tested (`"AB"→"BC"`) and
  verified against the real binary (`crackme1 AB BC` → `Correct!`).

## Obfuscation & anti-analysis
None present.

## Crypto & config
None — the transform is a plain `+1`, not cryptography.

## IOCs
None (benign fixture). No C2 / mutex / persistence.

### YARA
```
(not applicable — benign in-house fixture; no detection rule warranted)
```

## Dead ends & ideas for next time
- None needed. For a non-invertible variant (e.g. a hash compare), `templates/z3_skel.py`
  or `templates/angr_skel.py` would recover the key instead of direct inversion.

## Reproduction
```sh
python3 scripts/solve_crackme1.py MyName        # prints the key
./crackme1 MyName "$(python3 scripts/solve_crackme1.py MyName)"   # -> Correct!
```

## Index
- Plans: 01-triage-plan.md, 02-static-plan.md, 03-solve-plan.md
- Artifacts: artifacts/triage.txt
- Scripts: scripts/solve_crackme1.py, scripts/test_solve_crackme1.py, scripts/README.md
