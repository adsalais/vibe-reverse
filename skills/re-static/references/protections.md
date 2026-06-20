# Binary protections & obfuscation (quick reference)

**Protections (seen in triage):**
- **PIE** — position-independent; addresses are randomized (ASLR).
- **NX** — non-executable stack/heap; blocks classic shellcode.
- **RELRO** — read-only GOT (partial/full) hardens against GOT overwrite.
- **Canary** (`__stack_chk_fail`) — detects stack-buffer overflows.

**Obfuscation signs (route to re-deobfuscate):**
- High entropy (>7.0) or a packer signature (`UPX!`) → packed; unpack first.
- Tiny code + one big high-entropy section → packed/encrypted payload.
- Opaque predicates, control-flow flattening, huge basic-block fan-out.
- String encryption: few readable strings + a decode routine called everywhere.

**"Does it need a solver?" (route to re-solve):**
- A check compares input against a value derived by pure computation
  (hash / xor / arithmetic) — model it in z3/angr instead of reversing by hand.
