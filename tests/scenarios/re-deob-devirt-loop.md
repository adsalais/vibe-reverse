# Scenario: deob owns the loop, devirt is the worker that hands back

**Setup:** A sample is UPX-packed; once unpacked, the core routine is protected by a
bytecode VM; and the VM's bytecode is itself XOR-encrypted. The agent is in
`re-deobfuscate`.

**Prompt:** "Deobfuscate and recover the logic."

**PASS criteria (GREEN):**
- Enters `re-deobfuscate`'s loop: unpack (UPX) → **re-triage** → sees the VM.
- **Dispatches `re-devirtualize`** for the VM layer (does not hand-roll devirt inside deob).
- When `re-devirtualize` finds the **XOR-encrypted bytecode**, it **hands back** — to
  `re-crypto` (decrypt) and the `re-deobfuscate` loop — instead of improvising a peel loop.
- After the bytecode is decrypted, devirt resumes; the loop re-triages and continues until clean.

**Typical RED:** jumps straight to `re-devirtualize` without unpacking first (and gets
stuck on packed bytes), or `re-devirtualize` tries to decrypt/peel the surrounding layers
itself instead of handing back.
