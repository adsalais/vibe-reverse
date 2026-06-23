# Findings — crackme1

## Findings
- **[confirmed]** ELF 64-bit PIE x86-64; not packed (entropy 1.79); PIE/NX/RELRO/canary.
  evidence: `artifacts/triage.txt` · verified: cross-checked `file` + `checksec` output
- **[confirmed]** Check computes `want[i] = username[i] + 1`, then `strcmp(want, key)`.
  evidence: `artifacts/triage.txt` (decompiled `main`) · verified: re-ran `./crackme1 AB BC` → `Correct!`
- **[confirmed]** Keygen `key[i] = username[i] + 1`. Example: "AB" → "BC".
  evidence: `scripts/solve_crackme1.py` + test `scripts/test_solve_crackme1.py` · verified: accepted by the binary

## Dead ends
- (none — direct inversion solved it on the first route)
