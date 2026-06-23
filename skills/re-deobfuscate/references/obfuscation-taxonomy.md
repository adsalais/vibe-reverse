# Obfuscation taxonomy → handler / route

Peel OUTERMOST first. After each peel, re-run triage + static; repeat until clean.

| Technique | Signs | Handler / route |
|---|---|---|
| Packing | high entropy, packer sig (UPX!), tiny code + big high-entropy section | `unpack.sh` (UPX); else run-to-unpack / qiling emulate (`re-dynamic`) + lief rebuild |
| String obfuscation | few readable strings + a decode routine called everywhere | FLOSS first; then a tested decoder via `re-coding` |
| Stack-strings | strings built byte-by-byte on the stack | FLOSS / scripted reconstruction |
| API hashing | imports resolved from hashes at runtime | resolve the hash table (capa hints + `re-coding`) |
| Control-flow flattening | one dispatcher switch, many same-size blocks, a state var | de-flatten via miasm/angr symbolic recovery (`re-coding`) |
| Opaque / bogus predicates | always-true/false branches, dead code | prove constant with z3, patch out (keystone/lief), reanalyze |
| Virtualization | fetch-decode-execute loop, virtual PC, handler table | → `re-devirtualize` |
| Encrypted layers | a crypto routine gates the next stage | → `re-crypto`, then re-assess the plaintext |
| Interleaved anti-analysis | anti-debug/anti-disasm mixed into the above | → `re-antianalysis` |

Stacking is the norm in advanced malware: expect 2–4 of these at once.
