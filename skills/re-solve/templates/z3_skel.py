#!/usr/bin/env python3
"""z3 constraint-solver skeleton — recover an input that satisfies a check.

WHY: when a binary compares your input to a value computed by pure
arithmetic/bitops, model the computation as constraints and let z3 find a
satisfying input instead of reversing by hand. Replace the example constraints
with the ones you read in re-static.

Run: python3 z3_skel.py   (z3 is pre-installed on the air-gapped image)
"""
import z3


def solve(username: str) -> str:
    # Example modelled on crackme1: key[i] == username[i] + 1 (mod 256).
    # why: static analysis showed each key byte is the username byte plus one.
    key = [z3.BitVec(f"k{i}", 8) for i in range(len(username))]
    s = z3.Solver()
    for i, ch in enumerate(username):
        s.add(key[i] == (ord(ch) + 1) % 256)
    assert s.check() == z3.sat
    m = s.model()
    return "".join(chr(m[key[i]].as_long()) for i in range(len(username)))


if __name__ == "__main__":
    print(solve("AB"))  # -> BC
