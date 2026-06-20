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

Then run the capability + string scan (capa + FLOSS):

```sh
sh static_scan.sh <target> <investigation-dir>
```

capa tags capabilities (ATT&CK/MBC); FLOSS auto-extracts obfuscated/stack strings.
Both can be slow on large binaries — launch them per
`../reverse-engineering/references/long-running-ops.md`. Summarize the hits into the
plan; full output stays in `artifacts/`.

## Assess (cite `references/protections.md`)

- Packed / obfuscated? (high entropy, packer sig, opaque predicates) → `re-deobfuscate`.
- capa flags crypto / config / many obfuscated strings? → `re-crypto`, `re-config`.
- Anti-debug / anti-VM / timing checks visible? → `re-antianalysis`.
- A dispatcher loop + handler table (virtualized)? → `re-deobfuscate` → `re-devirtualize`.
- A check compares input to a *computed* value (hash / xor / arithmetic)? →
  solver-friendly → `re-solve`.
- Needs to run / be traced to understand? → `re-dynamic` (sandbox only).
- Protections (PIE / NX / RELRO / canary) — note for later phases.

Use **`re-scripting`** for custom parsing/analysis code.

## Always

End the phase with **`re-planning`**: write `NN-static-plan.md`, self-review,
STOP for approval. REQUIRED. Relative paths only.
