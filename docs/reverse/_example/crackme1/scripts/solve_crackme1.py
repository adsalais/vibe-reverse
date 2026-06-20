#!/usr/bin/env python3
"""Keygen for crackme1 — recover a valid key for a username.

WHY: static analysis (02-static-plan) showed the binary computes
want[i] = username[i] + 1 and compares it to the key, so the key is just each
username byte incremented by one.
"""
import sys


def keygen(username: str) -> str:
    # why: invert the check want[i] == username[i] + 1
    return "".join(chr((ord(c) + 1) % 256) for c in username)


if __name__ == "__main__":
    print(keygen(sys.argv[1] if len(sys.argv) > 1 else "AB"))
