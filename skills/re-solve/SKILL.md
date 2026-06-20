---
name: re-solve
description: Use when a reverse-engineering check compares input to a computed value (hash, xor, arithmetic) or you must find input that reaches a target path — recover the input with z3, angr, or direct inversion. Keywords: solver, z3, angr, symbolic execution, SMT, keygen, constraint, recover key, satisfy check.
---

# re-solve

Recover an input that satisfies a check.

## Pick a route

- **Direct inversion** — the check is invertible (xor / add / simple transform):
  compute the answer, usually via `re-scripting`.
- **Constraints (z3)** — arithmetic/bitwise relations: model them and solve.
  Start from `templates/z3_skel.py`.
- **Path-finding (angr)** — "find input that reaches the success branch": use
  `templates/angr_skel.py` with FIND/AVOID addresses from `re-static`.

Get the logic and addresses from **`re-static`**. `z3`/`angr` are installed
globally — run them with `python3`:

```sh
python3 templates/z3_skel.py
```

They are pre-installed on the air-gapped image — there is nothing to set up.

## Always verify

Run the *real* binary with the recovered input and confirm it is accepted (e.g.
`./target <user> <key>` → "Correct!"). Safe for your own challenge; for an
untrusted target, verify inside a sandbox via **`re-dynamic`**.

Write the solver with **`re-scripting`** (tested, documented). End with
**`re-planning`**. Relative paths only.
