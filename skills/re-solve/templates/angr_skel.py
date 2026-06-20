#!/usr/bin/env python3
"""angr symbolic-execution skeleton — find input that reaches a target address.

WHY: let angr explore paths and solve for the stdin/argv that reaches the
"success" branch, instead of tracing by hand. Set FIND/AVOID to addresses you
read in re-static (e.g. the puts("Correct!") block vs the puts("Wrong.") block).

Run: python3 angr_skel.py <binary>   (angr is pre-installed on the air-gapped image)
"""
import sys
import angr


def solve(path: str, find: int, avoid: int, arg_len: int = 32) -> bytes:
    proj = angr.Project(path, auto_load_libs=False)
    arg = angr.claripy.BVS("arg", 8 * arg_len)
    state = proj.factory.full_init_state(args=[path, arg])
    sm = proj.factory.simulation_manager(state)
    sm.explore(find=find, avoid=avoid)
    if not sm.found:
        raise SystemExit("no path reached FIND")
    return sm.found[0].solver.eval(arg, cast_to=bytes)


if __name__ == "__main__":
    # Fill FIND/AVOID from re-static, then call solve(sys.argv[1], FIND, AVOID).
    print("set FIND/AVOID addresses from re-static, then call solve()")
