---
name: re-triage
description: Use at the start of a reverse-engineering investigation to identify an unknown file — its format, architecture, packing/entropy, protections, and strings — and route to the right phase. Keywords: triage, file type, ELF, PE, Mach-O, packed, entropy, checksec, what is this binary, first look.
---

# re-triage

Triage is the **one-time first look** that bootstraps a binary — identify it, then route
into the hypothesis loop. Run it **once per binary** (the orchestrator on a new session,
or `add_binary.sh` for a dropped/separate payload), not per loop iteration. It is
**static and safe — never execute the target.**

**Method, interpretation, failure modes, worked example:** `references/triage-playbook.md`.
Heavy-artifact reads (rare in triage — its output is small) delegate mechanically — see
`../reverse-engineering/references/delegating-to-subagents.md`.
The family routes below are candidate hypotheses for the `re-planning` loop — it ranks and gates.

## Run it

```sh
sh triage.sh <target> <investigation-dir>
```

Writes `artifacts/triage.txt` and prints a summary: type/arch, size, sha256,
**entropy**, packer, ELF protections, and **family**.

## Read the summary

- **entropy > 7.0** or a packer line → likely packed → route to `re-deobfuscate`.
- **protections** (PIE / NX / RELRO / canary) — context for later phases.
- **strings** — usage text, imported funcs (`strcmp`, crypto), embedded secrets.

## Route by family

| family | next |
|---|---|
| `native` (ELF / PE / Mach-O) | propose `re-static` |
| `managed-java`, `wasm`, firmware | that pack isn't built yet — point to the roadmap in the design spec (don't fail) |

## Always

- Record the target + **authorization/scope** in `00-target.md` (if not already).
- End the phase via **`re-planning`**: write `01-triage-plan.md`, self-review, then
  gate — proceed if confident + reversible, stop if uncertain/irreversible. REQUIRED.

Relative paths only; put the summary in the plan, not the raw artifact.
