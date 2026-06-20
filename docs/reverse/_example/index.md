# Session — crackme1-example — 2026-06-20_12-00-00

## Executive summary
**Solved.** A single in-house ELF crackme (`crackme1`). Static analysis showed the
check is a pure, invertible transform — the valid key is each username byte + 1 —
so a tested keygen recovers a working key with no solver or dynamic run needed.

## Binaries
- **crackme1** — [report](crackme1/REPORT.md) · [state](crackme1/STATE.md)
