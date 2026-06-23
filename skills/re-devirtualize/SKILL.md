---
name: re-devirtualize
description: Use when a reverse-engineering target is protected by code virtualization / a VM-based obfuscator (VMProtect, Themida, Tigress, or a custom bytecode VM, possibly nested) — to find the dispatcher, recover the bytecode and handler semantics, and lift it back to readable logic. Keywords: devirtualize, virtualization, VMProtect, Themida, Tigress, VM obfuscation, dispatcher, handler table, bytecode, lifting, nested VM, recursion.
---

# re-devirtualize

For targets where triage/static/deob shows a **dispatcher loop + handler table**
(virtualized code). Usually reached via the `re-deobfuscate` router. Mostly
disciplined methodology + scripting.

**Method, failure modes, hand-back rule, worked example:** `references/devirtualize-playbook.md`.
Reading a large lifted-output/handler dump to extract specific handlers is **mechanical** —
delegate it per `../reverse-engineering/references/delegating-to-subagents.md`.
You are the VM worker the `re-deobfuscate` loop dispatches — hand back on a non-VM layer.

## Method (cite `references/devirt-methodology.md`)

1. **Locate** the dispatcher + handler table; enumerate handlers.
2. **Recover the bytecode** (the VM program).
3. **Derive each handler's semantics** — symbolically execute one handler with
   `templates/triton_handler.py`; build an opcode → semantics table.
4. **Decode** the bytecode into (opcode, operands).
5. **Lift** to IR and simplify with `templates/miasm_lift.py` → readable pseudocode.
6. **Recurse for nested VMs** — lift the inner VM first, substitute, continue.
7. **Verify** by emulating the lift vs the original (qiling/unicorn).

Adapt the templates via **`re-coding`** (test the deterministic parts, e.g. the
bytecode decoder). Run heavy symbolic/lift steps per
`../reverse-engineering/references/long-running-ops.md` (background + budget +
**ask before killing**).

## Honesty (REQUIRED)

Devirt is typically **partial**. Deliver the dispatcher map, the opcode→semantics
table, and a **confidence-tagged** partial lift with unresolved handlers listed.
Never present a partial lift as a complete decompilation.

End with **`re-planning`**. Relative paths only.
