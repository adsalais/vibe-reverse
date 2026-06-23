# Deobfuscation playbook — peel one layer, return to the loop

Advanced samples **stack** obfuscation (packing + strings + CFF + a VM…). This phase peels
**one** layer well and returns — it does **not** iterate. The `re-planning` loop drives the
stacking: it re-assesses each peeled result and re-invokes this phase (or routes to
`re-devirtualize` / `re-crypto` / …) for the next layer.

## Method

1. **Identify the outermost layer** — `deob_map.sh`, capa/FLOSS, DIE (`diec`), entropy;
   map it with `obfuscation-taxonomy.md` (sibling reference). Note suspected inner layers
   as `[hypothesis]` findings. The outermost is the only one you can peel now (you can't
   read flattened code inside a packed blob).
2. **Peel it** with its handler (taxonomy table) and record what changed as findings with
   evidence. If the outermost layer is a **VM**, don't peel — the next hypothesis is
   `re-devirtualize`; crypto-gated → `re-crypto`; interleaved anti-analysis → `re-antianalysis`.
3. **Return to the loop.** `re-planning` re-assesses the result (re-scan the changed bytes)
   and picks the next hypothesis. Most peels stay in the **same** binary (an unpacked
   section, a de-flattened function, a **nested VM**); only a peel that drops a **separate**
   binary → `add_binary.sh` + bootstrap (`re-triage`) it as a peer.

## Failure modes / wrong-track signals

- **Trying to clear the whole stack in one phase** — peel one layer and return; the loop
  handles the rest.
- **Peeling inner-first** — de-flattening code that's still packed/encrypted; peel the
  outermost.
- **Hand-rolling devirt or decryption** — a VM/crypto layer is the *loop's* next hypothesis
  (`re-devirtualize` / `re-crypto`), not something you improvise here.
- **Mistaking a deeper layer for a new binary** — a nested VM / unpacked section is the
  *same* binary; only a separate dropped file is a new binary (mandatory gate → `add_binary`).

## Red flags — STOP

| Thought | Reality |
|---|---|
| "I'll keep peeling here until it's clean" | Peel **one** layer and return — the `re-planning` loop iterates. |
| "It's a VM, I'll devirtualize it inline" | Record "outermost is a VM" and return; the loop routes to `re-devirtualize`. |
| "Unpacked it — I'll keep going in place on this new binary" | A *separate* dropped binary is a mandatory gate → `add_binary.sh`, bootstrap it. |

## Have I understood enough?

You've peeled the **outermost** layer and recorded the result with evidence. Whether
another layer remains is the **loop's** call (it re-assesses) — not something you decide by
looping here.

## Worked example

A dropper: triage shows entropy 7.9 + `UPX!`. Outermost = UPX packing → `unpack.sh` →
**return**. The loop re-assesses: entropy normal, but one dispatcher + equal-size blocks →
control-flow flattening is now outermost → `re-deobfuscate` again → de-flatten via miasm
(`re-coding`) → **return** → loop re-assesses → clean C → route on. Each pass peels one
layer; the loop drives.
