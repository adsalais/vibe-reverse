# Deobfuscation playbook — peel the stack, outermost first

Advanced samples **stack** obfuscation (packing + strings + CFF + a VM…). This phase is
the stacked-layer worker: inventory the layers, peel outermost-first, re-assess after
each peel. Its loop is the **ranking heuristic** feeding the `re-planning` hypothesis loop
— "the outermost layer is X" is the top hypothesis; peeling it is the test.

## Method

1. **Inventory** every technique present — `deob_map.sh`, capa/FLOSS, DIE (`diec`),
   entropy. Identify each with `obfuscation-taxonomy.md` (sibling reference).
2. **Rank outermost-first** (packing/encryption → control-flow → virtualization). You
   can't read flattened code inside a packed blob.
3. **Peel the top layer** with its handler (taxonomy table), then **re-assess the result
   in place** — re-run the triage scan (`triage.sh`) + a `re-static` look on the
   now-changed bytes to find the next layer. Most peels stay in the **same** binary (an
   unpacked section, a de-flattened function, a **nested VM**); keep looping on it. Only a
   peel that drops a **separate** binary → `add_binary.sh` + bootstrap (`re-triage`) it as
   a peer.
4. **A VM layer → dispatch `re-devirtualize`** as the worker (a nested VM is a deeper layer
   of the same binary — devirt recurses, or the loop re-dispatches it); when it returns the
   lifted logic, **re-assess and continue the loop.** Virtualization is a step in the loop,
   not a hand-off that ends it.
5. Record each layer + handler + result as findings (with evidence). Continue until
   entropy is normal, strings/imports are readable, and control flow is sane.

## Failure modes / wrong-track signals

- **Peeling inner-first** — de-flattening code that's still packed/encrypted.
- **Not re-assessing after a peel** — you miss the layer the peel just exposed.
- **Treating a VM as just-another-peel** — dispatch `re-devirtualize`, don't hand-roll it.
- **A peeled payload is a new binary** but you keep going in-place — mandatory gate
  (`add_binary.sh`, triage it as a peer).

## Red flags — STOP

| Thought | Reality |
|---|---|
| "I'll de-flatten now, the packing can wait" | Outermost first — you can't read code inside a packed blob. |
| "Peeled it, moving on" (no re-assess) | Re-assess after every peel — re-scan the changed bytes; a new layer may have appeared. |
| "Unpacked to a new binary, I'll keep analysing here" | New binary = mandatory gate → `add_binary.sh`, triage as a peer. |
| "I'll devirtualize this VM myself inline" | Dispatch `re-devirtualize` (the worker); it hands back if it hits a non-VM layer. |

## Have I understood enough?

A layer is peeled when its artifact is gone from the next re-assess (entropy dropped,
strings/imports readable). The phase is done when the binary re-assesses clean — then
route on. Don't over-peel a layer you've already removed.

## Worked example

A dropper: triage shows entropy 7.9 + `UPX!`. Top hypothesis: UPX packing → `unpack.sh`
→ re-assess (same binary, unpacked). Entropy normal now, but every function routes through
one dispatcher with equal-size blocks → control-flow flattening → de-flatten via miasm
(`re-coding`) → re-assess → clean C. Record each peel as a `[confirmed]` finding (evidence:
before/after artifacts).
