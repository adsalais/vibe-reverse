# Devirtualization methodology

Code virtualization replaces native instructions with bytecode interpreted by an
embedded VM. Goal: recover readable logic. Expect **partial** results — report
confidence.

## Recognize a VM
- A central **dispatcher** loop: read next bytecode, index a **handler table**,
  jump. Look for a big jump/switch table and a loop that keeps returning to it.
- A **virtual program counter** (a register/memory slot stepped each iteration) and
  a **VM context** struct holding virtual registers.
- Commercial: VMProtect, Themida/WinLicense, Code Virtualizer; academic: Tigress.
  Custom VMs are common in CTF and bespoke malware.

## Steps
1. **Locate** the dispatcher + handler table; enumerate handler addresses.
2. **Recover the bytecode** (the VM program — often pointed to at VM entry).
3. **Derive each handler's semantics** — symbolically execute one handler
   (`templates/triton_handler.py`) and read the output expression. Build an
   opcode → semantics table.
4. **Decode** the bytecode into (opcode, operands) using the VM's instruction format.
5. **Lift** to IR and simplify (`templates/miasm_lift.py`) → near-native pseudocode.
6. **Recursion / nesting:** if a handler itself enters another VM, treat the inner
   VM with steps 1–5 first, substitute its lifted result, then continue the outer.
   Track depth; each level multiplies cost — budget + ask-before-kill apply.
7. **Verify** by emulating the lifted logic vs the original on sample inputs
   (qiling/unicorn). Note any unhandled handlers as gaps.

## Honesty
A clean full devirtualization of a commercial protector is rarely one-shot. Deliver
the dispatcher map + opcode table + a partial lift with a clear confidence note and
the list of handlers still unresolved — that is real progress, not failure.
