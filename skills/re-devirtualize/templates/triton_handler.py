#!/usr/bin/env python3
"""Recover one VM handler's semantics by symbolic execution (Triton).

WHY: a virtualized binary replaces native code with a fetch-decode-execute loop over
bytecode; each handler implements one virtual opcode. Symbolically executing a single
handler and reading the resulting expression for the output register tells you what
that opcode DOES (e.g. "vreg2 = vreg0 + vreg1") without reversing it by hand. Repeat
per handler to build an opcode->semantics table — the core of devirtualization.

Adapt: set the handler start/end addresses and the VM context (register) layout.
Usage: python3 triton_handler.py <target> <handler_start_hex> <handler_end_hex>
"""
import argparse


def recover(target: str, start: int, end: int) -> None:
    # why: import here so the template byte-compiles where Triton is absent.
    from triton import TritonContext, ARCH  # noqa: F401
    # ctx = TritonContext(ARCH.X86_64); map the code bytes; symbolize the virtual
    # registers / VM context; emulate start..end; print the symbolic AST of each
    # modified vreg to read off the opcode's semantics. (Fill in for this VM.)
    raise SystemExit("Fill in the VM context layout + emulation loop (see SKILL.md).")


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("target")
    p.add_argument("handler_start", help="hex address of the handler start")
    p.add_argument("handler_end", help="hex address of the handler end")
    a = p.parse_args()
    recover(a.target, int(a.handler_start, 16), int(a.handler_end, 16))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
