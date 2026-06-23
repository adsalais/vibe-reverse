# Devirtualization playbook — the VM worker, dispatched by the loop

`re-devirtualize` is the **worker** the `re-deobfuscate` loop dispatches when the current
layer is a VM (dispatcher + handler table). It does the deep, often-partial work of
recovering readable logic — it does **not** own a peel loop of its own.

## Method

Follow the seven steps in `devirt-methodology.md` (sibling reference): locate dispatcher →
recover bytecode → derive handler semantics with `../templates/triton_handler.py` → decode
→ lift with `../templates/miasm_lift.py` → recurse for nested VMs → verify. Adapt the
templates via `re-scripting` (test the deterministic decoder). Heavy symbolic/lift steps
are **🐢, a mandatory gate** — run them per
`../../reverse-engineering/references/long-running-ops.md`.

## Hand back to the loop

If you find a **non-VM layer** — encrypted bytecode, packing around the VM, interleaved
anti-analysis — **do not improvise a peel loop here.** Return to the owner: packing/
strings/CFF → `re-deobfuscate`; a crypto-gated bytecode blob → `re-crypto`, then resume;
anti-disasm/anti-debug → `re-antianalysis`, then resume. You are the VM worker; the loop
owns ordering.

## Failure modes / wrong-track signals

- **Arrived at a "VM" that's still wrapped** — surrounding layers weren't peeled; hand
  back rather than fighting noise.
- **Presenting a partial lift as complete** — devirt is usually partial; tag confidence
  and list unresolved handlers.
- **Nested-VM depth blows the budget** — each level multiplies cost (🐢); gate it.

## Red flags — STOP

| Thought | Reality |
|---|---|
| "There's packing around the VM, I'll just peel it here" | Hand back to `re-deobfuscate` — it owns the loop. |
| "I lifted most of it, call it done" | Partial is the norm — confidence-tag it; list the gaps. |
| "I'll recurse this nested VM unattended" | Deep recursion is 🐢 — mandatory gate; state the cost and stop. |

## Have I understood enough?

Deliver the **dispatcher map + opcode→semantics table + a confidence-tagged partial
lift** with unresolved handlers listed. That is real progress — you don't need a complete
decompilation to hand back useful logic.

## Worked example

A function behind a custom bytecode VM: locate the dispatcher loop + 16-entry handler
table, symbolically execute three handlers (add/xor/load) with `triton_handler.py`, decode
the bytecode, lift the arithmetic with `miasm_lift.py`. Two handlers stay opaque → record
**[likely]** lift, list the two gaps, verify the lifted arithmetic against the original on
sample inputs.
