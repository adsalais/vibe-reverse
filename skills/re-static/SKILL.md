---
name: re-static
description: Use after triage on a native binary to statically analyze it — disassemble or decompile and assess whether it is obfuscated, packed, or needs a solver — without running it. Keywords: static analysis, decompile, disassemble, Ghidra, radare2, objdump, decompiled C, reverse function, obfuscation.
---

# re-static

Static analysis only — **never run the target.**

## Run it

```sh
sh ghidra_decompile.sh <target> <investigation-dir>
```

Tries **Ghidra → radare2 → objdump** and writes the result to `artifacts/`. Read
the artifact and **summarize** the relevant function(s) into the plan — don't
paste the whole disassembly into chat. If it fell back to objdump, the decompilers
(Ghidra/r2) were not found on PATH — unexpected on the air-gapped image.

## Assess (cite `references/protections.md`)

- Packed / obfuscated? (high entropy, packer sig, opaque predicates) → `re-deobfuscate`.
- A check compares input to a *computed* value (hash / xor / arithmetic)? →
  solver-friendly → `re-solve`.
- Needs to run / be traced to understand? → `re-dynamic` (sandbox only).
- Protections (PIE / NX / RELRO / canary) — note for later phases.

Use **`re-scripting`** for custom parsing/analysis code.

## Always

End the phase with **`re-planning`**: write `NN-static-plan.md`, self-review,
STOP for approval. REQUIRED. Relative paths only.
