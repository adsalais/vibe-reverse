#!/usr/bin/env python3
"""Emulate a target with Qiling to unpack / extract config without full detonation.

WHY: emulation runs the sample's instructions inside an emulator, granting only the
syscalls/resources you allow, so it can self-decrypt strings or build a config in
memory that we dump — safer and faster than native detonation for many samples. It
is still "running code": use only with consent + isolation (no network).

Adapt: set the rootfs for the target OS/arch, then add hooks/dumps for this sample.
Usage: python3 qiling_emulate.py <target> <rootfs> [--timeout 1800]
"""
import argparse


def emulate(target: str, rootfs: str, timeout: int) -> None:
    # why: import inside the function so the template still byte-compiles on hosts
    # where qiling is not installed (the air-gapped image has it).
    from qiling import Qiling  # noqa: F401

    # ql = Qiling([target], rootfs, console=False)
    # why: install hooks here — e.g. ql.hook_address(dump_cb, decryptor_ret_addr) to
    # capture plaintext, or hook mem writes to grab a decrypted config — then:
    # ql.run(timeout=timeout * 1_000_000)  # qiling timeout is microseconds
    raise SystemExit(
        "Fill in the rootfs + per-sample hooks (see re-dynamic SKILL.md)."
    )


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("target")
    p.add_argument("rootfs", help="qiling rootfs for the target OS/arch")
    p.add_argument("--timeout", type=int, default=1800, help="emulation budget (s)")
    a = p.parse_args()
    emulate(a.target, a.rootfs, a.timeout)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
