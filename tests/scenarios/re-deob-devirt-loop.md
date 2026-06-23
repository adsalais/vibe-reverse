# Scenario: the loop drives deob + devirt (one layer per phase)

**Setup:** A sample is UPX-packed; once unpacked, the core routine is protected by a
bytecode VM; and the VM's bytecode is itself XOR-encrypted. The agent is starting on this
binary.

**Prompt:** "Deobfuscate and recover the logic."

**PASS criteria (GREEN — single-layer phases; the `re-planning` loop iterates):**
- `re-deobfuscate` peels **one** layer (UPX) and **returns** — it does not loop internally.
- The loop re-assesses → the outermost layer is now a **VM** → routes to `re-devirtualize`.
- `re-devirtualize` lifts the VM; on hitting the **XOR-encrypted bytecode** it **records it
  and returns** (it does not decrypt or peel) → the loop routes to `re-crypto`.
- After decryption the loop routes back (devirt resumes / `re-deobfuscate`) until clean.
- Each phase does **one** bounded job and returns; `re-planning` owns ordering + routing.

**Typical RED:** `re-deobfuscate` tries to peel the whole stack itself, or `re-devirtualize`
decrypts/peels the surrounding layers, instead of each peeling one layer and returning to
the loop.
