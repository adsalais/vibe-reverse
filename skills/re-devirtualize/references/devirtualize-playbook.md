# Devirtualization playbook — lift the VM, then return to the loop

The `re-planning` loop routes here when the **outermost layer is a VM** (dispatcher +
handler table). You do the deep, often-partial work of recovering readable logic, then
return — you don't drive the surrounding peeling (that's the loop's job).

## Method

Follow the seven steps in `devirt-methodology.md` (sibling reference): locate dispatcher →
recover bytecode → derive handler semantics with `../templates/triton_handler.py` → decode
→ lift with `../templates/miasm_lift.py` → recurse for nested VMs → verify. Adapt the
templates via `re-coding` (test the deterministic decoder). Heavy symbolic/lift steps
are **🐢, a mandatory gate** — run them per
`../../reverse-engineering/references/long-running-ops.md`.

## Uncovered a non-VM layer? Record it and return

If lifting exposes a **non-VM layer** — encrypted bytecode, packing around the VM,
interleaved anti-analysis — **don't improvise.** Record it as a finding and **return to
the loop**, which routes the next hypothesis: packing/strings/CFF → `re-deobfuscate`;
crypto-gated bytecode → `re-crypto`; anti-disasm/anti-debug → `re-antianalysis`. (Nested
*VMs* are the exception — those you lift in place via recursion; see the Method.)

## Failure modes / wrong-track signals

- **Arrived at a "VM" that's still wrapped** — surrounding layers weren't peeled; record
  that and return rather than fighting noise (the loop peels them first).
- **Presenting a partial lift as complete** — devirt is usually partial; tag confidence
  and list unresolved handlers.
- **Nested-VM depth blows the budget** — each level multiplies cost (🐢); gate it.

## Red flags — STOP

| Thought | Reality |
|---|---|
| "There's packing around the VM, I'll just peel it here" | Record it and return — the loop routes to `re-deobfuscate`. |
| "I lifted most of it, call it done" | Partial is the norm — confidence-tag it; list the gaps. |
| "I'll recurse this nested VM unattended" | Deep recursion is 🐢 — mandatory gate; state the cost and stop. |

## Have I understood enough?

Deliver the **dispatcher map + opcode→semantics table + a confidence-tagged partial
lift** with unresolved handlers listed. That is real progress — you don't need a complete
decompilation to return useful logic to the loop.

## Worked example

A function behind a custom bytecode VM: locate the dispatcher loop + 16-entry handler
table, symbolically execute three handlers (add/xor/load) with `triton_handler.py`, decode
the bytecode, lift the arithmetic with `miasm_lift.py`. Two handlers stay opaque → record
**[likely]** lift, list the two gaps, verify the lifted arithmetic against the original on
sample inputs.
