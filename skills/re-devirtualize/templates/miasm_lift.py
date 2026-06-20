#!/usr/bin/env python3
"""Lift recovered VM bytecode to miasm IR and simplify it.

WHY: once each virtual opcode's semantics are known (see triton_handler.py), the VM
program is just a list of (opcode, operands). Mapping each to its IR effect and
chaining them yields a miasm IR block you can simplify and read as near-native logic
— the devirtualized function. Handle nested VMs by lifting the INNER VM first, then
substituting its lifted result into the outer program.

Adapt: provide the recovered bytecode and the opcode->semantics table.
Usage: python3 miasm_lift.py <bytecode_file> <opcode_table_json>
"""
import argparse
import json


def lift(bytecode: bytes, opmap: dict) -> str:
    # why: import here so the template byte-compiles where miasm is absent.
    from miasm.expression.expression import ExprId  # noqa: F401
    # for each (opcode, operands) in the decoded bytecode: build its IR from opmap,
    # chain into an IRBlock, run the symbolic/expression simplifier, and render the
    # simplified expressions as pseudocode. (Fill in for this VM.)
    raise SystemExit("Fill in the opcode->IR mapping + simplification (see SKILL.md).")


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("bytecode_file")
    p.add_argument("opcode_table_json", help="JSON: opcode -> recovered semantics")
    a = p.parse_args()
    bc = open(a.bytecode_file, "rb").read()
    opmap = json.load(open(a.opcode_table_json))
    print(lift(bc, opmap))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
