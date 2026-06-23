# Triage playbook — first look, done well

Triage identifies the artifact and routes it. It is **static and safe — never execute the
target.** The goal is a confident route, not deep understanding.

## Method

1. Run `triage.sh <target> <investigation-dir>` (writes `artifacts/triage.txt`).
2. Read the summary in order: **type / arch / size** → **entropy** → **packer** →
   **protections** (PIE/NX/RELRO/canary) → **strings** (usage text, imports like `strcmp`
   or crypto names, embedded secrets).
3. Map **family → route** (the SKILL's table): native → `re-static`; managed/wasm/firmware
   → that pack's roadmap.
4. Record a triage finding per `../../reverse-engineering/references/evidence-and-findings.md`
   — e.g. **[confirmed]** the format/arch/packing, evidence `artifacts/triage.txt`.

## Interpretation

- **Entropy > ~7.0** means high-entropy bytes — packing **or** encryption **or**
  compression **or** embedded compressed resources, not automatically a packer. Confirm
  with the packer line (DIE) before claiming "UPX".
- **Imports/strings** are the cheapest lead: `strcmp`/`memcmp` → a comparison check;
  crypto names/constants → `re-crypto`; many obfuscated strings → FLOSS in `re-static`.
- **Stripped / no symbols** is normal for release/malware; it is not "packed".

## Failure modes / wrong-track signals

- You start reading disassembly in triage — stop; that's `re-static`.
- You call it "packed" from entropy alone, with no packer signature.
- `file` says native but it's **managed** (a .NET PE, a Java class) — check for the CLR
  header / `PK` / `cafebabe` magic before routing to `re-static`.
- You treat a high-entropy *section* (a compressed resource) as a packed *binary*.

## Red flags — STOP

| Thought | Reality |
|---|---|
| "Let me start reversing the logic now" | Triage routes; it doesn't solve. Move to the right phase. |
| "Entropy is high, so it's UPX" | High entropy ≠ a specific packer. Confirm with DIE. |
| "It's stripped, so it's protected" | Stripping is normal. Not a protection finding. |

## Have I understood enough?

You are done when you know **format, architecture, packing status, and family**, and can
name the next phase. Anything deeper belongs to that phase. Do not decompile here.

## Worked example

`crackme1`: `triage.sh` reports ELF x86-64, entropy 1.79 (low → not packed), no packer,
PIE/NX/RELRO/canary, and a `strcmp` import. Family = native → record **[confirmed]** "ELF
x86-64, not packed" (evidence `artifacts/triage.txt`) and route to `re-static`. Time in
triage: one tool run.
