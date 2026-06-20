---
name: re-dynamic
description: Use when reverse engineering requires running or tracing the target — debugging, syscall/library tracing, or observing runtime values — which must happen only inside a sandbox. Symptoms you are about to violate it: "just run it on the host", "it's probably safe", "sandbox is overkill". Keywords: dynamic analysis, run, execute, gdb, strace, ltrace, debugger, trace, sandbox.
---

# re-dynamic

**This phase RUNS the target.** That is dangerous for untrusted binaries.

## Core rule

Run the target **only** with (1) explicit user consent **and** (2) a sandbox:
a container (`--network none`), a throwaway VM, or a restricted user. **Never run
an untrusted target on the host.** Record the sandbox used in `00-target.md`.
*Violating the letter of this rule is violating its spirit.*

## Sandbox: microVM when available

In the `vibe-reverse` container, detonate via the **microVM** (separate kernel,
no network device at all):

```sh
vmrun.sh <sample> <investigation-dir> --mode trace|gdb-script|gdb-server [--timeout N]
```

For a **Windows PE** sample, detonate in the Windows guest instead:
`vmrun.sh <sample.exe> <investigation-dir> --guest windows` (needs a prepared
`~/.config/vibe-reverse/guests/windows.qcow2`; see windows-guest.md).

Results land in `artifacts/dynamic/`. If `vmrun.sh` is not present (running the
skills outside the container), fall back to `dynamic_trace.sh` **inside an external
sandbox** — the consent + isolation rule above still applies.

## Trace it (inside the sandbox)

```sh
sh dynamic_trace.sh <target> <investigation-dir> [args...]
```

Uses strace → ltrace → gdb; writes the trace to `artifacts/`. Use it to confirm
behavior, find the comparison, read runtime values, or set breakpoints.

## Red flags — STOP

| Thought | Reality |
|---|---|
| "Just run it on the host quickly" | Untrusted code on your host = compromise. Sandbox first. |
| "It's probably safe" | Triage/static can't prove that. Sandbox first. |
| "Sandbox is overkill for this" | It's one command. Sandbox first. |
| "I'll disconnect the network after" | Start with `--network none`, not after. |

End with **`re-planning`**. Relative paths only.
