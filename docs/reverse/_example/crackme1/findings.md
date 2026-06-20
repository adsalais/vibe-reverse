# Findings — crackme1

- ELF 64-bit PIE x86-64; not packed (entropy 1.79); PIE/NX/RELRO/canary.
- Check: `want[i] = username[i] + 1`; then `strcmp(want, key)`.
- Key formula: `key[i] = username[i] + 1`. Example: "AB" → "BC".
- Verified against the binary: `Correct!` — **solved**.
