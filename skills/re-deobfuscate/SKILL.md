---
name: re-deobfuscate
description: Use when triage or static analysis shows a binary is packed or obfuscated — high entropy, a packer signature (UPX), encrypted strings, or control-flow flattening — to unpack and deobfuscate before deeper analysis. Keywords: packed, UPX, unpack, deobfuscate, obfuscation, entropy, encrypted strings, control-flow flattening.
---

# re-deobfuscate

The stacked-layer **loop owner**, not a one-shot unpack. Advanced malware **stacks**
techniques, so work a loop:

> **inventory → order → peel one layer → re-assess → repeat** — until entropy is
> normal, strings/imports are readable, and control flow is sane.

**Method, failure modes, worked example:** `references/deobfuscate-playbook.md`.
Reading a large lifted/handler or capa/FLOSS dump to extract the relevant lines is
**mechanical** — delegate it per `../reverse-engineering/references/delegating-to-subagents.md`.
The handlers/routes you pick are candidate hypotheses for the `re-planning` loop — it ranks and gates.

## 1. Inventory the layers

Use triage/static signals + `re-static`'s `static_scan.sh` (capa/FLOSS) + DIE
(`diec`) + entropy to list **every** technique present. Record them:

```sh
sh deob_map.sh <investigation-dir>
```

Keep `artifacts/deobfuscation/map.md` current. Identify each layer with
`references/obfuscation-taxonomy.md`.

## 2. Order — outermost first

You can't read flattened code inside a packed blob. Peel packing/encryption before
control-flow before virtualization.

## 3. Peel, then re-assess

Apply the right handler (table below), then **re-assess the result in place** — re-run
the triage scan (`triage.sh`: entropy/packer/strings) + a `re-static` look on the
now-changed bytes to find the next layer. **Most peels stay in the *same* binary** (an
unpacked section, a de-flattened function, a nested VM) — keep looping on it. **Only a
peel that drops a *separate* binary** (a distinct payload file) is a new target →
`add_binary.sh`, then bootstrap it (the `re-triage` phase, once) as a peer.

| Technique | Handler / route |
|---|---|
| Packing | `unpack.sh` (UPX); else run-to-unpack / qiling emulate (`re-dynamic`) + lief rebuild |
| String / API obfuscation | FLOSS, then a tested decoder via `re-coding` |
| Stack-strings | FLOSS / scripted reconstruction |
| Control-flow flattening | de-flatten via miasm/angr (`re-coding`) |
| Opaque / bogus predicates | prove constant with z3, patch out (keystone/lief) |
| **Virtualization** | → **`re-devirtualize`** |
| **Interleaved anti-analysis** | → **`re-antianalysis`** |
| **Crypto-gated layer** | → **`re-crypto`**, then re-assess the plaintext |

## Gate balance

Propose the **whole peeling plan** once via `re-planning` (layers + order + cost
⚡/⏳/🐢); peel the obvious layers; **STOP at the gate** when something new appears (a
fresh binary, a VM, a layer you can't crack).

Static only here — runtime unpacking belongs to `re-dynamic` (sandboxed). End with
**`re-planning`**. Relative paths only.
