---
name: re-deobfuscate
description: Use when triage or static analysis shows a binary is packed or obfuscated — high entropy, a packer signature (UPX), encrypted strings, or control-flow flattening — to peel one obfuscation layer before deeper analysis. Keywords: packed, UPX, unpack, deobfuscate, obfuscation, entropy, encrypted strings, control-flow flattening.
---

# re-deobfuscate

Peel **one** obfuscation layer, then return to the loop. Advanced malware **stacks**
techniques (packing + strings + CFF + a VM…) — but you don't iterate here; the
`re-planning` hypothesis loop drives the stacking and picks what's next.

**Method, failure modes, worked example:** `references/deobfuscate-playbook.md`.
Reading a large lifted/handler or capa/FLOSS dump to extract the relevant lines is
**mechanical** — delegate it per `../reverse-engineering/references/delegating-to-subagents.md`.
The handler you pick is a candidate hypothesis for the `re-planning` loop — it ranks and gates.

## 1. Identify the outermost layer

Use triage/static signals + `re-static`'s `static_scan.sh` (capa/FLOSS) + DIE (`diec`) +
entropy to identify the **outermost** technique and map it with
`references/obfuscation-taxonomy.md`. Record suspected inner layers as `[hypothesis]`
findings (they become the loop's later hypotheses) and keep `artifacts/deobfuscation/map.md`:

```sh
sh deob_map.sh <investigation-dir>
```

You can't read flattened code inside a packed blob, so the **outermost** layer is the one
to peel now (packing/encryption before control-flow before virtualization).

## 2. Peel that one layer

Apply its handler and record what changed as findings (with evidence):

| Outermost technique | Handler / next hypothesis |
|---|---|
| Packing | `unpack.sh` (UPX); else run-to-unpack / qiling emulate (`re-dynamic`) + lief rebuild |
| String / API obfuscation | FLOSS, then a tested decoder via `re-coding` |
| Stack-strings | FLOSS / scripted reconstruction |
| Control-flow flattening | de-flatten via miasm/angr (`re-coding`) |
| Opaque / bogus predicates | prove constant with z3, patch out (keystone/lief) |
| **It's a VM** (dispatcher + handler table) | don't peel — the next hypothesis is **`re-devirtualize`** |
| **Crypto-gated layer** | the next hypothesis is **`re-crypto`** (decrypt), then re-assess the plaintext |
| **Interleaved anti-analysis** | the next hypothesis is **`re-antianalysis`** |

## 3. Return to the loop

You peeled **one** layer — return to `re-planning`, which re-assesses the result and
picks the next hypothesis:
- still obfuscated, same binary (incl. a **nested VM**) → peel the next layer (`re-deobfuscate` again);
- outermost is now a VM → `re-devirtualize`; crypto-gated → `re-crypto`; anti-analysis → `re-antianalysis`;
- a peel dropped a **separate** binary → `add_binary.sh`, bootstrap (`re-triage`) it as a peer;
- entropy normal, strings/imports readable, control flow sane → route on.

Static only here — runtime unpacking belongs to `re-dynamic` (sandboxed). Peel one layer
and return; choosing the next step is the loop's job, not yours. Relative paths only.
